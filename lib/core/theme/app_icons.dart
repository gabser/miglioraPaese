import 'package:flutter/material.dart';
import 'package:goodtime/features/game/domain/problem_type.dart';

/// Raccolta centralizzata delle icone usate nell'app.
class AppIcons {
  const AppIcons._();

  /// Icona per la tab Home.
  static const IconData home = Icons.home_outlined;

  /// Icona per la tab di gioco/avvio partita.
  static const IconData play = Icons.play_circle_outline;

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

  /// Icona per tornare indietro.
  static const IconData back = Icons.arrow_back;

  /// Restituisce l'icona associata al [ProblemType].
  static IconData forProblemType(ProblemType type) {
    switch (type) {
      case ProblemType.lighting:
        return Icons.lightbulb_outline;
      case ProblemType.potholes:
        return Icons.car_repair;
      case ProblemType.waste:
        return Icons.delete_outline;
      case ProblemType.cleanliness:
        return Icons.cleaning_services_outlined;
      case ProblemType.green:
        return Icons.park_outlined;
      case ProblemType.signage:
        return Icons.signpost_outlined;
    }
  }

  /// Restituisce la label in italiano associata al [ProblemType].
  static String labelForProblemType(ProblemType type) {
    switch (type) {
      case ProblemType.lighting:
        return 'Illuminazione';
      case ProblemType.potholes:
        return 'Buche';
      case ProblemType.waste:
        return 'Rifiuti';
      case ProblemType.cleanliness:
        return 'Pulizia';
      case ProblemType.green:
        return 'Verde pubblico';
      case ProblemType.signage:
        return 'Segnaletica';
    }
  }
}
