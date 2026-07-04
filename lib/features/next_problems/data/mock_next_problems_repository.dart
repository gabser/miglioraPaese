import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

class MockNextProblemsRepository implements NextProblemsRepository {
  MockNextProblemsRepository({
    required String currentUserId,
    CivicLoopStore? store,
  }) : _store = store ?? CivicLoopStore(currentUserId: currentUserId);

  final CivicLoopStore _store;

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) async {
    return _store.listNextProblems(
      municipalityId: municipalityId,
      query: query,
      status: status,
    );
  }

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
  }) async {
    return _store.submitSuggestedProblem(
      municipalityId: municipalityId,
      title: title,
      description: description,
      category: category,
    );
  }

  @override
  Future<SuggestedProblem> voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) async {
    return _store.voteSuggestedProblem(
      municipalityId: municipalityId,
      problemId: problemId,
      vote: vote,
    );
  }
}
