import 'package:flutter/foundation.dart';

import '../models/candidate_result.dart';
import '../models/invitation_model.dart';
import '../models/question_model.dart';
import '../models/test_model.dart';
import 'api_client.dart';
import 'csv_parser.dart';
import 'download_service.dart';

/// Chiffres du tableau de bord (/api/entreprise/dashboard).
class DashboardStats {
  const DashboardStats({this.tests = 0, this.candidats = 0, this.tauxReussite});

  final int tests;
  final int candidats;

  /// Pourcentage 0-100, ou null s'il n'y a encore aucun résultat.
  final double? tauxReussite;
}

/// Résultat d'un import CSV côté serveur.
class ImportOutcome {
  const ImportOutcome(this.created, this.rejected);

  final int created;
  final int rejected;
}

/// Magasin de données de l'espace Entreprise, branché sur l'API.
///
/// Il remplace l'ancien AppStore en gardant la même forme : les écrans lisent
/// des getters synchrones (cache) et se redessinent via [notifyListeners].
/// Les actions qui modifient les données sont asynchrones et lèvent une
/// exception (DioException) en cas d'erreur : l'écran affiche alors
/// `ApiClient.errorMessage(e)`.
class AppStore extends ChangeNotifier {
  AppStore._();

  static final AppStore instance = AppStore._();

  List<TestModel> _tests = [];
  final Map<String, List<QuestionModel>> _questions = {};
  List<QuestionModel> _bank = [];
  List<InvitationModel> _invitations = [];
  final Map<String, CandidateResult> _results = {};
  DashboardStats _stats = const DashboardStats();
  String? _selectedTestId;

  // ---------------- Lecture ----------------
  List<TestModel> get tests => List.unmodifiable(_tests);
  List<TestModel> get publishedTests =>
      _tests.where((t) => t.published).toList();
  TestModel? get selectedTest => testById(_selectedTestId);
  DashboardStats get stats => _stats;

  TestModel? testById(String? id) {
    if (id == null) return null;
    for (final t in _tests) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<QuestionModel> questionsOf(String testId) =>
      List.unmodifiable(_questions[testId] ?? const <QuestionModel>[]);

  /// Nombre de questions : liste chargée si disponible, sinon valeur de l'API.
  int questionCountOf(TestModel t) =>
      _questions[t.id]?.length ?? t.questionCount;

  List<QuestionModel> get selectedQuestions {
    final t = selectedTest;
    return t == null ? <QuestionModel>[] : questionsOf(t.id);
  }

  List<QuestionModel> get bank => List.unmodifiable(_bank);

  /// Plus récentes d'abord (l'API trie déjà ainsi).
  List<InvitationModel> get invitations => List.unmodifiable(_invitations);

  CandidateResult? resultFor(String invitationId) => _results[invitationId];

  // ---------------- Chargement ----------------
  /// Recharge tout depuis l'API (après connexion, à l'ouverture des écrans).
  Future<void> loadAll() async {
    await Future.wait([
      loadTests(),
      loadBank(),
      loadInvitations(),
      loadStats(),
    ]);
  }

  /// Vide le cache (déconnexion).
  void reset() {
    _tests = [];
    _questions.clear();
    _bank = [];
    _invitations = [];
    _results.clear();
    _stats = const DashboardStats();
    _selectedTestId = null;
    notifyListeners();
  }

  Future<void> loadTests() async {
    final r = await ApiClient.dio.get('/api/entreprise/tests');
    _tests = [
      for (final j in (r.data['data'] as List)) TestModel.fromJson(j as Map<String, dynamic>),
    ];
    if (testById(_selectedTestId) == null) {
      _selectedTestId = _tests.isEmpty ? null : _tests.first.id;
    }
    notifyListeners();
    final id = _selectedTestId;
    if (id != null) await loadQuestions(id);
  }

  Future<void> loadQuestions(String testId) async {
    final r = await ApiClient.dio.get('/api/entreprise/tests/$testId/questions');
    _setQuestions(testId, r.data);
  }

  void _setQuestions(String testId, dynamic body) {
    final list = [
      for (final j in (body['data'] as List))
        QuestionModel.fromJson(j as Map<String, dynamic>, testId: testId),
    ];
    _questions[testId] = list;
    final t = testById(testId);
    if (t != null) _replaceTest(t.copyWith(questionCount: list.length), notify: false);
    notifyListeners();
  }

  Future<void> loadBank() async {
    final r = await ApiClient.dio
        .get('/api/entreprise/banque', queryParameters: {'limit': 100});
    _bank = [
      for (final j in (r.data['data'] as List)) QuestionModel.fromJson(j as Map<String, dynamic>),
    ];
    notifyListeners();
  }

  Future<void> loadInvitations() async {
    final r = await ApiClient.dio
        .get('/api/entreprise/invitations', queryParameters: {'limit': 200});
    _invitations = [
      for (final j in (r.data['data'] as List))
        InvitationModel.fromJson(j as Map<String, dynamic>),
    ];
    notifyListeners();
  }

  Future<void> loadStats() async {
    final r = await ApiClient.dio.get('/api/entreprise/dashboard');
    final d = r.data as Map;
    _stats = DashboardStats(
      tests: (d['tests'] as num?)?.toInt() ?? 0,
      candidats: (d['candidats'] as num?)?.toInt() ?? 0,
      tauxReussite: (d['tauxReussite'] as num?)?.toDouble(),
    );
    notifyListeners();
  }

  // ---------------- Tests ----------------
  void selectTest(String? id) {
    _selectedTestId = id;
    notifyListeners();
    if (id != null) {
      // Chargement en arrière-plan : l'écran se met à jour via notifyListeners.
      loadQuestions(id).catchError((Object _) {});
    }
  }

  Future<TestModel> createTest({
    required String title,
    required String description,
    required int durationMinutes,
    required String category,
    required int minScore,
    required bool showScore,
  }) async {
    final r = await ApiClient.dio.post('/api/entreprise/tests', data: {
      'titre': title,
      'description': description,
      'dureeMinutes': durationMinutes,
      'categorie': category,
      'scoreMinimum': minScore,
      'afficherScore': showScore,
    });
    final t = TestModel.fromJson(r.data as Map<String, dynamic>);
    _tests = [t, ..._tests];
    _questions[t.id] = [];
    _selectedTestId ??= t.id;
    notifyListeners();
    loadStats().catchError((Object _) {});
    return t;
  }

  Future<TestModel> duplicateTest(String id) async {
    final r = await ApiClient.dio.post('/api/entreprise/tests/$id/dupliquer');
    final copy = TestModel.fromJson(r.data as Map<String, dynamic>);
    _tests = [copy, ..._tests];
    _selectedTestId = copy.id;
    notifyListeners();
    loadQuestions(copy.id).catchError((Object _) {});
    loadStats().catchError((Object _) {});
    return copy;
  }

  /// Lève une exception si l'API refuse (ex. aucune question).
  Future<void> publishTest(String id) async {
    final r = await ApiClient.dio.patch('/api/entreprise/tests/$id/publier');
    _replaceTest(TestModel.fromJson(r.data as Map<String, dynamic>));
  }

  Future<void> unpublishTest(String id) async {
    final r = await ApiClient.dio.patch('/api/entreprise/tests/$id/depublier');
    _replaceTest(TestModel.fromJson(r.data as Map<String, dynamic>));
  }

  void _replaceTest(TestModel t, {bool notify = true}) {
    final i = _tests.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      _tests = [..._tests]..[i] = t;
      if (notify) notifyListeners();
    }
  }

  // ---------------- Questions ----------------
  Future<void> addQuestion({
    required String testId,
    required String text,
    required List<String> options,
    required int correctIndex,
    required int points,
  }) async {
    final q = QuestionModel(
      id: '',
      testId: testId,
      text: text,
      options: options,
      correctIndex: correctIndex,
      points: points,
    );
    final r = await ApiClient.dio
        .post('/api/entreprise/tests/$testId/questions', data: q.toApiBody());
    _setQuestions(testId, r.data);
  }

  Future<void> updateQuestion(QuestionModel q) async {
    final r = await ApiClient.dio.put(
        '/api/entreprise/tests/${q.testId}/questions/${q.id}',
        data: q.toApiBody());
    _setQuestions(q.testId, r.data);
  }

  Future<void> deleteQuestion(String id) async {
    final testId = _testIdOfQuestion(id);
    if (testId == null) return;
    final r =
    await ApiClient.dio.delete('/api/entreprise/tests/$testId/questions/$id');
    _setQuestions(testId, r.data);
  }

  /// [delta] = -1 (monter) ou +1 (descendre).
  Future<void> moveQuestion(String id, int delta) async {
    final testId = _testIdOfQuestion(id);
    if (testId == null) return;
    final action = delta < 0 ? 'monter' : 'descendre';
    final r = await ApiClient.dio
        .post('/api/entreprise/tests/$testId/questions/$id/$action');
    _setQuestions(testId, r.data);
  }

  /// Retourne le nombre de questions réellement ajoutées.
  Future<int> addFromBank(String testId, Iterable<String> bankIds) async {
    final before = _questions[testId]?.length ?? 0;
    final r = await ApiClient.dio.post(
      '/api/entreprise/tests/$testId/questions/banque',
      data: {'questionIds': [for (final b in bankIds) int.parse(b)]},
    );
    _setQuestions(testId, r.data);
    return (_questions[testId]?.length ?? 0) - before;
  }

  String? _testIdOfQuestion(String id) {
    for (final e in _questions.entries) {
      if (e.value.any((q) => q.id == id)) return e.key;
    }
    return null;
  }

  // ---------------- Invitations ----------------
  /// Retourne l'invitation avec sa clé en clair (affichée une seule fois).
  Future<InvitationModel> createInvitation({
    required String name,
    required String email,
    required TestModel test,
    required int days,
  }) async {
    final r = await ApiClient.dio.post('/api/entreprise/invitations', data: {
      'nom': name,
      'email': email,
      'testId': int.parse(test.id),
      'expirationJours': days,
    });
    final d = r.data as Map;
    await Future.wait([loadInvitations(), loadStats()]);
    return InvitationModel(
      id: '${d['id']}',
      name: name,
      email: email,
      testId: test.id,
      testTitle: test.title,
      expiresAt: DateTime.now().add(Duration(days: days)),
      key: '${d['cle']}',
    );
  }

  Future<ImportOutcome> createInvitations(List<CsvRow> rows,
      {required TestModel test, required int days}) async {
    final csv = StringBuffer('nom,email\n');
    for (final r in rows) {
      csv.writeln('${_csvCell(r.name)},${_csvCell(r.email)}');
    }
    final r = await ApiClient.dio.post('/api/entreprise/invitations/import', data: {
      'testId': int.parse(test.id),
      'expirationJours': days,
      'csv': csv.toString(),
    });
    final d = r.data as Map;
    await Future.wait([loadInvitations(), loadStats()]);
    return ImportOutcome(
      (d['crees'] as List).length,
      (d['erreurs'] as List).length,
    );
  }

  String _csvCell(String v) =>
      v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

  // ---------------- Résultats ----------------
  /// Charge le détail d'un résultat (404 si le candidat n'a pas terminé).
  Future<CandidateResult?> loadResult(String invitationId) async {
    try {
      final r = await ApiClient.dio.get('/api/entreprise/resultats/$invitationId');
      final j = r.data as Map<String, dynamic>;
      final min = testById('${j['testId']}')?.minScore ?? 0;
      final res = CandidateResult.fromJson(j, minScore: min);
      _results[invitationId] = res;
      notifyListeners();
      return res;
    } catch (_) {
      _results.remove(invitationId);
      notifyListeners();
      return null;
    }
  }

  Future<void> exportResult(String invitationId, String format) =>
      DownloadService.download(
        '/api/entreprise/resultats/$invitationId/export.$format',
        'resultat-$invitationId.$format',
        format == 'pdf' ? 'application/pdf' : 'text/csv',
      );
}
