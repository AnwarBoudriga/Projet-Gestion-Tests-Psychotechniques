class ResultLine {
  const ResultLine({
    required this.question,
    required this.chosen,
    required this.correct,
    required this.earned,
    required this.points,
  });

  final String question;
  final String chosen;
  final String correct;
  final int earned;
  final int points;
}

class CandidateResult {
  const CandidateResult({
    required this.invitationId,
    required this.lines,
    required this.minScore,
    this.serverPassed,
  });

  /// Construit le résultat à partir de /api/entreprise/resultats/:invitationId.
  factory CandidateResult.fromJson(Map<String, dynamic> j, {required int minScore}) {
    String label(Map opts, String? letter) =>
        letter == null ? '—' : '$letter. ${opts[letter] ?? ''}';
    final qs = (j['questions'] as List? ?? const []).cast<Map>();
    return CandidateResult(
      invitationId: '${j['invitationId']}',
      minScore: minScore,
      serverPassed: j['reussi'] as bool?,
      lines: [
        for (final q in qs)
          ResultLine(
            question: '${q['enonce']}',
            chosen: label(q['options'] as Map, q['reponseCandidat'] as String?),
            correct: label(q['options'] as Map, q['reponseCorrecte'] as String?),
            earned: (q['pointsObtenus'] as num?)?.toInt() ?? 0,
            points: (q['points'] as num?)?.toInt() ?? 0,
          ),
      ],
    );
  }

  final String invitationId;
  final List<ResultLine> lines;
  final int minScore;

  /// Verdict calculé par l'API (prioritaire sur le calcul local).
  final bool? serverPassed;

  int get score => lines.fold(0, (sum, l) => sum + l.earned);
  int get total => lines.fold(0, (sum, l) => sum + l.points);
  double get percent => total == 0 ? 0 : score * 100 / total;
  bool get passed => serverPassed ?? percent >= minScore;
}
