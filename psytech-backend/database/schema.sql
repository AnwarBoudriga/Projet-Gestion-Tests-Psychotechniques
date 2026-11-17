-- =====================================================================
--  PsyTech Pro — Base de données COMMUNE (Super Admin / Entreprise / Candidat)
--  v2. Pour repartir de zéro (données de test seulement):
--      DROP DATABASE psytech_pro;   puis réimporter ce fichier.
-- =====================================================================
CREATE DATABASE IF NOT EXISTS psytech_pro CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE psytech_pro;

-- ---------------------------------------------------------------------
-- SUPER ADMIN
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS super_admins (
  id INT AUTO_INCREMENT PRIMARY KEY,
  identifiant VARCHAR(50) NOT NULL UNIQUE,
  mot_de_passe_hash VARCHAR(255) NOT NULL,            -- bcrypt
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS entreprises (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nom VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  secteur VARCHAR(100) DEFAULT '',
  cle_hash CHAR(64) NULL UNIQUE,                      -- HMAC-SHA256 de ENT-XXXXXXXX
  statut ENUM('actif','inactif') NOT NULL DEFAULT 'actif',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_ent_statut (statut)
);

-- ---------------------------------------------------------------------
-- ENTREPRISE (RH): tests + questions
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  entreprise_id INT NOT NULL,
  titre VARCHAR(200) NOT NULL,
  description TEXT,
  duree_minutes INT NOT NULL,
  categorie VARCHAR(100),
  score_minimum INT NOT NULL DEFAULT 0,               -- score minimum de réussite
  afficher_score TINYINT(1) NOT NULL DEFAULT 0,       -- autoriser le candidat à voir son score
  statut ENUM('brouillon','publie') NOT NULL DEFAULT 'brouillon',
  duplique_de INT NULL,                               -- si créé par "Dupliquer"
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CHECK (duree_minutes > 0),
  CHECK (score_minimum >= 0),
  INDEX idx_tests_ent (entreprise_id, statut),
  FOREIGN KEY (entreprise_id) REFERENCES entreprises(id) ON DELETE CASCADE,
  FOREIGN KEY (duplique_de) REFERENCES tests(id) ON DELETE SET NULL
);

-- entreprise_id = NULL  =>  question de la BANQUE (créée par le Super Admin)
CREATE TABLE IF NOT EXISTS questions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  entreprise_id INT NULL,
  enonce TEXT NOT NULL,
  option_a VARCHAR(255) NOT NULL,
  option_b VARCHAR(255) NOT NULL,
  option_c VARCHAR(255) NOT NULL,
  option_d VARCHAR(255) NOT NULL,
  reponse_correcte ENUM('A','B','C','D') NOT NULL,
  points INT NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CHECK (points > 0),
  INDEX idx_q_ent (entreprise_id),
  FOREIGN KEY (entreprise_id) REFERENCES entreprises(id) ON DELETE CASCADE
);

-- Questions d'un test, avec ordre (position) -> réordonner = UPDATE position
CREATE TABLE IF NOT EXISTS test_questions (
  test_id INT NOT NULL,
  question_id INT NOT NULL,
  position INT NOT NULL DEFAULT 0,
  PRIMARY KEY (test_id, question_id),
  INDEX idx_tq_pos (test_id, position),
  FOREIGN KEY (test_id) REFERENCES tests(id) ON DELETE CASCADE,
  FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- ENTREPRISE -> CANDIDAT: invitations (= un candidat invité à un test)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS invitations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  entreprise_id INT NOT NULL,
  test_id INT NOT NULL,
  nom VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL,
  cle_hash CHAR(64) NOT NULL UNIQUE,                  -- HMAC-SHA256 de PSY-XXXXXX
  expiration DATETIME NOT NULL,
  statut ENUM('invite','en_cours','termine','expire') NOT NULL DEFAULT 'invite',
  email_envoye_at DATETIME NULL,                      -- confirmation par email
  lot_import VARCHAR(40) NULL,                        -- identifiant d'un import CSV
  started_at DATETIME NULL,                           -- début du test (chronomètre)
  termine_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_inv_ent (entreprise_id, statut),
  INDEX idx_inv_test (test_id),
  INDEX idx_inv_exp (expiration),
  FOREIGN KEY (entreprise_id) REFERENCES entreprises(id) ON DELETE CASCADE,
  FOREIGN KEY (test_id) REFERENCES tests(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- CANDIDAT: réponses + résultat
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reponses (
  id INT AUTO_INCREMENT PRIMARY KEY,
  invitation_id INT NOT NULL,
  question_id INT NOT NULL,
  choix ENUM('A','B','C','D') NOT NULL,
  UNIQUE KEY uq_rep (invitation_id, question_id),     -- une seule réponse par question
  FOREIGN KEY (invitation_id) REFERENCES invitations(id) ON DELETE CASCADE,
  FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS resultats (
  id INT AUTO_INCREMENT PRIMARY KEY,
  invitation_id INT NOT NULL UNIQUE,
  score INT NOT NULL,
  score_max INT NOT NULL,
  reussi TINYINT(1) NOT NULL DEFAULT 0,
  duree_secondes INT NULL,
  soumis_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (invitation_id) REFERENCES invitations(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- JOURNAL D'ACTIVITÉ (audit)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  acteur_type ENUM('super_admin','entreprise','candidat','systeme') NOT NULL,
  acteur_id INT NULL,
  action VARCHAR(100) NOT NULL,
  entite VARCHAR(50) NULL,
  entite_id INT NULL,
  details JSON NULL,
  ip VARCHAR(45) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_action (action),
  INDEX idx_created (created_at),
  INDEX idx_acteur (acteur_type, acteur_id)
);

-- ---------------------------------------------------------------------
-- VUES pratiques (lecture seule)
-- ---------------------------------------------------------------------
-- Entreprise: liste des tests avec nombre de questions et total de points
CREATE OR REPLACE VIEW v_tests_resume AS
SELECT t.id, t.entreprise_id, t.titre, t.categorie, t.statut, t.duree_minutes,
       t.score_minimum, t.afficher_score,
       COUNT(tq.question_id)  AS nb_questions,
       COALESCE(SUM(q.points), 0) AS total_points
FROM tests t
LEFT JOIN test_questions tq ON tq.test_id = t.id
LEFT JOIN questions q ON q.id = tq.question_id
GROUP BY t.id;

-- Entreprise: résultats détaillés par candidat (écran "Résultats" + export CSV/PDF)
CREATE OR REPLACE VIEW v_resultats_detail AS
SELECT r.id AS resultat_id, i.entreprise_id, i.id AS invitation_id,
       i.nom AS candidat_nom, i.email AS candidat_email,
       t.id AS test_id, t.titre AS test_titre,
       r.score, r.score_max,
       ROUND(r.score / r.score_max * 100, 1) AS pourcentage,
       r.reussi, r.duree_secondes, r.soumis_at
FROM resultats r
JOIN invitations i ON i.id = r.invitation_id
JOIN tests t ON t.id = i.test_id;

-- Entreprise: tableau de bord (tests, candidats, taux de réussite)
CREATE OR REPLACE VIEW v_dashboard_entreprise AS
SELECT e.id AS entreprise_id,
       (SELECT COUNT(*) FROM tests t WHERE t.entreprise_id = e.id) AS nb_tests,
       (SELECT COUNT(*) FROM invitations i WHERE i.entreprise_id = e.id) AS nb_candidats,
       (SELECT ROUND(100 * AVG(r.reussi), 1)
          FROM resultats r JOIN invitations i ON i.id = r.invitation_id
         WHERE i.entreprise_id = e.id) AS taux_reussite
FROM entreprises e;
