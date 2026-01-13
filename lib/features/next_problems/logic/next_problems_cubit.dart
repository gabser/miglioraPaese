import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import 'package:fanta_comune/features/next_problems/logic/next_problems_state.dart';
import 'package:fanta_comune/core/models/problem_key.dart';

class NextProblemsCubit extends Cubit<NextProblemsState> {
  NextProblemsCubit({
    required this.repository,
    required this.prefs,
  }) : super(const NextProblemsState());

  final NextProblemsRepository repository;
  final AppPrefs prefs;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final items = await repository.listNextProblems(
        municipalityId: prefs.municipalityId ?? 'demo',
        query: state.query.isEmpty ? null : state.query,
        status: state.filterStatus,
      );
      emit(
        state.copyWith(
          isLoading: false,
          items: _sorted(items, state.sortMode),
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> refresh() async {
    await load();
  }

  void setQuery(String value) {
    emit(state.copyWith(query: value));
    load();
  }

  void setFilterStatus(SuggestedProblemStatus? status) {
    emit(state.copyWith(filterStatus: status));
    load();
  }

  void setSortMode(NextProblemsSortMode mode) {
    emit(state.copyWith(sortMode: mode, items: _sorted(state.items, mode)));
  }

  Future<void> vote(String problemId, VoteChoice vote) async {
    final updatedVoting = {...state.votingProblemIds, problemId};
    emit(state.copyWith(votingProblemIds: updatedVoting, error: null));
    try {
      final updated = await repository.voteSuggestedProblem(
        municipalityId: prefs.municipalityId ?? 'demo',
        problemId: problemId,
        vote: vote,
      );
      final nextItems = state.items
          .map((item) => item.id == updated.id ? updated : item)
          .toList(growable: false);
      emit(
        state.copyWith(
          items: _sorted(nextItems, state.sortMode),
          votingProblemIds: updatedVoting..remove(problemId),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: e.toString(),
          votingProblemIds: updatedVoting..remove(problemId),
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
      emit(state.copyWith(submitting: false));
      return null;
    } catch (e) {
      emit(state.copyWith(submitting: false, error: e.toString()));
      if (e.toString().contains('duplicate_title')) {
        return 'duplicate_title';
      }
      return 'generic';
    }
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
