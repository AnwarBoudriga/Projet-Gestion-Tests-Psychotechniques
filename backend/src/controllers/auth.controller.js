const jwt = require('jsonwebtoken');
const { query } = require('../config/db');
const bcrypt = require('bcrypt');
const { jwtSecret, jwtExpiresIn, bcryptRounds } = require('../config/env');
const { unauthorized, forbidden } = require('../utils/errors');
const { prefixOf, verifyKey } = require('../utils/keys');

// Hash factice : on fait toujours un bcrypt.compare, même si la clé est inconnue,
// pour ne pas révéler par le temps de réponse si un préfixe existe.
const DUMMY_HASH = bcrypt.hashSync('dummy-key-never-matches', bcryptRounds);

exports.login = async (req, res) => {
  const { cle } = req.body;

  const { rows } = await query(
    'SELECT id, nom, email, statut, cle_hash, cle_version FROM entreprises WHERE cle_prefix = $1 AND cle_hash IS NOT NULL',
    [prefixOf(cle)]
  );

  let match = null;
  for (const row of rows) {
    if (await verifyKey(cle, row.cle_hash)) { match = row; break; }
  }
  if (!match) {
    if (rows.length === 0) await verifyKey(cle, DUMMY_HASH);
    throw unauthorized('Clé entreprise invalide.');
  }
  if (match.statut !== 'actif') throw forbidden('Ce compte entreprise est désactivé.');

  const token = jwt.sign(
    { sub: match.id, role: 'entreprise', kv: match.cle_version },
    jwtSecret,
    { algorithm: 'HS256', expiresIn: jwtExpiresIn }
  );

  res.json({
    token,
    entreprise: { id: match.id, nom: match.nom, email: match.email },
  });
};

exports.me = (req, res) => res.json({ entreprise: req.entreprise });
