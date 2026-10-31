import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import '../../helpers/memory_local_backend.dart';

void main() {
  test(
    'IDs, fields, places, votes and promoted cards survive reconstruction',
    () async {
      final backend = MemoryLocalBackend();
      final store = CivicLoopStore(
        currentUserId: 'user-a',
        localData: LocalDataStore(backend: backend),
      );
      final first = await store.submitSuggestedProblem(
        municipalityId: 'comune:Pincara',
        title: ' Alberi ',
        description: ' Potatura ',
        category: ProblemKey.green,
        location: ProposalLocation.specific(
          label: 'Via Milano',
          civic: '12/A',
          reference: 'Ingresso nord',
        ),
      );
      final second = await store.submitSuggestedProblem(
        municipalityId: 'COMUNE: PINCARA',
        title: 'Alberi',
        description: 'Potatura',
        category: ProblemKey.green,
        location: const ProposalLocation.municipality(),
      );
      expect(first.id, isNot(second.id));
      final voted = await store.voteSuggestedProblem(
        municipalityId: 'comune:Pincara',
        problemId: first.id,
        vote: VoteChoice.up,
      );
      final before = store.promotedProblems('comune:Pincara').single;
      final restored = CivicLoopStore(
        currentUserId: 'user-a',
        localData: LocalDataStore(backend: backend),
      );
      final items = restored.listNextProblems(municipalityId: 'comune:pincara');
      expect(items, hasLength(2));
      final found = items.firstWhere((item) => item.id == first.id);
      expect(found.title, 'Alberi');
      expect(found.createdAt.toUtc(), first.createdAt.toUtc());
      expect(found.location, first.location);
      expect(found.myVote, VoteChoice.up);
      expect(found.votesUp, voted.votesUp);
      expect(found.status, voted.status);
      expect(restored.promotedProblems('comune:pincara').single, before);
      final next = await restored.submitSuggestedProblem(
        municipalityId: 'comune:pincara',
        title: 'Alberi',
        description: 'Altro tratto',
        category: ProblemKey.green,
      );
      expect({first.id, second.id, next.id}, hasLength(3));
    },
  );

  test(
    'seed IDs and vote indexes isolate towns and voters across restart',
    () async {
      final backend = MemoryLocalBackend();
      final store = CivicLoopStore(
        currentUserId: 'user-a',
        localData: LocalDataStore(backend: backend),
      );
      final bologna = store.listNextProblems(municipalityId: 'comune:Bologna');
      final roma = store.listNextProblems(municipalityId: 'comune:Roma');
      expect(
        bologna
            .map((p) => p.id)
            .toSet()
            .intersection(roma.map((p) => p.id).toSet()),
        isEmpty,
      );
      final first = bologna.first;
      await store.voteSuggestedProblem(
        municipalityId: 'bologna',
        problemId: first.id,
        vote: VoteChoice.up,
      );
      expect(
        store.listNextProblems(municipalityId: 'comune:Roma').first.myVote,
        VoteChoice.none,
      );
      await store.voteSuggestedProblem(
        municipalityId: 'comune:Roma',
        problemId: roma.first.id,
        vote: VoteChoice.down,
      );
      final restored = CivicLoopStore(
        currentUserId: 'user-a',
        localData: LocalDataStore(backend: backend),
      );
      expect(
        restored.listNextProblems(municipalityId: 'bologna').first.myVote,
        VoteChoice.up,
      );
      expect(
        restored.listNextProblems(municipalityId: 'comune:Roma').first.myVote,
        VoteChoice.down,
      );
      final otherUser = CivicLoopStore(
        currentUserId: 'user-b',
        localData: LocalDataStore(backend: backend),
      );
      expect(
        otherUser.listNextProblems(municipalityId: 'bologna').first.myVote,
        VoteChoice.none,
      );
      expect(
        otherUser.listNextProblems(municipalityId: 'comune:Roma').first.myVote,
        VoteChoice.none,
      );
      final toggle = await restored.voteSuggestedProblem(
        municipalityId: 'comune:Bologna',
        problemId: first.id,
        vote: VoteChoice.up,
      );
      expect(toggle.myVote, VoteChoice.none);
      expect(toggle.votesUp, first.votesUp);
    },
  );

  test('failed writes do not publish phantom proposals or votes', () async {
    final backend = MemoryLocalBackend();
    final store = CivicLoopStore(
      currentUserId: 'user-a',
      localData: LocalDataStore(backend: backend),
    );
    backend.onWrite = (_, _) async => false;
    await expectLater(
      store.submitSuggestedProblem(
        municipalityId: 'comune:Pincara',
        title: 'Alberi',
        description: 'Potatura',
        category: ProblemKey.green,
      ),
      throwsA(isA<LocalDataWriteException>()),
    );
    expect(store.listNextProblems(municipalityId: 'comune:Pincara'), isEmpty);
    backend.onWrite = null;
    final saved = await store.submitSuggestedProblem(
      municipalityId: 'comune:Pincara',
      title: 'Alberi',
      description: 'Potatura',
      category: ProblemKey.green,
    );
    backend.onWrite = (_, _) async => false;
    await expectLater(
      store.voteSuggestedProblem(
        municipalityId: 'comune:Pincara',
        problemId: saved.id,
        vote: VoteChoice.up,
      ),
      throwsA(isA<LocalDataWriteException>()),
    );
    expect(
      store.listNextProblems(municipalityId: 'comune:Pincara').single.myVote,
      VoteChoice.none,
    );
    expect(store.promotedProblems('comune:Pincara'), isEmpty);
    expect(
      CivicLoopStore(
        currentUserId: 'user-a',
        localData: LocalDataStore(backend: backend),
      ).listNextProblems(municipalityId: 'comune:Pincara').single.id,
      saved.id,
    );
  });

  test(
    'reset cancels pending persistence and delayed game writes, then empties both providers',
    () async {
      final backend = MemoryLocalBackend();
      final local = LocalDataStore(backend: backend);
      final store = CivicLoopStore(currentUserId: 'user-a', localData: local);
      final game = MockGameRepository(civicLoopStore: store);
      final turn = await game.getCurrentTurn('bologna');
      final problems = await game.listProblems('bologna');
      await game.upsertPrediction(
        turnId: turn.id,
        problemId: problems.first.id,
        choice: PredictionChoice.improve,
      );
      final delayed = game.upsertPrediction(
        turnId: turn.id,
        problemId: problems[1].id,
        choice: PredictionChoice.stable,
      );
      final delayedCheck = expectLater(
        delayed,
        throwsA(isA<LocalDataResetException>()),
      );
      final entered = Completer<void>();
      final release = Completer<bool>();
      backend.onWrite = (_, _) {
        entered.complete();
        return release.future;
      };
      final pending = store.submitSuggestedProblem(
        municipalityId: 'comune:Pincara',
        title: 'Da cancellare',
        description: 'In volo',
        category: ProblemKey.green,
      );
      final pendingCheck = expectLater(
        pending,
        throwsA(isA<LocalDataResetException>()),
      );
      await entered.future;
      expect(store.listNextProblems(municipalityId: 'comune:Pincara'), isEmpty);
      final reset = local.reset();
      release.complete(true);
      await Future.wait([reset, pendingCheck, delayedCheck]);
      expect(store.listNextProblems(municipalityId: 'comune:Pincara'), isEmpty);
      expect(await game.getMyPredictions(turn.id), isEmpty);
      expect((await game.getReputationScore(turn.id)).totalPoints, 0);
      game.dispose();
      store.dispose();
    },
  );

  test(
    'different environments stay isolated and corrupt snapshots are not silently replaced',
    () async {
      final local = LocalDataStore(backend: MemoryLocalBackend());
      final first = CivicLoopStore(
        currentUserId: 'user',
        localData: local,
        storageKey: () => 'mock:first',
      );
      final second = CivicLoopStore(
        currentUserId: 'user',
        localData: local,
        storageKey: () => 'mock:second',
      );
      await first.submitSuggestedProblem(
        municipalityId: 'comune:Pincara',
        title: 'Alberi',
        description: 'Potatura',
        category: ProblemKey.green,
      );
      expect(
        second.listNextProblems(municipalityId: 'comune:Pincara'),
        isEmpty,
      );
      await local.mutate(
        'mock:second',
        (_) => const LocalDataMutation({'version': 99}, true),
      );
      expect(
        () => second.listNextProblems(municipalityId: 'comune:Pincara'),
        throwsA(isA<LocalDataCorruptException>()),
      );
      await expectLater(
        second.submitSuggestedProblem(
          municipalityId: 'comune:Pincara',
          title: 'Nuova',
          description: 'Testo',
          category: ProblemKey.green,
        ),
        throwsA(isA<LocalDataCorruptException>()),
      );
      expect(local.read('mock:second'), {'version': 99});
    },
  );
}
