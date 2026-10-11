import 'package:fanta_comune/core/config/app_config.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/profile/presentation/profile_page.dart';
import 'package:fanta_comune/features/leaderboard/presentation/leaderboard_page.dart';
import 'package:fanta_comune/features/leaderboard/domain/leaderboard_entry.dart';
import '../../../helpers/test_app.dart';

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
      'profile displays current numeric score and low data at $width',
      (tester) async {
        await _pump(tester, const ProfilePage(), _Repository(), width: width);
        expect(find.text('Punti: 42'), findsOneWidget);
        expect(find.text('Previsioni concluse: 2'), findsOneWidget);
        expect(find.text('Accuratezza: 50%'), findsOneWidget);
        expect(find.textContaining('Pochi dati:'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'leaderboard keeps local identity, points and long names readable at $width',
      (tester) async {
        await _pump(
          tester,
          const LeaderboardPage(),
          _Repository(),
          width: width,
        );
        expect(find.textContaining('Comune: Bologna'), findsOneWidget);
        expect(find.textContaining('(Tu)'), findsOneWidget);
        expect(find.text('42 pt'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'empty leaderboard proposes an actionable next step at $width',
      (tester) async {
        await _pump(
          tester,
          const LeaderboardPage(),
          _Repository(),
          width: width,
          municipality: 'comune:Pincara',
        );
        expect(
          find.text('Non ci sono ancora punteggi per questo Comune.'),
          findsOneWidget,
        );
        final cta = find.widgetWithText(FilledButton, 'Proponi un problema');
        await tester.ensureVisible(cta);
        await tester.tap(cta);
        await tester.pumpAndSettle();
        expect(find.text('Form proposte'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'profile retries errors and never fabricates zero accuracy for new town',
    (tester) async {
      final repo = _Repository()..failHistory = true;
      final prefs = await _pump(tester, const ProfilePage(), repo, width: 390);
      final retry = find.text('Riprova');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await _finishLoads(tester);
      expect(find.text('Punti: 42'), findsOneWidget);
      await prefs.setMunicipalityId('comune:Pincara');
      await _finishLoads(tester);
      expect(find.text('Punti: 0'), findsOneWidget);
      expect(
        find.text('Accuratezza: non disponibile, nessuna previsione conclusa.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile discards late history after municipality changes', (
    tester,
  ) async {
    final pending = Completer<List<ReputationScore>>();
    final repo = _Repository()..pendingHistory = pending;
    final prefs = await _pump(
      tester,
      const ProfilePage(),
      repo,
      width: 390,
      settle: false,
    );
    await prefs.setMunicipalityId('comune:Pincara');
    await tester.pumpAndSettle();
    pending.complete([
      const ReputationScore(totalPoints: 99, accuracy: 1, predictionsCount: 20),
    ]);
    await _finishLoads(tester);
    expect(find.text('Punti: 0'), findsOneWidget);
    expect(find.text('Punti: 42'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaderboard can retry a failed load', (tester) async {
    await _pump(
      tester,
      const LeaderboardPage(),
      _Repository()..failLeaderboard = true,
      width: 390,
    );
    final retry = find.byKey(const ValueKey('leaderboard-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.textContaining('(Tu)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<AppPrefs> _pump(
  WidgetTester tester,
  Widget page,
  GameRepository repository, {
  required double width,
  String municipality = 'comune:Bologna',
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final prefs = await createTestPrefs({
    'municipality_id': municipality,
    'user_id': 'user:test',
  });
  final router = GoRouter(
    initialLocation: '/page',
    routes: [
      GoRoute(
        path: '/page',
        builder: (_, _) => Scaffold(body: page),
      ),
      GoRoute(
        path: '/suggest-problem',
        builder: (_, _) => const Scaffold(body: Text('Form proposte')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: AppConfig.fromValues()),
        ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        Provider<GameRepository>.value(value: repository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    ),
  );
  if (settle)
    await _finishLoads(tester);
  else
    await tester.pump(const Duration(milliseconds: 350));
  return prefs;
}

class _Repository extends MockGameRepository {
  bool failHistory = false;
  bool failLeaderboard = false;
  Completer<List<ReputationScore>>? pendingHistory;
  @override
  String get currentUserId => 'user:test';
  @override
  Future<ReputationScore> getReputationScore(String turnId) async =>
      turnId == 'turn-activation'
      ? const ReputationScore(totalPoints: 0, accuracy: 0, predictionsCount: 0)
      : const ReputationScore(
          totalPoints: 42,
          accuracy: 0.5,
          predictionsCount: 2,
        );
  @override
  Future<List<ReputationScore>> getReputationHistory({
    required String municipalityId,
  }) async {
    if (municipalityId == 'comune:Pincara') return [];
    if (failHistory) {
      failHistory = false;
      throw StateError('Private technical error');
    }
    if (pendingHistory != null) return pendingHistory!.future;
    return [
      const ReputationScore(
        totalPoints: 42,
        accuracy: 0.5,
        predictionsCount: 2,
      ),
    ];
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String municipalityId,
    String? leagueId,
  }) async {
    if (failLeaderboard) {
      failLeaderboard = false;
      throw StateError('Private technical error');
    }
    if (municipalityId == 'comune:Pincara') return [];
    return [
      const LeaderboardEntry(
        userId: 'user:test',
        displayName: 'Nome partecipante lungo per controllare il testo a capo',
        points: 42,
        rank: 1,
      ),
    ];
  }
}

Future<void> _finishLoads(WidgetTester tester) async {
  for (var index = 0; index < 4; index++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle();
}
