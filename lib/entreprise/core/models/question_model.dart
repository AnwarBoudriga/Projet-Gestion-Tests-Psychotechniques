class QuestionModel {
  const QuestionModel({
    required this.id,
    required this.testId,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.points,
  });

  /// Construit une question à partir de l'API
  /// ({enonce, optionA..D, reponseCorrecte: 'A'..'D', points}).
  factory QuestionModel.fromJson(Map<String, dynamic> j, {String testId = ''}) =>
      QuestionModel(
        id: '${j['id']}',
        testId: testId,
        text: '${j['enonce'] ?? ''}',
        options: [
          '${j['optionA'] ?? ''}',
          '${j['optionB'] ?? ''}',
          '${j['optionC'] ?? ''}',
          '${j['optionD'] ?? ''}',
        ],
        correctIndex: _letters.indexOf('${j['reponseCorrecte']}').clamp(0, 3),
        points: (j['points'] as num?)?.toInt() ?? 1,
      );

  static const _letters = ['A', 'B', 'C', 'D'];

  final String id;

  /// Vide pour une question de la banque.
  final String testId;
  final String text;
  final List<String> options;
  final int correctIndex;
  final int points;

  String get correctLabel => String.fromCharCode(65 + correctIndex);

  String optionLabel(int index) =>
      '${String.fromCharCode(65 + index)}. ${options[index]}';

  /// Corps JSON attendu par l'API (création / modification).
  Map<String, dynamic> toApiBody() => {
    'enonce': text,
    'optionA': options[0],
    'optionB': options[1],
    'optionC': options[2],
    'optionD': options[3],
    'reponseCorrecte': _letters[correctIndex],
    'points': points,
  };

  QuestionModel copyWith({
    String? id,
    String? testId,
    String? text,
    List<String>? options,
    int? correctIndex,
    int? points,
  }) =>
      QuestionModel(
        id: id ?? this.id,
        testId: testId ?? this.testId,
        text: text ?? this.text,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        points: points ?? this.points,
      );
}
