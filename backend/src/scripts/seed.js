// Données de démonstration (DEV uniquement) : une entreprise avec la clé du Front (PSYTECH-2026)
// + la banque de questions du MockStore.
const { pool } = require('../config/db');
const { isProd } = require('../config/env');
const { hashKey, prefixOf } = require('../utils/keys');

const DEMO_KEY = 'PSYTECH-2026';

(async () => {
  if (isProd) throw new Error('Seed interdit en production.');

  const { rows } = await pool.query('SELECT id FROM entreprises WHERE email = $1', ['demo@psytech.local']);
  if (rows.length === 0) {
    await pool.query(
      `INSERT INTO entreprises (nom, email, secteur, cle_hash, cle_prefix)
       VALUES ($1, $2, $3, $4, $5)`,
      ['Entreprise Démo', 'demo@psytech.local', 'Services', await hashKey(DEMO_KEY), prefixOf(DEMO_KEY)]
    );
    console.log(`[seed] entreprise démo créée. Clé de connexion : ${DEMO_KEY}`);
  } else {
    console.log('[seed] entreprise démo déjà présente.');
  }

  const { rows: b } = await pool.query('SELECT count(*)::int AS n FROM questions_banque');
  if (b[0].n === 0) {
    const bank = [
      ['Quel mot est l’intrus : chaise, table, armoire, stylo ?', 'chaise', 'table', 'armoire', 'stylo', 'D', 1],
      ['25 % de 240 vaut :', '50', '60', '65', '80', 'B', 1],
      ['Si 3 ouvriers font un travail en 12 jours, 6 ouvriers le font en :', '4 jours', '6 jours', '9 jours', '24 jours', 'B', 2],
    ];
    for (const q of bank) {
      await pool.query(
        `INSERT INTO questions_banque (enonce, option_a, option_b, option_c, option_d, reponse_correcte, points)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`, q);
    }
    console.log('[seed] banque de questions créée (3).');
  }
  await pool.end();
})().catch((e) => { console.error('[seed] échec :', e.message); process.exit(1); });
