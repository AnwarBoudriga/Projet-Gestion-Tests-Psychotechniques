import 'package:flutter/material.dart';

import 'admin/core/api.dart';
import 'admin/core/theme.dart';
import 'admin/screens/shell.dart';
import 'auth/unified_login_screen.dart';
import 'entreprise/core/navigation/app_router.dart';
import 'entreprise/core/services/api_client.dart';
import 'entreprise/core/services/app_store.dart';
import 'entreprise/core/theme/app_theme.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // L'API entreprise répond 401 (session expirée, clé régénérée, entreprise
    // désactivée) : retour à l'écran de connexion commun.
    ApiClient.onUnauthorized = () {
      AppStore.instance.reset();
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    };
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PsyTech Pro',
    navigatorKey: _navigatorKey,
    debugShowCheckedModeBanner: false,
    // Thème de l'espace Entreprise (les écrans admin sont enveloppés
    // dans leur propre Theme, voir AuthGate).
    theme: AppTheme.light(),
    // '/' (AppRoutes.login) affiche toujours AuthGate : la déconnexion
    // entreprise (pushNamedAndRemoveUntil('/')) revient donc au login commun.
    home: const AuthGate(),
    onGenerateRoute: AppRouter.onGenerateRoute,
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _adminLogged;

  @override
  void initState() {
    super.initState();
    Api.onUnauthorized = () {
      if (mounted) setState(() => _adminLogged = false);
    };
    Api.hasToken().then((v) {
      if (mounted) setState(() => _adminLogged = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_adminLogged == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Session admin active : on garde l'espace Super Administrateur.
    if (_adminLogged!) {
      return Theme(
        data: buildTheme(),
        child: Shell(onLogout: () async {
          await Api.logout();
          if (mounted) setState(() => _adminLogged = false);
        }),
      );
    }

    return Theme(
      data: buildTheme(),
      child: UnifiedLoginScreen(
        onAdminLoggedIn: () => setState(() => _adminLogged = true),
        onEntrepriseLoggedIn: () =>
            Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard),
      ),
    );
  }
}
