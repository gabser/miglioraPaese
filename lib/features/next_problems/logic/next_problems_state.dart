import 'package:equatable/equatable.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';

enum NextProblemsSortMode { hot, newest, controversial }

const _filterStatusNotProvided = Object();

class NextProblemsState extends Equatable {
  const NextProblemsState({
    this.municipalityId,
    this.isLoading = false,
    this.error,
    this.voteError,
    this.items = const <SuggestedProblem>[],
    this.query = '',
    this.filterStatus,
    this.sortMode = NextProblemsSortMode.hot,
    this.submitting = false,
    this.votingProblemIds = const <String>{},
  });

  final String? municipalityId;
  final bool isLoading;
  final String? error;
  final String? voteError;
  final List<SuggestedProblem> items;
  final String query;
  final SuggestedProblemStatus? filterStatus;
  final NextProblemsSortMode sortMode;
  final bool submitting;
  final Set<String> votingProblemIds;

  NextProblemsState copyWith({
    bool? isLoading,
    String? error,
    String? voteError,
    List<SuggestedProblem>? items,
    String? query,
    Object? filterStatus = _filterStatusNotProvided,
    NextProblemsSortMode? sortMode,
    bool? submitting,
    Set<String>? votingProblemIds,
  }) {
    return NextProblemsState(
      municipalityId: municipalityId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      voteError: voteError,
      items: items ?? this.items,
      query: query ?? this.query,
      filterStatus: identical(filterStatus, _filterStatusNotProvided)
          ? this.filterStatus
          : filterStatus as SuggestedProblemStatus?,
      sortMode: sortMode ?? this.sortMode,
      submitting: submitting ?? this.submitting,
      votingProblemIds: votingProblemIds ?? this.votingProblemIds,
    );
  }

  @override
  List<Object?> get props => [
    municipalityId,
    isLoading,
    error,
    voteError,
    items,
    query,
    filterStatus,
    sortMode,
    submitting,
    votingProblemIds,
  ];
}
