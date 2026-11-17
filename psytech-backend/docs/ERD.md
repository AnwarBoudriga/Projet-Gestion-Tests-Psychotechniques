# Base de données PsyTech Pro

```mermaid
erDiagram
  SUPER_ADMINS {
    int id PK
    string identifiant UK
    string mot_de_passe_hash
  }
  ENTREPRISES {
    int id PK
    string nom
    string email UK
    string secteur
    char cle_hash UK
    enum statut "actif | inactif"
  }
  TESTS {
    int id PK
    int entreprise_id FK
    string titre
    int duree_minutes
    int score_minimum
    bool afficher_score
    enum statut "brouillon | publie"
    int duplique_de FK
  }
  QUESTIONS {
    int id PK
    int entreprise_id FK "NULL = banque du Super Admin"
    text enonce
    string option_a_d
    enum reponse_correcte "A-D"
    int points
  }
  TEST_QUESTIONS {
    int test_id PK
    int question_id PK
    int position
  }
  INVITATIONS {
    int id PK
    int entreprise_id FK
    int test_id FK
    string nom
    string email
    char cle_hash UK
    datetime expiration
    enum statut "invite | en_cours | termine | expire"
  }
  REPONSES {
    int invitation_id FK
    int question_id FK
    enum choix "A-D"
  }
  RESULTATS {
    int invitation_id FK
    int score
    int score_max
    bool reussi
  }
  AUDIT_LOGS {
    bigint id PK
    enum acteur_type
    string action
    json details
  }
  ENTREPRISES ||--o{ TESTS : possede
  ENTREPRISES ||--o{ QUESTIONS : ecrit
  ENTREPRISES ||--o{ INVITATIONS : invite
  TESTS ||--o{ TEST_QUESTIONS : contient
  QUESTIONS ||--o{ TEST_QUESTIONS : "utilisee dans"
  TESTS ||--o{ INVITATIONS : "passe via"
  INVITATIONS ||--o{ REPONSES : donne
  QUESTIONS ||--o{ REPONSES : concerne
  INVITATIONS ||--o| RESULTATS : produit
```

## Qui utilise quoi
| Module | Tables principales |
|---|---|
| Super Admin | `super_admins`, `entreprises`, `questions` (entreprise_id NULL), `audit_logs`, stats sur tout |
| Entreprise (RH) | `tests`, `questions` (les siennes), `test_questions`, `invitations`, vues `v_tests_resume`, `v_resultats_detail`, `v_dashboard_entreprise` |
| Candidat | `invitations` (login par clé), `test_questions` + `questions` (énoncés), `reponses`, `resultats` |

## Requêtes utiles
**Questions d'un test, dans l'ordre** (sans la bonne réponse pour le candidat !):
```sql
SELECT q.id, q.enonce, q.option_a, q.option_b, q.option_c, q.option_d
FROM test_questions tq JOIN questions q ON q.id = tq.question_id
WHERE tq.test_id = ? ORDER BY tq.position;
```
**Calcul du score à la soumission:**
```sql
SELECT COALESCE(SUM(CASE WHEN r.choix = q.reponse_correcte THEN q.points END), 0) AS score,
       SUM(q.points) AS score_max
FROM test_questions tq
JOIN questions q ON q.id = tq.question_id
LEFT JOIN reponses r ON r.question_id = q.id AND r.invitation_id = ?
WHERE tq.test_id = ?;
```
**Enregistrer/changer une réponse** (le candidat peut revenir en arrière):
```sql
INSERT INTO reponses (invitation_id, question_id, choix) VALUES (?, ?, ?)
ON DUPLICATE KEY UPDATE choix = VALUES(choix);
```
**Login candidat** (clé valide, non expirée, entreprise active):
```sql
SELECT i.* FROM invitations i JOIN entreprises e ON e.id = i.entreprise_id
WHERE i.cle_hash = ? AND i.expiration > NOW() AND e.statut = 'actif' AND i.statut <> 'termine';
```
La clé reçue est hashée avec `hashKey()` de `src/utils/keys.js` avant la requête.
