import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Client HTTP de l'espace Entreprise (Dio).
///
/// URL de l'API : flutter run --dart-define=API_URL=http://10.0.2.2:3000
/// (10.0.2.2 = localhost vu depuis l'émulateur Android ; http://localhost:3000 pour le web / desktop).
///
/// Le token est stocké sous une clé distincte de celle de l'espace Super Admin ('token'),
/// pour que les deux sessions ne s'écrasent pas.
class ApiClient {
  ApiClient._();

  static const String baseUrl =
  String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');

  static const _tokenKey = 'entreprise_token';
  static const _storage = FlutterSecureStorage();

  /// Appelé quand l'API répond 401 (session expirée, clé régénérée, entreprise désactivée).
  static VoidCallback? onUnauthorized;

  static final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    contentType: Headers.jsonContentType,
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) async {
        final isLogin = e.requestOptions.path.contains('/auth/login');
        if (e.response?.statusCode == 401 && !isLogin) {
          await clearToken();
          onUnauthorized?.call();
        }
        handler.next(e);
      },
    ));

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Future<bool> hasToken() async =>
      (await _storage.read(key: _tokenKey)) != null;

  /// Message lisible à partir d'une erreur Dio (format API : {message, errors[]}).
  static String errorMessage(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map) {
        final errs = d['errors'];
        if (errs is List && errs.isNotEmpty) {
          return errs.map((x) => x['message']).join('\n');
        }
        if (d['message'] != null) return d['message'].toString();
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Serveur injoignable.';
      }
    }
    return 'Une erreur est survenue.';
  }
}