import 'package:equatable/equatable.dart';

class CivicLoopSummary extends Equatable {
  const CivicLoopSummary({
    required this.municipalityName,
    required this.proposedThemes,
    required this.confirmedThemes,
    required this.cardsInTurn,
    required this.predictions,
    required this.outcomes,
    required this.reputationPoints,
    this.topThemeTitle,
  });

  final String municipalityName;
  final int proposedThemes;
  final int confirmedThemes;
  final int cardsInTurn;
  final int predictions;
  final int outcomes;
  final int reputationPoints;
  final String? topThemeTitle;

  bool get hasCompleteLoop =>
      proposedThemes > 0 &&
      confirmedThemes > 0 &&
      cardsInTurn > 0 &&
      predictions > 0 &&
      outcomes > 0;

  CivicLoopSummary copyWith({
    String? municipalityName,
    int? proposedThemes,
    int? confirmedThemes,
    int? cardsInTurn,
    int? predictions,
    int? outcomes,
    int? reputationPoints,
    String? topThemeTitle,
  }) {
    return CivicLoopSummary(
      municipalityName: municipalityName ?? this.municipalityName,
      proposedThemes: proposedThemes ?? this.proposedThemes,
      confirmedThemes: confirmedThemes ?? this.confirmedThemes,
      cardsInTurn: cardsInTurn ?? this.cardsInTurn,
      predictions: predictions ?? this.predictions,
      outcomes: outcomes ?? this.outcomes,
      reputationPoints: reputationPoints ?? this.reputationPoints,
      topThemeTitle: topThemeTitle ?? this.topThemeTitle,
    );
  }

  @override
  List<Object?> get props => [
    municipalityName,
    proposedThemes,
    confirmedThemes,
    cardsInTurn,
    predictions,
    outcomes,
    reputationPoints,
    topThemeTitle,
  ];
}
