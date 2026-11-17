import 'package:dio/dio.dart';

import 'api_client.dart';
import 'app_store.dart';

/// Authentification entreprise : la clé entreprise est vérifiée par l'API,
/// qui renvoie un JWT conservé de façon sécurisée.
///
/// La signature `loginWithCompanyKey(String) -> Future<bool>` est inchangée :
/// l'écran de connexion (LoginForm) n'a donc pas besoin d'être modifié.
class AuthService {
  Future<bool> loginWithCompanyKey(String key) async {
    try {
      final r = await ApiClient.dio.post(
        '/api/entreprise/auth/login',
        data: {'cle': key.trim()},
      );
      final token = r.data['token'];
      if (token is! String) return false;
      await ApiClient.saveToken(token);
      // Charge les données de l'entreprise (tests, banque, invitations, chiffres).
      try {
        await AppStore.instance.loadAll();
      } catch (_) {
        // Les écrans rechargent à l'ouverture : on ne bloque pas la connexion.
      }
      return true;
    } on DioException {
      // 401 (clé invalide), 403 (compte désactivé), 429 (trop de tentatives), réseau…
      return false;
    }
  }

  Future<void> logout() async {
    await ApiClient.clearToken();
    AppStore.instance.reset();
  }
}