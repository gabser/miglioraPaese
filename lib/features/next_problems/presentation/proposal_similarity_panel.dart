import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_document_widgets.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_similarity_controller.dart';

class ProposalSimilarityPanel extends StatelessWidget {
  const ProposalSimilarityPanel({required this.controller, super.key});
  final ProposalSimilarityController controller;
  @override
  Widget build(BuildContext context) => FcPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Proposte simili',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        Semantics(
          liveRegion: true,
          child: Text(switch (controller.status) {
            SimilarityStatus.checking =>
              'Sto confrontando le proposte leggibili di questo Comune.',
            SimilarityStatus.unavailable =>
              'Il confronto non è disponibile. Puoi continuare senza perdere la bozza.',
            _ =>
              controller.candidates.isEmpty
                  ? 'Non ho trovato un confronto tra le proposte leggibili. Potrebbero esserci altri problemi simili.'
                  : 'Controlla queste proposte. Stesso titolo o luogo non significano necessariamente lo stesso problema.',
          }),
        ),
        for (final candidate in controller.candidates) ...[
          const SizedBox(height: AppTokens.s12),
          Text(candidate.title, style: Theme.of(context).textTheme.titleSmall),
          Text(candidate.location?.displayLabel ?? 'Luogo non specificato'),
          Text(
            'Comune: ${MunicipalityCatalog.displayNameFromId(controller.scope.municipalityId)}',
          ),
          Text('Stato: ${proposalStatusLabel(candidate.status)}'),
          if (candidate.location?.reference != null)
            Text('Riferimento: ${candidate.location!.reference}'),
          TextButton(
            key: ValueKey('similar-proposal-${candidate.id}'),
            onPressed: () => context.push(
              ProposalRouteContext.detailLocation(
                candidate.id,
                controller.scope.municipalityId,
              ),
            ),
            child: Text('Apri “${candidate.title}”'),
          ),
        ],
        if (!controller.canProceed)
          OutlinedButton(
            key: const ValueKey('proposal-similarity-continue'),
            onPressed: controller.acknowledge,
            child: Text(
              controller.candidates.isNotEmpty
                  ? 'È un problema diverso, continua'
                  : 'Continua senza confronto',
            ),
          ),
        if (controller.acknowledged)
          const Text(
            'Puoi inviare la tua proposta. Nessuna proposta esistente verrà modificata.',
          ),
      ],
    ),
  );
}
