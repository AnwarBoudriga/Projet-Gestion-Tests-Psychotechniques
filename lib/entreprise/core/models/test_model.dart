class TestModel {
  const TestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.category,
    required this.minScore,
    required this.showScore,
    this.published = false,
    this.questionCount = 0,
  });

  /// Construit un test à partir de la réponse de l'API (/api/entreprise/tests).
  factory TestModel.fromJson(Map<String, dynamic> j) => TestModel(
    id: '${j['id']}',
    title: '${j['titre'] ?? ''}',
    description: '${j['description'] ?? ''}',
    durationMinutes: (j['dureeMinutes'] as num?)?.toInt() ?? 0,
    category: '${j['categorie'] ?? ''}',
    minScore: (j['scoreMinimum'] as num?)?.toInt() ?? 0,
    showScore: j['afficherScore'] == true,
    published: j['statut'] == 'publie',
    questionCount: (j['nbQuestions'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String title;
  final String description;
  final int durationMinutes;
  final String category;

  /// Score minimum de réussite, en pourcentage (0-100).
  final int minScore;
  final bool showScore;
  final bool published;

  /// Nombre de questions (renvoyé par l'API).
  final int questionCount;

  TestModel copyWith({bool? published, int? questionCount}) => TestModel(
    id: id,
    title: title,
    description: description,
    durationMinutes: durationMinutes,
    category: category,
    minScore: minScore,
    showScore: showScore,
    published: published ?? this.published,
    questionCount: questionCount ?? this.questionCount,
  );
}
