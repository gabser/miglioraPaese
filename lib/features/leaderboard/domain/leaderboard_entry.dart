import 'package:equatable/equatable.dart';

/// Elemento di classifica per un partecipante.
class LeaderboardEntry extends Equatable {
  /// Crea un record di classifica con [userId], nome e punti.
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.points,
    required this.rank,
  });

  /// Identificativo univoco dell'utente.
  final String userId;

  /// Nome visualizzato nella classifica.
  final String displayName;

  /// Punteggio totale accumulato.
  final int points;

  /// Posizione in classifica (1 = primo).
  final int rank;

  /// Restituisce una copia immutabile con eventuali modifiche.
  LeaderboardEntry copyWith({
    String? userId,
    String? displayName,
    int? points,
    int? rank,
  }) {
    return LeaderboardEntry(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      points: points ?? this.points,
      rank: rank ?? this.rank,
    );
  }

  @override
  List<Object?> get props => [userId, displayName, points, rank];
}
