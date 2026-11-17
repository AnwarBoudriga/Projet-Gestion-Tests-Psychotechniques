import 'package:flutter/material.dart';

import '../../widgets/app_shell.dart';
import '../../widgets/page_header.dart';
import '../../navigation/app_router.dart';
import '../../services/app_store.dart';
import 'widgets/candidate_selection_card.dart';
import 'widgets/result_details_card.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  String? _invitationId;

  @override
  void initState() {
    super.initState();
    AppStore.instance.loadAll().catchError((Object _) {});
  }

  void _select(String id) {
    setState(() => _invitationId = id);
    // Le détail du résultat est chargé à la demande depuis l'API.
    AppStore.instance.loadResult(id);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    return AppShell(
      currentRoute: AppRoutes.results,
      pageLabel: 'Résultats',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Résultats des candidats',
            subtitle:
            'Consultez les résultats détaillés par candidat et exportez-les au format CSV ou PDF.',
          ),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final invitations = store.invitations;
              final matches =
              invitations.where((i) => i.id == _invitationId).toList();
              final selected = matches.isEmpty ? null : matches.first;
              final result = selected == null ? null : store.resultFor(selected.id);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CandidateSelectionCard(
                    invitations: invitations,
                    selected: selected,
                    hasResult: result != null,
                    onChanged: _select,
                  ),
                  const SizedBox(height: 20),
                  ResultDetailsCard(invitation: selected, result: result),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
