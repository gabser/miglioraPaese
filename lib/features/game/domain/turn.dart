import 'package:equatable/equatable.dart';
import 'package:fanta_comune/features/game/domain/turn_state.dart';

/// Rappresenta una finestra temporale di gioco con le sue date e lo stato.
class Turn extends Equatable {
  /// Crea un turno identificato da [id] con data di inizio/fine e [state].
  const Turn({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.state,
  });

  /// Identificativo del turno.
  final String id;

  /// Momento di apertura del turno.
  final DateTime startAt;

  /// Momento di chiusura del turno.
  final DateTime endAt;

  /// Stato corrente del turno.
  final TurnState state;

  /// Restituisce una copia del turno con eventuali campi aggiornati.
  Turn copyWith({
    String? id,
    DateTime? startAt,
    DateTime? endAt,
    TurnState? state,
  }) {
    return Turn(
      id: id ?? this.id,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      state: state ?? this.state,
    );
  }

  @override
  List<Object?> get props => [id, startAt, endAt, state];
}
