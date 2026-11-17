const jwt = require('jsonwebtoken');
const { jwtSecret } = require('../config/env');
const { query } = require('../config/db');
const { unauthorized } = require('../utils/errors');
const asyncHandler = require('../utils/asyncHandler');

/**
 * Vérifie le JWT puis recharge l'entreprise en base : une entreprise désactivée, ou dont la clé
 * a été régénérée (cle_version), perd l'accès immédiatement sans attendre l'expiration du token.
 * L'identifiant d'entreprise vient TOUJOURS du token, jamais du client.
 */
module.exports = asyncHandler(async (req, _res, next) => {
  const [scheme, token] = (req.headers.authorization || '').split(' ');
  if (scheme !== 'Bearer' || !token) throw unauthorized();

  let payload;
  try {
    payload = jwt.verify(token, jwtSecret, { algorithms: ['HS256'] });
  } catch {
    throw unauthorized('Session expirée ou invalide.');
  }
  if (payload.role !== 'entreprise') throw unauthorized();

  const { rows } = await query(
    'SELECT id, nom, email, statut, cle_version FROM entreprises WHERE id = $1',
    [payload.sub]
  );
  const e = rows[0];
  if (!e || e.statut !== 'actif' || e.cle_version !== payload.kv) {
    throw unauthorized('Session expirée ou invalide.');
  }
  req.entreprise = { id: e.id, nom: e.nom, email: e.email };
  next();
});
