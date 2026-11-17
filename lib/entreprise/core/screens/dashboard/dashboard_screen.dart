import 'package:flutter/material.dart';

import '../../widgets/app_shell.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_card.dart';
import '../../navigation/app_router.dart';
import '../../services/app_store.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Rafraîchit les chiffres à chaque ouverture (les candidats passent leurs tests en parallèle).
    AppStore.instance.loadAll().catchError((Object _) {});
  }

  // Les maquettes affichent « — » tant qu'il n'y a pas de données.
  static const String _empty = '—';

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    return AppShell(
      currentRoute: AppRoutes.dashboard,
      pageLabel: 'Tableau de bord',
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final stats = store.stats;
          final rate = stats.tauxReussite == null
              ? _empty
              : '${stats.tauxReussite!.round()} %';

          final cards = [
            StatCard(
              label: 'Tests',
              icon: Icons.assignment_outlined,
              value: stats.tests == 0 ? _empty : '${stats.tests}',
            ),
            StatCard(
              label: 'Candidats',
              icon: Icons.group_outlined,
              value: stats.candidats == 0 ? _empty : '${stats.candidats}',
            ),
            StatCard(
              label: 'Taux de réussite',
              icon: Icons.check_circle_outline,
              value: rate,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(title: 'Tableau de bord'),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: [
                        for (final c in cards) ...[c, const SizedBox(height: 16)],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
