# PsyTech Pro - Backend Entreprise (RH)

Node.js + Express + PostgreSQL (`pg`) + JWT + bcrypt + zod.

## Démarrage

```bash
npm install
cp .env.example .env          # puis renseigner DATABASE_URL et JWT_SECRET
createdb psytech_pro          # ou créer la base avec pgAdmin
npm run migrate               # crée les tables (db/schema.sql)
npm run seed                  # DEV : entreprise démo (clé PSYTECH-2026) + banque de questions
npm run dev                   # http://localhost:3000
npm run test:auth             # test automatique du module Authentification
```

## Modules

| Module | État |
|---|---|
| 0 - Socle (config, DB, erreurs, validation, sécurité) | fait, testé |
| 1 - Authentification (clé entreprise -> JWT) | fait, 17 tests OK |
| 2 - Tests | à venir |
| 3 - Questions | à venir |
| 4 - Invitations | à venir |
| 5 - Résultats | à venir |
| 6 - Tableau de bord | à venir |

## API disponible

| Méthode | URL | Auth | Description |
|---|---|---|---|
| GET | /api/health | non | État de l'API et de la base |
| POST | /api/entreprise/auth/login | non | `{ "cle": "..." }` -> `{ token, entreprise }` |
| GET | /api/entreprise/auth/me | Bearer | Entreprise connectée |

Erreurs : `{ "message": "...", "errors": [{ "field", "message" }] }` (même format que l'`Api.errorMessage` du Flutter).

## Sécurité en place

- Clé entreprise stockée hachée (bcrypt), jamais en clair ; comparaison même si la clé est inconnue (pas de fuite par le temps de réponse).
- JWT HS256 signé, expirant ; refusé dès que l'entreprise est désactivée ou que sa clé est régénérée (`cle_version`).
- Limitation de débit sur le login (10 tentatives / 15 min / IP), `helmet`, CORS en liste blanche en production.
- Validation `zod` stricte (champs inattendus et objets d'injection refusés), requêtes SQL paramétrées uniquement.
