import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

abstract class NextProblemsRepository {
  Future<SuggestedProblem> getSuggestedProblem({
    required String municipalityId,
    required String problemId,
  });

  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  });

  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
  });

  Future<SuggestedProblem> voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  });
}

/// Pilot UI must verify the server protocol before exposing new proposal fields.
abstract interface class ProposalFormCapabilities {
  Future<void> prepareProposalForm();
}

/// Private detail requires the original authoritative submission scope.
abstract interface class OwnProposalDetails {
  Future<SuggestedProblem> getOwnSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required String submissionScope,
  });
}
