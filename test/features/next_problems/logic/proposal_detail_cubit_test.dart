import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_detail_cubit.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';
import '../../../helpers/memory_local_backend.dart';
import 'proposal_similarity_controller_test.dart' as fixture;

class Delayed extends MockNextProblemsRepository {
  Delayed(this.results) : super(currentUserId: 'test');
  final List<Future<SuggestedProblem>> results;
  int calls = 0;
  @override
  Future<SuggestedProblem> getSuggestedProblem({
    required String municipalityId,
    required String problemId,
  }) => results[calls++];
}

class StateHost {
  final data = LocalDataStore(backend: MemoryLocalBackend());
  late final scope = ProposalScope(
    municipalityId: 'bologna',
    environment: 'mock:test',
    namespace: data.namespace,
  );
  late final loop = CivicLoopStore(currentUserId: 'test', localData: data);
  late final repo = MockNextProblemsRepository(
    currentUserId: 'test',
    store: loop,
  );
  late final receipts = ProposalSubmissionCoordinator(
    store: ProposalSubmissionStore(data),
    drafts: ProposalDraftStore(data),
    gateway: repo,
    isMock: true,
  );
  ProposalDetailCubit reader(
    MockNextProblemsRepository source, {
    String id = 'read-id',
  }) => ProposalDetailCubit(
    repository: source,
    scope: scope,
    problemId: id,
    data: data,
    receipts: receipts,
  );
  void dispose() {
    receipts.dispose();
    loop.dispose();
    data.dispose();
  }
}

void main() {
  test(
    'real mock detail rereads promoted state, keeps snapshot, reconstructs ledger and proves original scope',
    () async {
      final h = StateHost();
      final view = await h.receipts.start(
        scope: h.scope,
        draftRevision: 0,
        title: 'Alberi',
        description: 'Serve ombra.',
        category: ProblemKey.green,
        location: const ProposalLocation.municipality(),
      );
      final intent = view.intent!;
      await h.repo.voteSuggestedProblem(
        municipalityId: 'bologna',
        problemId: intent.receipt!.id,
        vote: VoteChoice.up,
      );
      final live = await h.repo.getOwnSuggestedProblem(
        municipalityId: 'bologna',
        problemId: intent.receipt!.id,
        submissionScope: intent.submissionScope,
      );
      expect(live.status, SuggestedProblemStatus.approved);
      expect(
        h.receipts.savedReceipt(h.scope).intent!.receipt!.status,
        SuggestedProblemStatus.pending,
      );
      final freshLoop = CivicLoopStore(
        currentUserId: 'test',
        localData: h.data,
      );
      final fresh = MockNextProblemsRepository(
        currentUserId: 'test',
        store: freshLoop,
      );
      expect(
        (await fresh.getOwnSuggestedProblem(
          municipalityId: 'bologna',
          problemId: live.id,
          submissionScope: intent.submissionScope,
        )).id,
        live.id,
      );
      await expectLater(
        fresh.getOwnSuggestedProblem(
          municipalityId: 'castel-bolognese',
          problemId: live.id,
          submissionScope: intent.submissionScope,
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      await expectLater(
        fresh.getOwnSuggestedProblem(
          municipalityId: 'bologna',
          problemId: live.id,
          submissionScope: 'mock:another-user',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'proposal_scope_changed',
          ),
        ),
      );
      freshLoop.dispose();
      h.dispose();
    },
  );
  test(
    'newest detail read wins and late previous response cannot undo status',
    () async {
      final h = StateHost();
      final a = Completer<SuggestedProblem>();
      final b = Completer<SuggestedProblem>();
      final cubit = h.reader(Delayed([a.future, b.future]));
      final first = cubit.load();
      final second = cubit.load();
      b.complete(fixture.item('read-id', status: 'approved'));
      await second;
      a.complete(fixture.item('read-id'));
      await first;
      expect(cubit.state.problem!.status, SuggestedProblemStatus.approved);
      await cubit.close();
      h.dispose();
    },
  );
  test(
    'public rejected or mismatched detail fails closed instead of rendering private data',
    () async {
      for (final item in [
        fixture.item('read-id', status: 'rejected'),
        fixture.item('another-id'),
      ]) {
        final h = StateHost();
        final cubit = h.reader(Delayed([Future.value(item)]));
        await cubit.load();
        expect(cubit.state.status, ProposalDetailStatus.unavailable);
        expect(cubit.state.problem, isNull);
        await cubit.close();
        h.dispose();
      }
    },
  );
  test(
    'reset invalidates pending detail and dispose does not publish or throw',
    () async {
      final h = StateHost();
      final pending = Completer<SuggestedProblem>();
      final cubit = h.reader(Delayed([pending.future]));
      final work = cubit.load();
      await h.data.reset();
      expect(cubit.state.status, ProposalDetailStatus.reset);
      await cubit.close();
      pending.complete(fixture.item('read-id'));
      await work;
      expect(cubit.state.problem, isNull);
      h.dispose();
    },
  );
}
