import 'package:flutter/material.dart';

import 'core/navigation/app_router.dart';
import 'core/services/api_client.dart';
import 'core/services/app_store.dart';
import 'core/theme/app_theme.dart';

class PsyTechApp extends StatefulWidget {
  const PsyTechApp({super.key});

  @override
  State<PsyTechApp> createState() => _PsyTechAppState();
}

class _PsyTechAppState extends State<PsyTechApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // L'API répond 401 (session expirée, clé régénérée, entreprise désactivée) :
    // retour à l'écran de connexion.
    ApiClient.onUnauthorized = () {
      AppStore.instance.reset();
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PsyTech Pro',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
