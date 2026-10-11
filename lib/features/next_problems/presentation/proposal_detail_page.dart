import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_detail_cubit.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_document_widgets.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_scope_notice.dart';

class ProposalDetailPage extends StatelessWidget {
  const ProposalDetailPage({
    required this.routeContext,
    required this.problemId,
    super.key,
  });
  final ProposalRouteContext routeContext;
  final String problemId;

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
    return BlocProvider(
      key: ValueKey([scope.key, problemId].join(':')),
      create: (context) => ProposalDetailCubit(
        repository: context.read<NextProblemsRepository>(),
        scope: scope,
        problemId: problemId,
        data: data,
        receipts: context.read<ProposalSubmissionCoordinator>(),
      )..load(),
      child: _DetailView(scope: scope, problemId: problemId),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.scope, required this.problemId});
  final ProposalScope scope;
  final String problemId;

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<ProposalSubmissionCoordinator>().savedReceipt(
      scope,
      problemId: problemId,
    );
    return ProposalDocumentScaffold(
      title: 'Dettaglio della proposta',
      municipalityId: scope.municipalityId,
      child: BlocBuilder<ProposalDetailCubit, ProposalDetailState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.read<AppConfig>().nextProblemsDataSource ==
                      NextProblemsDataSource.mock
                  ? 'Demo locale · Dettaglio aggiornato'
                  : 'Proposte online · Dettaglio aggiornato',
            ),
            const SizedBox(height: AppTokens.s12),
            if (state.status == ProposalDetailStatus.loading)
              const Center(child: CircularProgressIndicator())
            else if (state.problem != null) ...[
              ProposalDocument(
                problem: state.problem!,
                municipalityId: scope.municipalityId,
                snapshot: false,
              ),
              TextButton.icon(
                onPressed: context.read<ProposalDetailCubit>().load,
                icon: const Icon(Icons.refresh),
                label: const Text('Aggiorna il dettaglio'),
              ),
            ] else ...[
              FcPanel(
                child: Semantics(
                  liveRegion: true,
                  child: Text(state.message ?? 'Proposta non disponibile.'),
                ),
              ),
              if (state.status == ProposalDetailStatus.unavailable ||
                  state.status == ProposalDetailStatus.scopeLost)
                FilledButton(
                  onPressed: context.read<ProposalDetailCubit>().load,
                  child: const Text('Riprova'),
                ),
            ],
            if (saved.intent != null) ...[
              const SizedBox(height: AppTokens.s12),
              TextButton(
                onPressed: () => context.push(
                  ProposalRouteContext.receiptLocation(
                    problemId,
                    scope.municipalityId,
                  ),
                ),
                child: const Text('Leggi la ricevuta salvata'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
