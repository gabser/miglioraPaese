import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import 'package:fanta_comune/features/next_problems/logic/next_problems_state.dart';

class NextProblemsCubit extends Cubit<NextProblemsState> {
  NextProblemsCubit({
    required this.repository,
    required this.prefs,
    this.searchDebounce = const Duration(milliseconds: 300),
  }) : super(const NextProblemsState());

  final NextProblemsRepository repository;
  final AppPrefs prefs;
  final Duration searchDebounce;
  Timer? _searchTimer;
  int _loadVersion = 0;

  Future<void> load() async {
    final requestVersion = ++_loadVersion;
    final query = state.query.trim();
    final filterStatus = state.filterStatus;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final items = await repository.listNextProblems(
        municipalityId: prefs.municipalityId ?? 'demo',
        query: query.isEmpty ? null : query,
        status: filterStatus,
      );
      if (isClosed || requestVersion != _loadVersion) return;
      emit(
        state.copyWith(
          isLoading: false,
          items: _sorted(items, state.sortMode),
          error: null,
        ),
      );
    } catch (error) {
      if (isClosed || requestVersion != _loadVersion) return;
      emit(state.copyWith(isLoading: false, error: _userMessageFor(error)));
    }
  }

  Future<void> refresh() async {
    _searchTimer?.cancel();
    await load();
  }

  void setQuery(String value) {
    _searchTimer?.cancel();
    _loadVersion++;
    emit(state.copyWith(query: value, error: null));
    _searchTimer = Timer(searchDebounce, () {
      if (!isClosed) unawaited(load());
    });
  }

  void setFilterStatus(SuggestedProblemStatus? status) {
    _searchTimer?.cancel();
    _loadVersion++;
    emit(state.copyWith(filterStatus: status, error: null));
    unawaited(load());
  }

  void setSortMode(NextProblemsSortMode mode) {
    emit(state.copyWith(sortMode: mode, items: _sorted(state.items, mode)));
  }

  Future<void> vote(String problemId, VoteChoice vote) async {
    if (state.votingProblemIds.contains(problemId)) return;
    final updatedVoting = {...state.votingProblemIds, problemId};
    emit(state.copyWith(votingProblemIds: updatedVoting, error: null));
    try {
      final updated = await repository.voteSuggestedProblem(
        municipalityId: prefs.municipalityId ?? 'demo',
        problemId: problemId,
        vote: vote,
      );
      if (isClosed) return;
      final nextItems = state.items
          .map((item) => item.id == updated.id ? updated : item)
          .toList(growable: false);
      emit(
        state.copyWith(
          items: _sorted(nextItems, state.sortMode),
          votingProblemIds: _withoutProblemId(problemId),
          error: null,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          error: _userMessageFor(error),
          votingProblemIds: _withoutProblemId(problemId),
        ),
      );
    }
  }

  Future<String?> submit({
    required String title,
    required String description,
    required ProblemKey category,
  }) async {
    emit(state.copyWith(submitting: true, error: null));
    try {
      await repository.submitSuggestedProblem(
        municipalityId: prefs.municipalityId ?? 'demo',
        title: title,
        description: description,
        category: category,
      );
      if (isClosed) return 'generic';
      emit(state.copyWith(submitting: false));
      return null;
    } catch (error) {
      if (isClosed) return 'generic';
      emit(state.copyWith(submitting: false, error: _userMessageFor(error)));
      if (_isDuplicateTitle(error)) {
        return 'duplicate_title';
      }
      return 'generic';
    }
  }

  Set<String> _withoutProblemId(String problemId) {
    return Set<String>.from(state.votingProblemIds)..remove(problemId);
  }

  bool _isDuplicateTitle(Object error) {
    return (error is ApiException && error.code == 'duplicate_title') ||
        error.toString().contains('duplicate_title');
  }

  String _userMessageFor(Object error) {
    if (error is ApiException) {
      if (error.code == 'unsupported_municipality' ||
          error.code == 'municipality_not_found') {
        return 'Questo Comune non e\' ancora disponibile online. '
            'Puoi sceglierne un altro dal profilo.';
      }
      if (error.code == 'duplicate_title') {
        return 'Esiste gia\' una proposta con questo titolo.';
      }
      if (error.kind == ApiExceptionKind.timeout) {
        return 'Il servizio sta impiegando troppo tempo. Riprova tra poco.';
      }
      if (error.kind == ApiExceptionKind.network) {
        return 'Non riusciamo a raggiungere il servizio. '
            'Controlla la connessione e riprova.';
      }
    }
    return 'Non siamo riusciti a caricare i temi. Riprova tra poco.';
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    _loadVersion++;
    return super.close();
  }

  List<SuggestedProblem> _sorted(
    List<SuggestedProblem> items,
    NextProblemsSortMode mode,
  ) {
    final sorted = List<SuggestedProblem>.from(items);
    switch (mode) {
      case NextProblemsSortMode.hot:
        sorted.sort((a, b) => b.score.compareTo(a.score));
      case NextProblemsSortMode.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case NextProblemsSortMode.controversial:
        sorted.sort((a, b) {
          final aTotal = a.votesUp + a.votesDown;
          final bTotal = b.votesUp + b.votesDown;
          final aDiff = (a.votesUp - a.votesDown).abs();
          final bDiff = (b.votesUp - b.votesDown).abs();
          final aScore = aTotal - aDiff;
          final bScore = bTotal - bDiff;
          return bScore.compareTo(aScore);
        });
    }
    return sorted;
  }
}
