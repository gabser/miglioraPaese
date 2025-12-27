import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/logic/play_state.dart';

/// Gestisce il flusso di gioco "Gioca": carica turno, problemi e previsioni.
class PlayCubit extends Cubit<PlayState> {
  /// Crea il cubit con le dipendenze necessarie.
  PlayCubit({
    required this.repository,
    required this.prefs,
  }) : super(const PlayState(isLoading: true));

  final GameRepository repository;
  final AppPrefs prefs;

  /// Carica turno, problemi e previsioni utente riusando il repository mock.
  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final municipalityId = prefs.municipalityId ?? 'demo';
      final turn = await repository.getCurrentTurn(municipalityId);
      final problems = await repository.listProblems(municipalityId);
      final predictions = await repository.getMyPredictions(turn.id);
      final results = await repository.getPredictionResults(turn.id);
      final reputation = await repository.getReputationScore(turn.id);

      emit(
        state.copyWith(
          isLoading: false,
          currentTurn: turn,
          problems: problems,
          myPredictions: predictions.map(
            (key, value) => MapEntry(key, value.choice),
          ),
          results: results,
          reputation: reputation,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Aggiorna in modo ottimistico la previsione per il problema indicato.
  Future<void> selectPrediction({
    required String problemId,
    required PredictionChoice choice,
  }) async {
    final turnId = state.currentTurn?.id;
    if (turnId == null) return;

    final updatedPredictions = Map<String, PredictionChoice>.from(state.myPredictions)
      ..[problemId] = choice;
    final updatedResults = Map<String, PredictionResult>.from(state.results)
      ..remove(problemId);
    emit(state.copyWith(myPredictions: updatedPredictions, error: null, results: updatedResults));

    try {
      await repository.upsertPrediction(
        turnId: turnId,
        problemId: problemId,
        choice: choice,
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Ricarica un singolo problema per aggiornare stato e trend in UI.
  Future<void> refreshProblem(String problemId) async {
    try {
      final problem = await repository.getProblemById(problemId);
      final updatedProblems = state.problems
          .map((p) => p.id == problemId ? problem : p)
          .toList(growable: false);
      emit(state.copyWith(problems: updatedProblems, error: null));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Risolve tutte le previsioni correnti, aggiornando esiti e reputazione mock.
  Future<void> resolveTurn() async {
    final turnId = state.currentTurn?.id;
    if (turnId == null || state.myPredictions.isEmpty) return;

    emit(state.copyWith(isLoading: true, error: null));
    try {
      for (final entry in state.myPredictions.entries) {
        await repository.resolvePrediction(
          problemId: entry.key,
          choice: entry.value,
        );
      }

      final resolved = await repository.getPredictionResults(turnId);
      final reputation = await repository.getReputationScore(turnId);

      emit(
        state.copyWith(
          isLoading: false,
          results: resolved,
          reputation: reputation,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
