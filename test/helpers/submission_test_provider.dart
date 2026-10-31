import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_receipt_page.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_gateway.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';

/// Adapter for older recording fixtures. Production mock/API gateways and actual
/// provider tests remain independent and exercise the real recovery protocol.
class RecordingSubmissionGateway implements ProposalSubmissionGateway {
  RecordingSubmissionGateway(this.repository);
  final NextProblemsRepository repository;
  final receipts = <String, SuggestedProblem>{};
  @override
  Future<String> prepareSubmissionScope({String? expectedScope}) async {
    if (repository is ProposalFormCapabilities) {
      await (repository as ProposalFormCapabilities).prepareProposalForm();
    }
    if (expectedScope != null && expectedScope != 'fixture-scope') {
      throw StateError('Unexpected fixture scope.');
    }
    return 'fixture-scope';
  }

  @override
  Future<SuggestedProblem> submitIntent(ProposalSubmissionIntent intent) async {
    final prior = receipts[intent.idempotencyKey];
    if (prior != null) return prior;
    final result = await repository.submitSuggestedProblem(
      municipalityId: intent.scope.municipalityId,
      title: intent.title,
      description: intent.description,
      category: intent.category,
      location: intent.location,
    );
    receipts[intent.idempotencyKey] = result;
    return result;
  }

  @override
  Future<SuggestedProblem> lookupIntent(
    ProposalSubmissionIntent intent,
  ) async =>
      receipts[intent.idempotencyKey] ??
      (throw const ApiException(
        kind: ApiExceptionKind.response,
        statusCode: 404,
        code: 'submission_not_found',
        message: 'Not found',
      ));
}

Widget recordingSubmissionHost({
  required AppPrefs prefs,
  required NextProblemsRepository repository,
  required Widget child,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<LocalDataStore>.value(value: prefs.localData),
    ChangeNotifierProvider<ProposalSubmissionCoordinator>(
      create: (_) => ProposalSubmissionCoordinator(
        store: ProposalSubmissionStore(prefs.localData),
        drafts: ProposalDraftStore(prefs.localData),
        gateway: RecordingSubmissionGateway(repository),
        isMock: true,
      ),
    ),
  ],
  child: child,
);

GoRoute receiptTestRoute(AppPrefs prefs) => GoRoute(
  path: '/proposal-receipt/:problemId',
  builder: (_, state) => ProposalReceiptPage(
    problemId: state.pathParameters['problemId'],
    routeContext: ProposalRouteContext.resolve(
      state.uri,
      preference: prefs.municipalityId,
    ),
  ),
);
