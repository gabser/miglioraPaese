import 'package:fanta_comune/features/next_problems/presentation/proposal_point_map.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
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
  SuggestedProblemStatus.pending => VenialCopy.nextProblemsStatusPending,
  SuggestedProblemStatus.approved => VenialCopy.nextProblemsStatusApproved,
  SuggestedProblemStatus.rejected => VenialCopy.nextProblemsStatusRejected,
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
        if (problem.location?.coordinates != null)
          ProposalPointMap(
            municipalityId: municipalityId,
            coordinates: problem.location!.coordinates,
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
              ? 'Puoi leggere questa ricevuta anche senza connessione, su questo dispositivo. Mostra la proposta al momento dell’invio. Apri il dettaglio per vedere lo stato aggiornato.'
              : 'Qui trovi i dati riletti dal servizio o dalla demo. Premi Aggiorna il dettaglio per controllare se sono cambiati.',
        ),
        const SizedBox(height: AppTokens.s8),
        const Text(
          'La proposta è stata ricevuta. Non è una segnalazione ufficiale al Comune e non entra automaticamente nel gioco. L’invio non assegna punti alla squadra né reputazione.',
        ),
      ],
    ),
  );
}
