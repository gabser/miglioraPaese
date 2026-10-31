import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';

class ProposalDocumentScaffold extends StatelessWidget {
  const ProposalDocumentScaffold({
    required this.title,
    required this.municipalityId,
    required this.child,
    super.key,
  });
  final String title;
  final String municipalityId;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: IconButton(
        tooltip: context.canPop() ? 'Torna indietro' : 'Torna alle proposte',
        icon: const Icon(AppIcons.back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(
              ProposalRouteContext.location('/next-problems', municipalityId),
            );
          }
        },
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        child: FcPageShell(
          maxWidth: AppTokens.narrowContentWidth,
          child: child,
        ),
      ),
    ),
  );
}

String proposalStatusLabel(SuggestedProblemStatus status) => switch (status) {
  SuggestedProblemStatus.pending => 'In valutazione',
  SuggestedProblemStatus.approved => 'Entrata in gioco',
  SuggestedProblemStatus.rejected => 'Non accolta',
};

String proposalDateLabel(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} alle ${two(local.hour)}:${two(local.minute)}';
}

/// Snapshot and live detail share content, but their provenance labels differ.
class ProposalDocument extends StatelessWidget {
  const ProposalDocument({
    required this.problem,
    required this.municipalityId,
    required this.snapshot,
    this.acceptedAt,
    super.key,
  });
  final SuggestedProblem problem;
  final String municipalityId;
  final bool snapshot;
  final DateTime? acceptedAt;

  @override
  Widget build(BuildContext context) => FcPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            problem.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: AppTokens.s12),
        SelectableText('ID: ${problem.id}'),
        Text(
          'Comune: ${MunicipalityCatalog.displayNameFromId(municipalityId)}',
        ),
        Text('Categoria: ${AppIcons.labelForProblemKey(problem.category)}'),
        Text(
          'Luogo: ${problem.location?.displayLabel ?? 'Luogo non specificato'}',
        ),
        if (problem.location?.reference != null)
          Text('Riferimento: ${problem.location!.reference}'),
        const SizedBox(height: AppTokens.s12),
        Text(problem.shortDescription),
        const SizedBox(height: AppTokens.s12),
        Text('Creata il ${proposalDateLabel(problem.createdAt)} (ora locale)'),
        if (acceptedAt != null)
          Text(
            'Ricevuta salvata il ${proposalDateLabel(acceptedAt!)} (ora locale)',
          ),
        Text(
          '${snapshot ? 'Stato all’invio' : 'Stato aggiornato'}: ${proposalStatusLabel(problem.status)}',
        ),
        if (!snapshot)
          Text('Consensi: ${problem.votesUp} · Contrari: ${problem.votesDown}'),
        const SizedBox(height: AppTokens.s12),
        Text(
          snapshot
              ? 'Questa ricevuta è salvata su questo dispositivo e si può leggere anche offline. È lo snapshot dell’invio, non lo stato aggiornato della proposta.'
              : 'Questi dati sono stati riletti dalla fonte delle proposte. Per verificare cambiamenti successivi, aggiorna il dettaglio.',
        ),
        const SizedBox(height: AppTokens.s8),
        const Text(
          'L’invio ricevuto non è un’approvazione né una segnalazione ufficiale.',
        ),
      ],
    ),
  );
}
