import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';

class PsyTechApp extends StatelessWidget {
  const PsyTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PsyTech Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
