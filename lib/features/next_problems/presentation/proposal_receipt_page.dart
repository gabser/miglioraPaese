import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_document_widgets.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_scope_notice.dart';

class ProposalReceiptPage extends StatelessWidget {
  const ProposalReceiptPage({
    required this.routeContext,
    this.problemId,
    super.key,
  });
  final ProposalRouteContext routeContext;
  final String? problemId;

  @override
  Widget build(BuildContext context) {
    final municipality = routeContext.municipalityId;
    if (municipality == null) {
      return ProposalScopeNotice(
        invalid: routeContext.invalid,
        returnTo: '/next-problems',
      );
    }
    final data = context.watch<LocalDataStore>();
    final scope = ProposalScope.fromConfig(
      municipalityId: municipality,
      config: context.read<AppConfig>(),
      namespace: data.namespace,
    );
    final view = context.watch<ProposalSubmissionCoordinator>().savedReceipt(
      scope,
      problemId: problemId,
    );
    final valid = ProposalRouteContext.validProblemId(problemId);
    final intent = valid ? view.intent : null;
    return ProposalDocumentScaffold(
      title: 'Conferma dell’invio',
      municipalityId: municipality,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (intent != null) ...[
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                'Invio ricevuto',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppTokens.s12),
            ProposalDocument(
              problem: intent.receipt!,
              municipalityId: municipality,
              snapshot: true,
              acceptedAt: intent.acceptedAt,
            ),
            const SizedBox(height: AppTokens.s12),
            FilledButton(
              onPressed: () => context.push(
                ProposalRouteContext.detailLocation(
                  intent.receipt!.id,
                  municipality,
                ),
              ),
              child: const Text('Apri il dettaglio aggiornato'),
            ),
          ] else
            FcPanel(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  view.status == SubmissionStatus.storageFailed
                      ? 'La ricevuta locale non è leggibile. Non inviare di nuovo per recuperarla.'
                      : 'La ricevuta non è disponibile su questo dispositivo per questo Comune. Potrebbe essere stata cancellata con i dati locali.',
                ),
              ),
            ),
          const SizedBox(height: AppTokens.s12),
          TextButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(
                  ProposalRouteContext.location('/next-problems', municipality),
                );
              }
            },
            child: Text(
              context.canPop() ? 'Torna indietro' : 'Torna alle proposte',
            ),
          ),
        ],
      ),
    );
  }
}
