import 'package:equatable/equatable.dart';
import 'package:fanta_comune/features/game/domain/insight_snapshot.dart';

/// Contenitore ordinato degli snapshot di percezione per un problema.
class InsightHistory extends Equatable {
  /// Crea una storia mock per il [problemId] con snapshot in ordine cronologico.
  const InsightHistory({required this.problemId, required this.snapshots});

  /// Identificativo del problema a cui si riferisce lo storico.
  final String problemId;

  /// Lista di snapshot ordinati dal più vecchio al più recente.
  final List<InsightSnapshot> snapshots;

  @override
  List<Object?> get props => [problemId, snapshots];
}
