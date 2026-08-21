import 'package:equatable/equatable.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';

/// Problema civico monitorato nel turno di gioco.
class Problem extends Equatable {
  /// Crea un problema identificato da [id] e collegato a [key].
  const Problem({
    required this.id,
    required this.key,
    required this.title,
    required this.zoneName,
    required this.status,
    required this.trendPercent,
    required this.updatedAt,
  });

  /// Identificativo del problema.
  final String id;

  /// Tipologia del problema, riusando le chiavi condivise.
  final ProblemKey key;

  /// Titolo sintetico (es. "Buche in strada").
  final String title;

  /// Nome della zona o quartiere, se disponibile.
  final String? zoneName;

  /// Stato attuale del problema.
  final ProblemStatus status;

  /// Andamento percentuale del problema (positivo o negativo).
  final int trendPercent;

  /// Ultimo aggiornamento disponibile.
  final DateTime updatedAt;

  /// Restituisce una copia immutabile con eventuali modifiche.
  Problem copyWith({
    String? id,
    ProblemKey? key,
    String? title,
    String? zoneName,
    ProblemStatus? status,
    int? trendPercent,
    DateTime? updatedAt,
  }) {
    return Problem(
      id: id ?? this.id,
      key: key ?? this.key,
      title: title ?? this.title,
      zoneName: zoneName ?? this.zoneName,
      status: status ?? this.status,
      trendPercent: trendPercent ?? this.trendPercent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    key,
    title,
    zoneName,
    status,
    trendPercent,
    updatedAt,
  ];
}
