import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_gateway.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

class MockNextProblemsRepository
    implements
        NextProblemsRepository,
        ProposalSubmissionGateway,
        OwnProposalDetails {
  MockNextProblemsRepository({
    required String currentUserId,
    CivicLoopStore? store,
  }) : _store = store ?? CivicLoopStore(currentUserId: currentUserId);

  final CivicLoopStore _store;

  @override
  Future<SuggestedProblem> getOwnSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required String submissionScope,
  }) async {
    final epoch = _store.epoch;
    await prepareSubmissionScope(expectedScope: submissionScope);
    if (_store.epoch != epoch || _store.resetting) {
      throw const LocalDataResetException();
    }
    return _store.getOwnSuggestedProblem(
      municipalityId: municipalityId,
      problemId: problemId,
      submissionScope: submissionScope,
    );
  }

  @override
  Future<String> prepareSubmissionScope({
    String? expectedScope,
    String? municipalityId,
  }) async {
    final scope = 'mock:${_store.currentUserId}';
    if (expectedScope != null && expectedScope != scope) {
      throw ApiException.configuration(
        code: 'proposal_scope_changed',
        message: 'Sessione locale cambiata.',
      );
    }
    return scope;
  }

  @override
  Future<SuggestedProblem> submitIntent(ProposalSubmissionIntent intent) async {
    final epoch = _store.epoch;
    await prepareSubmissionScope(expectedScope: intent.submissionScope);
    if (_store.epoch != epoch || _store.resetting)
      throw const LocalDataResetException();
    return _store.submitIntent(intent);
  }

  @override
  Future<SuggestedProblem> lookupIntent(ProposalSubmissionIntent intent) async {
    final epoch = _store.epoch;
    await prepareSubmissionScope(expectedScope: intent.submissionScope);
    if (_store.epoch != epoch || _store.resetting)
      throw const LocalDataResetException();
    return _store.lookupIntent(intent);
  }

  @override
  Future<SuggestedProblem> getSuggestedProblem({
    required String municipalityId,
    required String problemId,
  }) async {
    final items = await listNextProblems(municipalityId: municipalityId);
    for (final item in items) {
      if (item.id == problemId) return item;
    }
    throw const ApiException(
      kind: ApiExceptionKind.response,
      statusCode: 404,
      code: 'suggested_problem_not_found',
      message: 'Proposta non trovata.',
    );
  }

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) async {
    return _store
        .listNextProblems(
          municipalityId: municipalityId,
          query: query,
          status: status,
        )
        .where((item) => item.status != SuggestedProblemStatus.rejected)
        .toList(growable: false);
  }

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
  }) async {
    return _store.submitSuggestedProblem(
      municipalityId: municipalityId,
      title: title,
      description: description,
      category: category,
      location: location,
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
