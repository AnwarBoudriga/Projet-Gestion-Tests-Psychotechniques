const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');

(async () => {
  const sql = fs.readFileSync(path.join(__dirname, '../../db/schema.sql'), 'utf8');
  await pool.query(sql);
  console.log('[migrate] schéma appliqué.');
  await pool.end();
})().catch((e) => { console.error('[migrate] échec :', e.message); process.exit(1); });
