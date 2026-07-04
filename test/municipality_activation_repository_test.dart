import 'package:flutter_test/flutter_test.dart';

import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

void main() {
  test(
    'mock game repository exposes an empty activation state for new towns',
    () async {
      final repository = MockGameRepository();
      const municipalityId = 'comune:Pincara';

      final activationState = await repository.getMunicipalityActivationState(
        municipalityId,
      );
      final turn = await repository.getCurrentTurn(municipalityId);
      final problems = await repository.listProblems(municipalityId);
      final predictions = await repository.getMyPredictions(turn.id);
      final leaderboard = await repository.getLeaderboard(
        municipalityId: municipalityId,
      );

      expect(activationState, MunicipalityActivationState.newMunicipality);
      expect(turn.id, 'turn-activation');
      expect(problems, isEmpty);
      expect(predictions, isEmpty);
      expect(leaderboard, isEmpty);
    },
  );

  test(
    'mock next-problems repository starts empty and accepts first proposal',
    () async {
      final repository = MockNextProblemsRepository(currentUserId: 'user:test');
      const municipalityId = 'comune:Pincara';

      expect(
        await repository.listNextProblems(municipalityId: municipalityId),
        isEmpty,
      );

      await repository.submitSuggestedProblem(
        municipalityId: municipalityId,
        title: 'Lampioni spenti',
        description: 'Via Roma resta buia la sera.',
        category: ProblemKey.lighting,
      );

      final proposals = await repository.listNextProblems(
        municipalityId: municipalityId,
      );
      expect(proposals, hasLength(1));
      expect(proposals.single.title, 'Lampioni spenti');
    },
  );

  test(
    'seeded municipalities keep active mock problems and proposals',
    () async {
      final gameRepository = MockGameRepository();
      final nextRepository = MockNextProblemsRepository(
        currentUserId: 'user:test',
      );
      final municipalityId = MunicipalityCatalog.idForCity('Milano');

      expect(
        await gameRepository.getMunicipalityActivationState(municipalityId),
        MunicipalityActivationState.active,
      );
      expect(await gameRepository.listProblems(municipalityId), isNotEmpty);
      expect(
        await nextRepository.listNextProblems(municipalityId: municipalityId),
        isNotEmpty,
      );
    },
  );

  test(
    'first civic loop promotes a confirmed proposal to a turn card',
    () async {
      final store = CivicLoopStore(currentUserId: 'user:test');
      final gameRepository = MockGameRepository(civicLoopStore: store);
      final nextRepository = MockNextProblemsRepository(
        currentUserId: 'user:test',
        store: store,
      );
      const municipalityId = 'comune:Pincara';

      final proposal = await nextRepository.submitSuggestedProblem(
        municipalityId: municipalityId,
        title: 'Lampioni spenti',
        description: 'Via Roma resta buia la sera.',
        category: ProblemKey.lighting,
      );

      final confirmed = await nextRepository.voteSuggestedProblem(
        municipalityId: municipalityId,
        problemId: proposal.id,
        vote: VoteChoice.up,
      );
      final problems = await gameRepository.listProblems(municipalityId);
      final summary = await gameRepository.getCivicLoopSummary(municipalityId);

      expect(confirmed.status, SuggestedProblemStatus.approved);
      expect(confirmed.votesUp, 1);
      expect(confirmed.promotionRule.threshold, 1);
      expect(confirmed.approvalsNeeded, 0);
      expect(confirmed.promotionProgress, 1);
      expect(
        await gameRepository.getMunicipalityActivationState(municipalityId),
        MunicipalityActivationState.active,
      );
      expect(problems, hasLength(1));
      expect(problems.single.title, 'Lampioni spenti');
      expect(summary.proposedThemes, 1);
      expect(summary.confirmedThemes, 1);
      expect(summary.cardsInTurn, 1);
      expect(summary.topThemeTitle, 'Lampioni spenti');
    },
  );

  test(
    'mock game repository locks the main prediction after first vote',
    () async {
      final repository = MockGameRepository();
      final municipalityId = MunicipalityCatalog.idForCity('Milano');
      final turn = await repository.getCurrentTurn(municipalityId);
      final problem = (await repository.listProblems(municipalityId)).first;

      await repository.upsertPrediction(
        turnId: turn.id,
        problemId: problem.id,
        choice: PredictionChoice.improve,
      );

      expect(
        () => repository.upsertPrediction(
          turnId: turn.id,
          problemId: problem.id,
          choice: PredictionChoice.worsen,
        ),
        throwsStateError,
      );
    },
  );
}
