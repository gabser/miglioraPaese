import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';

/// Possibili motivazioni predefinite associate a una previsione.
enum MotivationKey {
  /// L'utente ha notato interventi visibili sul territorio.
  visibleActions,

  /// La situazione è peggiorata di recente.
  recentDecline,

  /// La dinamica segue una ciclicità stagionale.
  seasonality,

  /// Sono state promesse azioni non ancora rispettate.
  unmetPromises,

  /// Osservazione diretta o vissuta in prima persona.
  personalExperience,
}

extension MotivationKeyX on MotivationKey {
  /// Etichetta in italiano mostrata sui chip di motivazione.
  String get label {
    switch (this) {
      case MotivationKey.visibleActions:
        return 'Interventi visibili';
      case MotivationKey.recentDecline:
        return 'Peggioramento recente';
      case MotivationKey.seasonality:
        return 'Stagionalità';
      case MotivationKey.unmetPromises:
        return 'Promesse non mantenute';
      case MotivationKey.personalExperience:
        return 'Esperienza personale';
    }
  }

  /// Icona coerente con il set attuale, riusando asset condivisi dove possibile.
  IconData get icon {
    switch (this) {
      case MotivationKey.visibleActions:
        return AppIcons.spark;
      case MotivationKey.recentDecline:
        return Icons.trending_down;
      case MotivationKey.seasonality:
        return Icons.calendar_month_outlined;
      case MotivationKey.unmetPromises:
        return Icons.pending_actions_outlined;
      case MotivationKey.personalExperience:
        return Icons.person_pin_circle_outlined;
    }
  }
}
