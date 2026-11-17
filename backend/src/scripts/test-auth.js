// Test de bout en bout du module Authentification (serveur lancé sur PORT).
// Usage : npm run test:auth
require('dotenv').config();
const { pool } = require('../config/db');
const BASE = `http://localhost:${process.env.PORT || 3000}`;
let pass = 0, fail = 0;

const call = async (method, path, { body, token } = {}) => {
  const r = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token && { Authorization: `Bearer ${token}` }) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let data = null; try { data = await r.json(); } catch { /* vide */ }
  return { status: r.status, data };
};
const check = (name, cond, extra = '') => {
  cond ? pass++ : fail++;
  console.log(`${cond ? '  ✔' : '  ✘'} ${name}${cond ? '' : '  → ' + extra}`);
};

(async () => {
  console.log('Santé');
  let r = await call('GET', '/api/health');
  check('GET /api/health = 200, db ok', r.status === 200 && r.data.db === 'ok', JSON.stringify(r));

  console.log('Login');
  r = await call('POST', '/api/entreprise/auth/login', { body: { cle: 'PSYTECH-2026' } });
  check('clé valide = 200 + token', r.status === 200 && typeof r.data.token === 'string', JSON.stringify(r));
  const token = r.data && r.data.token;
  check('réponse sans hash ni clé', !JSON.stringify(r.data).includes('cle_hash'));

  r = await call('POST', '/api/entreprise/auth/login', { body: { cle: '  psytech-2026 ' } });
  check('clé en minuscules/espaces acceptée (comme le Front)', r.status === 200, JSON.stringify(r));

  r = await call('POST', '/api/entreprise/auth/login', { body: { cle: 'PSYTECH-0000' } });
  check('mauvaise clé = 401', r.status === 401 && r.data.message === 'Clé entreprise invalide.', JSON.stringify(r));

  r = await call('POST', '/api/entreprise/auth/login', { body: { cle: 'ZZZ' } });
  check('clé inconnue = 401', r.status === 401, JSON.stringify(r));

  r = await call('POST', '/api/entreprise/auth/login', { body: { cle: '' } });
  check('clé vide = 400 avec errors[]', r.status === 400 && Array.isArray(r.data.errors), JSON.stringify(r));

  r = await call('POST', '/api/entreprise/auth/login', { body: { cle: 'PSYTECH-2026', admin: true } });
  check('champ inattendu = 400 (strict)', r.status === 400, JSON.stringify(r));

  r = await call('POST', '/api/entreprise/auth/login', { body: { cle: { $ne: '' } } });
  check('injection objet = 400', r.status === 400, JSON.stringify(r));

  console.log('Route protégée');
  r = await call('GET', '/api/entreprise/auth/me');
  check('sans token = 401', r.status === 401, JSON.stringify(r));

  r = await call('GET', '/api/entreprise/auth/me', { token: 'abc.def.ghi' });
  check('token falsifié = 401', r.status === 401, JSON.stringify(r));

  r = await call('GET', '/api/entreprise/auth/me', { token });
  check('token valide = 200 + entreprise', r.status === 200 && r.data.entreprise.email === 'demo@psytech.local', JSON.stringify(r));

  console.log('Invalidation de session');
  await pool.query("UPDATE entreprises SET cle_version = cle_version + 1 WHERE email = 'demo@psytech.local'");
  r = await call('GET', '/api/entreprise/auth/me', { token });
  check('clé régénérée => ancien token refusé (401)', r.status === 401, JSON.stringify(r));
  await pool.query("UPDATE entreprises SET cle_version = 1 WHERE email = 'demo@psytech.local'");

  r = await call('POST', '/api/entreprise/auth/login', { body: { cle: 'PSYTECH-2026' } });
  const t2 = r.data.token;
  await pool.query("UPDATE entreprises SET statut = 'inactif' WHERE email = 'demo@psytech.local'");
  r = await call('GET', '/api/entreprise/auth/me', { token: t2 });
  check('entreprise désactivée => token refusé (401)', r.status === 401, JSON.stringify(r));
  r = await call('POST', '/api/entreprise/auth/login', { body: { cle: 'PSYTECH-2026' } });
  check('entreprise désactivée => login 403', r.status === 403, JSON.stringify(r));
  await pool.query("UPDATE entreprises SET statut = 'actif' WHERE email = 'demo@psytech.local'");

  console.log('Divers');
  r = await call('GET', '/api/nimporte-quoi');
  check('route inconnue = 404 JSON', r.status === 404 && r.data.message, JSON.stringify(r));

  // Le limiteur (10 / 15 min) doit finir par bloquer.
  let blocked = false;
  for (let i = 0; i < 12 && !blocked; i++) {
    const x = await call('POST', '/api/entreprise/auth/login', { body: { cle: 'FAUX-' + i } });
    blocked = x.status === 429;
  }
  check('rate limit => 429 après trop de tentatives', blocked);

  console.log(`\n${pass} réussis, ${fail} échoués`);
  await pool.end();
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
