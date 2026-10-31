import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';

/// Recovery always proves the original scope; it cannot bootstrap a new one.
abstract interface class ProposalSubmissionGateway {
  Future<String> prepareSubmissionScope({String? expectedScope});
  Future<SuggestedProblem> submitIntent(ProposalSubmissionIntent intent);
  Future<SuggestedProblem> lookupIntent(ProposalSubmissionIntent intent);
}

abstract interface class LostProposalScopeRecovery {
  /// Explicit abandonment may forget an unusable local token, never an active one.
  Future<void> abandonLostScope(String expectedScope);
}
