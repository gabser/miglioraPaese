import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import '../../../helpers/memory_local_backend.dart';

void main() {
  test(
    'search matches place and reference within the chosen municipality',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      final store = CivicLoopStore(
        currentUserId: 'search-user',
        localData: data,
      );
      final repo = MockNextProblemsRepository(
        currentUserId: 'search-user',
        store: store,
      );
      addTearDown(store.dispose);
      addTearDown(data.dispose);
      final item = await repo.submitSuggestedProblem(
        municipalityId: 'bologna',
        title: 'Tema nuovo',
        description: 'Un ostacolo',
        category: ProblemKey.green,
        location: ProposalLocation.specific(
          label: 'Viale Zaffiro',
          civic: '12/A',
          reference: 'Ingresso speciale',
        ),
      );
      for (final term in ['zaffiro', '12/A', 'ingresso speciale']) {
        final items = await repo.listNextProblems(
          municipalityId: 'bologna',
          query: term,
        );
        expect(items.map((x) => x.id), contains(item.id));
        final others = await repo.listNextProblems(
          municipalityId: 'castel-bolognese',
          query: term,
        );
        expect(others.map((x) => x.id), isNot(contains(item.id)));
      }
    },
  );

  test(
    'detail reads current state/place by exact municipality and survives recreation',
    () async {
      final backend = MemoryLocalBackend();
      final data = LocalDataStore(backend: backend);
      final store = CivicLoopStore(currentUserId: 'user-a', localData: data);
      final repository = MockNextProblemsRepository(
        currentUserId: 'user-a',
        store: store,
      );
      final place = ProposalLocation.specific(
        label: 'Piazza delle Rose',
        reference: 'Ingresso nord',
      );
      final created = await repository.submitSuggestedProblem(
        municipalityId: 'comune:Bologna',
        title: 'Alberi',
        description: 'Potatura',
        category: ProblemKey.green,
        location: place,
      );
      _expectDetails(
        await repository.getSuggestedProblem(
          municipalityId: 'bologna',
          problemId: created.id,
        ),
        created,
      );
      final voted = await repository.voteSuggestedProblem(
        municipalityId: 'bologna',
        problemId: created.id,
        vote: VoteChoice.up,
      );
      expect(voted.status, SuggestedProblemStatus.approved);
      _expectDetails(
        await repository.getSuggestedProblem(
          municipalityId: 'comune:Bologna',
          problemId: created.id,
        ),
        voted,
      );
      store.dispose();
      data.dispose();
      final reloadedData = LocalDataStore(backend: backend);
      final reloadedStore = CivicLoopStore(
        currentUserId: 'user-a',
        localData: reloadedData,
      );
      final reloaded = MockNextProblemsRepository(
        currentUserId: 'user-a',
        store: reloadedStore,
      );
      final detail = await reloaded.getSuggestedProblem(
        municipalityId: 'bologna',
        problemId: created.id,
      );
      _expectDetails(detail, voted);
      expect(detail.location, place);
      expect(detail.createdAt.isAtSameMomentAs(created.createdAt), isTrue);
      await reloadedData.reset();
      await expectLater(
        reloaded.getSuggestedProblem(
          municipalityId: 'bologna',
          problemId: created.id,
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      reloadedStore.dispose();
      reloadedData.dispose();
    },
  );

  test(
    'wrong municipality and missing IDs cannot read another scope',
    () async {
      final repository = MockNextProblemsRepository(currentUserId: 'user-a');
      final created = await repository.submitSuggestedProblem(
        municipalityId: 'bologna',
        title: 'Alberi',
        description: 'Potatura',
        category: ProblemKey.green,
      );
      for (final request in [
        (municipality: 'castel-bolognese', id: created.id),
        (municipality: 'bologna', id: 'missing'),
        (municipality: 'bologna', id: ''),
      ]) {
        await expectLater(
          repository.getSuggestedProblem(
            municipalityId: request.municipality,
            problemId: request.id,
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', 404)
                .having((e) => e.code, 'code', 'suggested_problem_not_found'),
          ),
        );
      }
    },
  );
}

void _expectDetails(SuggestedProblem actual, SuggestedProblem expected) {
  expect(
    [
      actual.id,
      actual.title,
      actual.shortDescription,
      actual.location,
      actual.category,
      actual.createdAt.toUtc(),
      actual.status,
      actual.votesUp,
      actual.votesDown,
      actual.myVote,
      actual.submittedByDisplayName,
      actual.promotionRule.threshold,
      actual.promotionRule.scopeLabel,
      actual.promotionRule.reason,
    ],
    [
      expected.id,
      expected.title,
      expected.shortDescription,
      expected.location,
      expected.category,
      expected.createdAt.toUtc(),
      expected.status,
      expected.votesUp,
      expected.votesDown,
      expected.myVote,
      expected.submittedByDisplayName,
      expected.promotionRule.threshold,
      expected.promotionRule.scopeLabel,
      expected.promotionRule.reason,
    ],
  );
}
