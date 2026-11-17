const { Pool } = require('pg');
const { databaseUrl } = require('./env');

const pool = new Pool({ connectionString: databaseUrl, max: 10 });
pool.on('error', (err) => console.error('[db] erreur inattendue sur le pool :', err.message));

/** Requête paramétrée (jamais de concaténation de valeurs utilisateur). */
const query = (text, params) => pool.query(text, params);

/** Exécute fn(client) dans une transaction. */
async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const out = await fn(client);
    await client.query('COMMIT');
    return out;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

module.exports = { pool, query, withTransaction };
