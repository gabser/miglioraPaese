import 'package:equatable/equatable.dart';

/// Insight critico e leggero per confrontare prospettive aggregate.
class CriticalInsight extends Equatable {
  const CriticalInsight({
    required this.headline,
    required this.supporting,
    this.note,
  });

  /// Headline sintetica.
  final String headline;

  /// Supporto a una riga.
  final String supporting;

  /// Nota opzionale (es. "opinioni divise").
  final String? note;

  @override
  List<Object?> get props => [headline, supporting, note];
}
