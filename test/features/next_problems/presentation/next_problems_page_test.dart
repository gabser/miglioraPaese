import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/promotion_rule.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import 'package:fanta_comune/features/next_problems/presentation/next_problems_page.dart';

void main() {
  testWidgets('shows a human error and retries successfully on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'municipality_id': 'comune:Bologna',
      'user_id': 'user:test',
    });
    final prefs = await AppPrefs.init();
    final repository = _RetryRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppPrefs>.value(value: prefs),
          Provider<NextProblemsRepository>.value(value: repository),
        ],
        child: const MaterialApp(home: NextProblemsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Temi non disponibili'), findsOneWidget);
    expect(find.textContaining('Controlla la connessione'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final retryButton = find.byKey(const ValueKey('next-problems-retry'));
    await tester.ensureVisible(retryButton);
    await tester.pumpAndSettle();
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Illuminazione al parco'), findsOneWidget);
    expect(find.text('Temi non disponibili'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _RetryRepository implements NextProblemsRepository {
  int calls = 0;

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) async {
    calls++;
    if (calls == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        code: 'network_error',
        message: 'socket failed',
      );
    }
    return [_problem()];
  }

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SuggestedProblem> voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) {
    throw UnimplementedError();
  }
}

SuggestedProblem _problem() {
  return SuggestedProblem(
    id: 'suggested-1',
    title: 'Illuminazione al parco',
    shortDescription: 'Percorsi poco leggibili la sera.',
    category: ProblemKey.lighting,
    createdAt: DateTime.utc(2026, 7, 4),
    status: SuggestedProblemStatus.pending,
    votesUp: 0,
    votesDown: 0,
    myVote: VoteChoice.none,
    submittedByDisplayName: 'Tu',
    promotionRule: const PromotionRule(
      threshold: 1,
      scopeLabel: 'Bologna · illuminazione',
      reason: 'Una approvazione netta promuove il tema.',
    ),
  );
}
