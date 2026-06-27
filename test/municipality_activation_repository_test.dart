import 'package:flutter_test/flutter_test.dart';

import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';

void main() {
  test('mock game repository exposes an empty activation state for new towns',
      () async {
    final repository = MockGameRepository();
    const municipalityId = 'comune:Pincara';

    final activationState =
        await repository.getMunicipalityActivationState(municipalityId);
    final turn = await repository.getCurrentTurn(municipalityId);
    final problems = await repository.listProblems(municipalityId);
    final predictions = await repository.getMyPredictions(turn.id);
    final leaderboard =
        await repository.getLeaderboard(municipalityId: municipalityId);

    expect(activationState, MunicipalityActivationState.newMunicipality);
    expect(turn.id, 'turn-activation');
    expect(problems, isEmpty);
    expect(predictions, isEmpty);
    expect(leaderboard, isEmpty);
  });

  test('mock next-problems repository starts empty and accepts first proposal',
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

    final proposals =
        await repository.listNextProblems(municipalityId: municipalityId);
    expect(proposals, hasLength(1));
    expect(proposals.single.title, 'Lampioni spenti');
  });

  test('seeded municipalities keep active mock problems and proposals',
      () async {
    final gameRepository = MockGameRepository();
    final nextRepository =
        MockNextProblemsRepository(currentUserId: 'user:test');
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
  });
}
