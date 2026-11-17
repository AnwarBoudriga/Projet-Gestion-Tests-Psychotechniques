const jwt = require('jsonwebtoken');
const db = require('../config/db');
const AppError = require('../utils/AppError');

if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
  console.error('[config] JWT_SECRET manquant ou trop court (32 caractères minimum).');
  process.exit(1);
}

const signToken = (payload, expiresIn = process.env.JWT_EXPIRES_IN || '8h') =>
  jwt.sign(payload, process.env.JWT_SECRET, { expiresIn });

function readToken(req, role) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) throw new AppError(401, 'Authentification requise.');
  let payload;
  try {
    payload = jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    throw new AppError(401, 'Token invalide ou expiré.');
  }
  if (payload.role !== role) throw new AppError(403, 'Accès non autorisé pour ce profil.');
  return payload;
}

// ---- Super Admin ------------------------------------------------------
function requireAuth(req, _res, next) {
  const p = readToken(req, 'super_admin');
  req.user = { id: p.sub, role: p.role };
  next();
}

// ---- Entreprise (RH): vérifie à CHAQUE requête que l'entreprise est active
async function requireEntreprise(req, _res, next) {
  const p = readToken(req, 'entreprise');
  const [rows] = await db.execute('SELECT id, nom, statut FROM entreprises WHERE id = ?', [p.sub]);
  const e = rows[0];
  if (!e) throw new AppError(401, 'Compte introuvable.');
  if (e.statut !== 'actif') throw new AppError(403, 'Entreprise désactivée. Contactez le Super Administrateur.');
  req.user = { id: e.id, role: 'entreprise' };
  req.entreprise = e;
  next();
}

// ---- Candidat ---------------------------------------------------------
// Toutes les durées sont calculées côté MySQL (NOW()) pour éviter les écarts de fuseau horaire.
const INVITATION_SQL = `
  SELECT i.*, t.titre, t.description, t.duree_minutes, t.score_minimum, t.afficher_score,
         t.statut AS test_statut, e.nom AS entreprise_nom, e.statut AS ent_statut,
         (i.expiration < NOW()) AS expiree,
         CASE WHEN i.started_at IS NULL THEN t.duree_minutes * 60
              ELSE GREATEST(0, TIMESTAMPDIFF(SECOND, NOW(), DATE_ADD(i.started_at, INTERVAL t.duree_minutes MINUTE)))
         END AS reste_secondes
  FROM invitations i
  JOIN tests t ON t.id = i.test_id
  JOIN entreprises e ON e.id = i.entreprise_id`;

async function chargerInvitation(id) {
  const [rows] = await db.execute(`${INVITATION_SQL} WHERE i.id = ?`, [id]);
  return rows[0] || null;
}

async function requireCandidat(req, _res, next) {
  const p = readToken(req, 'candidat');
  const inv = await chargerInvitation(p.sub);
  if (!inv) throw new AppError(401, 'Invitation introuvable.');
  if (inv.ent_statut !== 'actif') throw new AppError(403, 'Accès indisponible.');
  req.user = { id: inv.id, role: 'candidat' };
  req.inv = inv;
  next();
}

module.exports = {
  signToken,
  requireAuth,
  requireEntreprise,
  requireCandidat,
  chargerInvitation,
  INVITATION_SQL,
};
