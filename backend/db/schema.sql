-- =====================================================================
-- PsyTech Pro - Schéma PostgreSQL - module Entreprise (RH)
-- Déduit du MockStore et des modèles Dart existants.
-- Les tables "entreprises" et "questions_banque" sont CRÉÉES SI ABSENTES :
-- si le backend Super Admin les définit déjà, adaptez les noms de colonnes
-- (voir la section "Hypothèses" de la réponse).
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------
-- Entreprises (créées par le Super Admin, qui leur émet une clé)
-- Le login RH se fait avec cette clé (écran "Clé entreprise").
-- On ne stocke JAMAIS la clé en clair : uniquement son hash.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entreprises (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom           VARCHAR(150) NOT NULL,
  email         VARCHAR(255) NOT NULL UNIQUE,
  secteur       VARCHAR(100),
  statut        VARCHAR(10)  NOT NULL DEFAULT 'actif'
                CHECK (statut IN ('actif', 'inactif')),
  cle_hash      TEXT,                       -- bcrypt de la clé entreprise
  cle_prefix    VARCHAR(16),                -- 8 premiers caractères, pour retrouver la ligne
  cle_version   INT NOT NULL DEFAULT 1,     -- +1 à chaque régénération : invalide les anciens JWT
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_entreprises_cle_prefix ON entreprises (cle_prefix);

-- ---------------------------------------------------------------------
-- Banque de questions (gérée par le Super Admin, lecture seule pour RH)
-- Colonnes identiques à l'API admin : enonce, optionA..D, reponseCorrecte, points
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS questions_banque (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enonce           TEXT NOT NULL,
  option_a         TEXT NOT NULL,
  option_b         TEXT NOT NULL,
  option_c         TEXT NOT NULL,
  option_d         TEXT NOT NULL,
  reponse_correcte CHAR(1) NOT NULL CHECK (reponse_correcte IN ('A','B','C','D')),
  points           INT NOT NULL CHECK (points >= 1),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- Tests (TestModel)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tests (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entreprise_id  UUID NOT NULL REFERENCES entreprises(id) ON DELETE CASCADE,
  titre          VARCHAR(200) NOT NULL,
  description    TEXT NOT NULL DEFAULT '',
  duree_minutes  INT  NOT NULL CHECK (duree_minutes > 0),
  categorie      VARCHAR(100) NOT NULL,
  score_minimum  INT  NOT NULL CHECK (score_minimum BETWEEN 0 AND 100),
  afficher_score BOOLEAN NOT NULL DEFAULT false,
  publie         BOOLEAN NOT NULL DEFAULT false,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tests_entreprise ON tests (entreprise_id);

-- ---------------------------------------------------------------------
-- Questions d'un test (QuestionModel) - ordre géré par "position"
-- (écran : boutons Monter / Descendre)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS questions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id          UUID NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
  position         INT  NOT NULL,
  enonce           TEXT NOT NULL,
  option_a         TEXT NOT NULL,
  option_b         TEXT NOT NULL,
  option_c         TEXT NOT NULL,
  option_d         TEXT NOT NULL,
  reponse_correcte CHAR(1) NOT NULL CHECK (reponse_correcte IN ('A','B','C','D')),
  points           INT NOT NULL CHECK (points >= 1),
  banque_id        UUID REFERENCES questions_banque(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (test_id, position) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX IF NOT EXISTS idx_questions_test ON questions (test_id, position);

-- ---------------------------------------------------------------------
-- Invitations / candidats (InvitationModel)
-- Statuts stockés : invite | en_cours | termine
-- "Expiré" est calculé (expire_at < now() et statut <> termine), comme
-- le getter displayStatus du Front.
-- La clé candidat (PT-XXXX-XXXX) est affichée UNE SEULE FOIS à la création
-- (key_dialog) : on stocke son hash, jamais la valeur.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS invitations (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entreprise_id  UUID NOT NULL REFERENCES entreprises(id) ON DELETE CASCADE,
  test_id        UUID NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
  nom            VARCHAR(150) NOT NULL,
  email          VARCHAR(255) NOT NULL,
  cle_hash       TEXT NOT NULL,
  cle_prefix     VARCHAR(16) NOT NULL,
  statut         VARCHAR(10) NOT NULL DEFAULT 'invite'
                 CHECK (statut IN ('invite', 'en_cours', 'termine')),
  expire_at      TIMESTAMPTZ NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_invitations_entreprise ON invitations (entreprise_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_invitations_test ON invitations (test_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_invitations_cle_prefix ON invitations (cle_prefix);

-- ---------------------------------------------------------------------
-- Résultats (CandidateResult + ResultLine)
-- Les lignes sont un instantané : énoncé, réponses et points sont copiés
-- au moment de la passation, pour que modifier le test plus tard ne
-- change pas un résultat déjà obtenu.
-- Ces tables seront alimentées par l'application CANDIDAT (hors périmètre) ;
-- côté RH, on ne fait que les lire.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS resultats (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id  UUID NOT NULL UNIQUE REFERENCES invitations(id) ON DELETE CASCADE,
  score_minimum  INT NOT NULL,              -- copié du test au moment de la passation
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS resultat_lignes (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resultat_id       UUID NOT NULL REFERENCES resultats(id) ON DELETE CASCADE,
  position          INT NOT NULL,
  enonce            TEXT NOT NULL,
  reponse_choisie   CHAR(1) CHECK (reponse_choisie IN ('A','B','C','D')),
  texte_choisi      TEXT,
  reponse_correcte  CHAR(1) NOT NULL CHECK (reponse_correcte IN ('A','B','C','D')),
  texte_correct     TEXT NOT NULL,
  points_obtenus    INT NOT NULL DEFAULT 0,
  points_max        INT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_resultat_lignes ON resultat_lignes (resultat_id, position);
