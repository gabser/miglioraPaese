import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';

/// Lente con cui leggere le situazioni civiche.
enum PerspectiveRole { observer, realist, caretaker, organizer, optimist }

extension PerspectiveRoleX on PerspectiveRole {
  /// Etichetta in italiano.
  String get label {
    switch (this) {
      case PerspectiveRole.observer:
        return 'Osservatore';
      case PerspectiveRole.realist:
        return 'Realista';
      case PerspectiveRole.caretaker:
        return 'Caregiver';
      case PerspectiveRole.organizer:
        return 'Organizzatore';
      case PerspectiveRole.optimist:
        return 'Ottimista';
    }
  }

  /// Descrizione breve e veniale della lente.
  String get shortDescription {
    switch (this) {
      case PerspectiveRole.observer:
        return 'Guardi i segnali con calma e senza fretta.';
      case PerspectiveRole.realist:
        return 'Tieni d\'occhio tempi, costi e fattibilita\'.';
      case PerspectiveRole.caretaker:
        return 'Ti interessa l\'impatto sulle persone.';
      case PerspectiveRole.organizer:
        return 'Segui il processo e la coordinazione.';
      case PerspectiveRole.optimist:
        return 'Cerchi il potenziale e le svolte positive.';
    }
  }

  /// Icona associata alla lente.
  IconData get icon {
    switch (this) {
      case PerspectiveRole.observer:
        return Icons.visibility_outlined;
      case PerspectiveRole.realist:
        return Icons.schedule_outlined;
      case PerspectiveRole.caretaker:
        return Icons.favorite_border;
      case PerspectiveRole.organizer:
        return Icons.account_tree_outlined;
      case PerspectiveRole.optimist:
        return AppIcons.spark;
    }
  }
}

PerspectiveRole suggestPerspectiveRole({
  required Map<String, HypothesisConfidence> confidences,
  required Map<String, List<MotivationKey>> motivations,
  required Map<String, int> reflectionAnswers,
}) {
  var gutFeeling = 0;
  var convinced = 0;
  var considered = 0;
  for (final confidence in confidences.values) {
    switch (confidence) {
      case HypothesisConfidence.gutFeeling:
        gutFeeling++;
      case HypothesisConfidence.considered:
        considered++;
      case HypothesisConfidence.convinced:
        convinced++;
    }
  }

  var structuralMotivations = 0;
  var processMotivations = 0;
  var peopleMotivations = 0;
  for (final list in motivations.values) {
    for (final motivation in list) {
      switch (motivation) {
        case MotivationKey.unmetPromises:
        case MotivationKey.seasonality:
          structuralMotivations++;
        case MotivationKey.visibleActions:
          processMotivations++;
        case MotivationKey.personalExperience:
          peopleMotivations++;
        case MotivationKey.recentDecline:
          structuralMotivations++;
      }
    }
  }

  var reflectionCaretaker = 0;
  var reflectionOptimist = 0;
  var reflectionOrganizer = 0;
  for (final value in reflectionAnswers.values) {
    if (value == 0) {
      reflectionCaretaker++;
    } else if (value == 1) {
      reflectionOptimist++;
    } else if (value == 2) {
      reflectionOrganizer++;
    }
  }

  if (peopleMotivations >= 2 || reflectionCaretaker >= 2) {
    return PerspectiveRole.caretaker;
  }

  if (convinced >= 2 && structuralMotivations >= 2) {
    return PerspectiveRole.realist;
  }

  if (convinced >= 2 && (processMotivations >= 2 || reflectionOrganizer >= 2)) {
    return PerspectiveRole.organizer;
  }

  if (gutFeeling >= 2 && reflectionOptimist >= 2) {
    return PerspectiveRole.optimist;
  }

  if (considered >= 2) {
    return PerspectiveRole.observer;
  }

  return PerspectiveRole.observer;
}
