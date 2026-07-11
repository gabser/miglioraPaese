import 'package:fanta_comune/core/models/problem_key.dart';

/// Tipologie di problema civico gestite dal dominio di gioco.
enum ProblemType { lighting, potholes, waste, cleanliness, green, signage }

/// Estensioni di utilità per convertire il dominio verso il modello condiviso.
extension ProblemTypeX on ProblemType {
  /// Converte il tipo dominio nella chiave condivisa [ProblemKey] per icone e label.
  ProblemKey toKey() {
    switch (this) {
      case ProblemType.lighting:
        return ProblemKey.lighting;
      case ProblemType.potholes:
        return ProblemKey.potholes;
      case ProblemType.waste:
        return ProblemKey.waste;
      case ProblemType.cleanliness:
        return ProblemKey.cleanliness;
      case ProblemType.green:
        return ProblemKey.green;
      case ProblemType.signage:
        return ProblemKey.signage;
    }
  }
}
