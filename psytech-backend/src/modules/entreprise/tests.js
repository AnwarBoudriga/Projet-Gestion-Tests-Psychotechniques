const router = require('express').Router();
const { z } = require('zod');
const db = require('../../config/db');
const validate = require('../../middlewares/validate');
const AppError = require('../../utils/AppError');
const { logAction } = require('../../utils/audit');
const { parseId, TEST_SELECT, fmtTest, getTest } = require('./helpers');

const testSchema = z.object({
  titre: z.string().trim().min(2, 'Titre requis').max(200),
  description: z.string().trim().max(5000).optional().default(''),
  dureeMinutes: z.coerce.number().int().min(1, 'Durée >= 1 minute').max(600),
  categorie: z.string().trim().max(100).optional().default(''),
  scoreMinimum: z.coerce.number().int().min(0).optional().default(0),
  afficherScore: z.boolean().optional().default(false),
});

// GET /api/entreprise/tests?statut=publie|brouillon
router.get('/', async (req, res) => {
  const statut = ['publie', 'brouillon'].includes(req.query.statut) ? req.query.statut : null;
  const [rows] = await db.query(
    `${TEST_SELECT} WHERE t.entreprise_id = ? ${statut ? 'AND t.statut = ?' : ''} ORDER BY t.created_at DESC, t.id DESC`,
    statut ? [req.user.id, statut] : [req.user.id]
  );
  res.json({ data: rows.map(fmtTest) });
});

// POST /api/entreprise/tests
router.post('/', validate(testSchema), async (req, res) => {
  const t = req.valid;
  const [r] = await db.execute(
    `INSERT INTO tests (entreprise_id, titre, description, duree_minutes, categorie, score_minimum, afficher_score)
     VALUES (?,?,?,?,?,?,?)`,
    [req.user.id, t.titre, t.description, t.dureeMinutes, t.categorie, t.scoreMinimum, t.afficherScore ? 1 : 0]
  );
  await logAction(req, { action: 'TEST_CREE', entite: 'test', entiteId: r.insertId });
  res.status(201).json(fmtTest(await getTest(req.user.id, r.insertId)));
});

// GET /api/entreprise/tests/:id
router.get('/:id', async (req, res) => res.json(fmtTest(await getTest(req.user.id, parseId(req.params.id)))));

// PUT /api/entreprise/tests/:id   (refusé si publié)
router.put('/:id', validate(testSchema), async (req, res) => {
  const test = await getTest(req.user.id, parseId(req.params.id));
  if (test.statut === 'publie') throw new AppError(409, 'Dépubliez le test avant de le modifier.');
  const t = req.valid;
  await db.execute(
    `UPDATE tests SET titre=?, description=?, duree_minutes=?, categorie=?, score_minimum=?, afficher_score=? WHERE id=?`,
    [t.titre, t.description, t.dureeMinutes, t.categorie, t.scoreMinimum, t.afficherScore ? 1 : 0, test.id]
  );
  await logAction(req, { action: 'TEST_MODIFIE', entite: 'test', entiteId: test.id });
  res.json(fmtTest(await getTest(req.user.id, test.id)));
});

// POST /api/entreprise/tests/:id/dupliquer
// Les questions de la banque sont partagées; les questions propres à l'entreprise sont COPIÉES.
router.post('/:id/dupliquer', async (req, res) => {
  const src = await getTest(req.user.id, parseId(req.params.id));
  const conn = await db.getConnection();
  let newId;
  try {
    await conn.beginTransaction();
    const [r] = await conn.execute(
      `INSERT INTO tests (entreprise_id, titre, description, duree_minutes, categorie, score_minimum, afficher_score, statut, duplique_de)
       VALUES (?,?,?,?,?,?,?, 'brouillon', ?)`,
      [src.entreprise_id, `${src.titre} (copie)`.slice(0, 200), src.description, src.duree_minutes, src.categorie, src.score_minimum, src.afficher_score, src.id]
    );
    newId = r.insertId;
    const [links] = await conn.query(
      `SELECT q.*, tq.position FROM test_questions tq JOIN questions q ON q.id = tq.question_id
       WHERE tq.test_id = ? ORDER BY tq.position`,
      [src.id]
    );
    for (const q of links) {
      let qid = q.id;
      if (q.entreprise_id !== null) {
        const [c] = await conn.execute(
          `INSERT INTO questions (entreprise_id, enonce, option_a, option_b, option_c, option_d, reponse_correcte, points)
           VALUES (?,?,?,?,?,?,?,?)`,
          [q.entreprise_id, q.enonce, q.option_a, q.option_b, q.option_c, q.option_d, q.reponse_correcte, q.points]
        );
        qid = c.insertId;
      }
      await conn.execute('INSERT INTO test_questions (test_id, question_id, position) VALUES (?,?,?)', [newId, qid, q.position]);
    }
    await conn.commit();
  } catch (e) {
    await conn.rollback();
    throw e;
  } finally {
    conn.release();
  }
  await logAction(req, { action: 'TEST_DUPLIQUE', entite: 'test', entiteId: newId, details: { source: src.id } });
  res.status(201).json(fmtTest(await getTest(req.user.id, newId)));
});

// PATCH /api/entreprise/tests/:id/publier
router.patch('/:id/publier', async (req, res) => {
  const test = await getTest(req.user.id, parseId(req.params.id));
  if (Number(test.nb_questions) < 1) throw new AppError(409, 'Ajoutez au moins une question avant de publier.');
  if (test.score_minimum > Number(test.total_points)) {
    throw new AppError(409, `Le score minimum (${test.score_minimum}) dépasse le total des points (${test.total_points}).`);
  }
  await db.execute(`UPDATE tests SET statut = 'publie' WHERE id = ?`, [test.id]);
  await logAction(req, { action: 'TEST_PUBLIE', entite: 'test', entiteId: test.id });
  res.json(fmtTest(await getTest(req.user.id, test.id)));
});

// PATCH /api/entreprise/tests/:id/depublier
router.patch('/:id/depublier', async (req, res) => {
  const test = await getTest(req.user.id, parseId(req.params.id));
  const [[r]] = await db.execute(`SELECT COUNT(*) AS n FROM invitations WHERE test_id = ? AND statut = 'en_cours'`, [test.id]);
  if (Number(r.n) > 0) throw new AppError(409, 'Des candidats ont un test en cours: dépublication impossible pour le moment.');
  await db.execute(`UPDATE tests SET statut = 'brouillon' WHERE id = ?`, [test.id]);
  await logAction(req, { action: 'TEST_DEPUBLIE', entite: 'test', entiteId: test.id });
  res.json(fmtTest(await getTest(req.user.id, test.id)));
});

module.exports = router;
