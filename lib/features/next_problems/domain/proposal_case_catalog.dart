import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_draft.dart';

abstract final class ProposalCaseCatalog {
  static const cases = <ProblemKey, List<String>>{
    ProblemKey.lighting: [
      'Lampione spento',
      'Luce intermittente',
      'Zona poco illuminata',
    ],
    ProblemKey.potholes: [
      'Buca sulla strada',
      'Più buche',
      'Asfalto dissestato',
    ],
    ProblemKey.waste: [
      'Cassonetto pieno',
      'Rifiuti abbandonati',
      'Raccolta saltata',
    ],
    ProblemKey.cleanliness: [
      'Strada sporca',
      'Escrementi non raccolti',
      'Cestino da svuotare',
    ],
    ProblemKey.green: ['Erba alta', 'Ramo sul passaggio', 'Gioco danneggiato'],
    ProblemKey.signage: [
      'Cartello danneggiato',
      'Cartello poco visibile',
      'Strisce sbiadite',
    ],
    ProblemKey.transport: [
      'Corsa saltata',
      'Ritardi frequenti',
      'Fermata poco accessibile',
    ],
    ProblemKey.parking: [
      'Passaggio bloccato',
      'Sosta sul marciapiede',
      'Posto riservato occupato',
    ],
    ProblemKey.decor: [
      'Panchina danneggiata',
      'Arredo urbano danneggiato',
      'Scritte su muri',
    ],
    ProblemKey.noise: ['Musica alta', 'Rumori da lavori', 'Traffico rumoroso'],
    ProblemKey.safety: [
      'Velocità elevata',
      'Attraversamento difficile',
      'Visibilità ridotta',
    ],
    ProblemKey.construction: [
      'Passaggio interrotto',
      'Lavori fermi',
      'Segnalazione del cantiere poco chiara',
    ],
    ProblemKey.queues: [
      'Attesa allo sportello',
      'Coda all’ingresso',
      'Attesa per appuntamento',
    ],
  };
  static List<String> details(ProposalDraft draft) {
    if (draft.caseIndex == null || draft.caseIndex == -1) return const [];
    if (draft.category == ProblemKey.lighting && draft.caseIndex == 0) {
      return const ['1', '2', '3', '4', '5', 'Più di 5'];
    }
    if (draft.category == ProblemKey.potholes) {
      return const ['Carreggiata', 'Marciapiede', 'Pista ciclabile'];
    }
    if (draft.category == ProblemKey.noise) {
      return const ['Giorno', 'Sera', 'Notte'];
    }
    return const [];
  }

  static String detailLabel(ProposalDraft draft) => switch (draft.category) {
    ProblemKey.lighting => 'Numero di lampioni (facoltativo)',
    ProblemKey.potholes => 'Dove si trova (facoltativo)',
    _ => 'Quando si sente (facoltativo)',
  };
  static ({String title, String description}) generate(ProposalDraft draft) {
    final category = draft.category;
    if (category == null || draft.caseIndex == null) {
      return (title: '', description: '');
    }
    final custom = draft.caseIndex == -1;
    final title = custom
        ? AppIcons.labelForProblemKey(category)
        : cases[category]![draft.caseIndex!];
    final parts = <String>[custom ? draft.customDescription.trim() : '$title.'];
    if (details(draft).contains(draft.detail)) {
      parts.add(switch (category) {
        ProblemKey.lighting => 'Numero di lampioni: ${draft.detail}.',
        ProblemKey.potholes => 'Posizione: ${draft.detail!.toLowerCase()}.',
        _ => 'Momento: ${draft.detail!.toLowerCase()}.',
      });
    }
    if (draft.locationKind != null) {
      parts.add('Luogo: ${draft.location.displayLabel}.');
      if (draft.location.reference != null) {
        parts.add('Riferimento: ${draft.location.reference}.');
      }
    }
    return (
      title: title,
      description: parts.where((p) => p.isNotEmpty).join(' '),
    );
  }
}
