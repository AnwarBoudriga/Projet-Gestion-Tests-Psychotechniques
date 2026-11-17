// Calcule le score d'une invitation (somme des points des bonnes réponses).
async function calculerScore(conn, invitationId, testId) {
  const [[r]] = await conn.query(
    `SELECT COALESCE(SUM(CASE WHEN rp.choix = q.reponse_correcte THEN q.points END), 0) AS score,
            COALESCE(SUM(q.points), 0) AS score_max
     FROM test_questions tq
     JOIN questions q ON q.id = tq.question_id
     LEFT JOIN reponses rp ON rp.question_id = q.id AND rp.invitation_id = ?
     WHERE tq.test_id = ?`,
    [invitationId, testId]
  );
  return { score: Number(r.score), scoreMax: Number(r.score_max) };
}
module.exports = { calculerScore };
