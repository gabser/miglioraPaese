import 'package:flutter/material.dart';
import 'package:fanta_comune/core/models/problem_key.dart';

/// Raccolta centralizzata delle icone e delle label di navigazione e problemi.
class AppIcons {
  const AppIcons._();

  /// Icona per la tab Home.
  static const IconData home = Icons.home_outlined;

  /// Icona per la tab di gioco/avvio partita.
  static const IconData play = Icons.play_circle_outline;

  /// Icona per il tabellone di gioco.
  static const IconData board = Icons.grid_view_outlined;

  /// Icona per la tab Classifica.
  static const IconData leaderboard = Icons.leaderboard_outlined;

  /// Icona per la tab Profilo.
  static const IconData profile = Icons.person_outline;

  /// Icona per schermate informative.
  static const IconData info = Icons.info_outline;

  /// Icona per Privacy o gestione dati.
  static const IconData privacy = Icons.privacy_tip_outlined;

  /// Icona per la condivisione.
  static const IconData share = Icons.share_outlined;

  /// Icona per le impostazioni.
  static const IconData settings = Icons.settings_outlined;

  /// Icona per previsioni positive/miglioramenti.
  static const IconData spark = Icons.auto_fix_high;

  /// Icona per trend negativi.
  static const IconData trendingDown = Icons.trending_down;

  /// Icona per tornare indietro.
  static const IconData back = Icons.arrow_back;

  /// Restituisce l'icona associata al [ProblemKey].
  static IconData forProblemKey(ProblemKey key) {
    switch (key) {
      case ProblemKey.lighting:
        return Icons.lightbulb_outline;
      case ProblemKey.potholes:
        return Icons.car_repair;
      case ProblemKey.waste:
        return Icons.delete_outline;
      case ProblemKey.cleanliness:
        return Icons.cleaning_services_outlined;
      case ProblemKey.green:
        return Icons.park_outlined;
      case ProblemKey.signage:
        return Icons.signpost_outlined;
      case ProblemKey.transport:
        return Icons.directions_bus_outlined;
      case ProblemKey.parking:
        return Icons.local_parking_outlined;
      case ProblemKey.decor:
        return Icons.auto_awesome_outlined;
      case ProblemKey.noise:
        return Icons.volume_up_outlined;
      case ProblemKey.safety:
        return Icons.shield_outlined;
      case ProblemKey.construction:
        return Icons.construction_outlined;
      case ProblemKey.queues:
        return Icons.hourglass_bottom_outlined;
    }
  }

  /// Restituisce la label in italiano associata al [ProblemKey].
  static String labelForProblemKey(ProblemKey key) {
    switch (key) {
      case ProblemKey.lighting:
        return 'Illuminazione';
      case ProblemKey.potholes:
        return 'Buche';
      case ProblemKey.waste:
        return 'Rifiuti';
      case ProblemKey.cleanliness:
        return 'Pulizia';
      case ProblemKey.green:
        return 'Verde pubblico';
      case ProblemKey.signage:
        return 'Segnaletica';
      case ProblemKey.transport:
        return 'Trasporti';
      case ProblemKey.parking:
        return 'Parcheggi';
      case ProblemKey.decor:
        return 'Decoro';
      case ProblemKey.noise:
        return 'Rumore';
      case ProblemKey.safety:
        return 'Sicurezza stradale';
      case ProblemKey.construction:
        return 'Cantieri';
      case ProblemKey.queues:
        return 'Code uffici';
    }
  }
}
