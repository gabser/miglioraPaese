import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/data/local_fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import '../fantasy_test_support.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('unreadable archive does not prevent using Squadra', (
    tester,
  ) async {
    final h = await createHarness();
    await (await SharedPreferences.getInstance()).setString(
      'fantasy_demo_archive_v1',
      '{',
    );
    await tester.pumpWidget(
      buildTestApp(
        h.prefs,
        config: AppConfig.fromValues(fantasyModeEnabled: true),
        fantasyManager: h.manager,
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/squad');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final restart = find.widgetWithText(TextButton, 'Nuova partita demo');
    await tester.ensureVisible(restart);
    await tester.tap(restart);
    await tester.pumpAndSettle();
    expect(find.text('Riprendi partita precedente'), findsOneWidget);
    expect(h.prefs.fantasyDemoArchive.first, '{');
    expect(tester.takeException(), isNull);
  });

  testWidgets('restart demo unblocks formation and exposes recovery', (
    tester,
  ) async {
    final h = await createHarness();
    await h.manager.confirmLineup();
    await h.at(day.locksAt);
    await tester.pumpWidget(
      buildTestApp(
        h.prefs,
        config: AppConfig.fromValues(fantasyModeEnabled: true),
        fantasyManager: h.manager,
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/squad');
    await tester.pumpAndSettle();
    final restart = find.widgetWithText(TextButton, 'Nuova partita demo');
    await tester.ensureVisible(restart);
    await tester.tap(restart);
    await tester.pumpAndSettle();
    expect(find.text('Formazione bloccata'), findsNothing);
    expect(find.text('Formazione da confermare'), findsOneWidget);
    expect(find.text('Riprendi partita precedente'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Conferma formazione'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'restored frozen formation stays locked in the progress after clock rollback',
    (tester) async {
      final h = await createHarness();
      await h.manager.confirmLineup();
      await h.at(day.locksAt);
      await h.at(epoch);
      expect(day.isLockedAt(epoch), isFalse);
      expect(h.manager.snapshotFor(day.id), isNotNull);
      await tester.pumpWidget(
        buildTestApp(
          h.prefs,
          config: AppConfig.fromValues(fantasyModeEnabled: true),
          fantasyManager: h.manager,
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/matchday');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Previsioni chiuse · Si gioca!'),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsNothing);
    },
  );

  testWidgets(
    'API save failure blocks controls without claiming a scheduled lock',
    (tester) async {
      final h = await createHarness();
      final data = await LocalFantasyRepository(
        h.prefs,
        now: () => epoch,
        initialMatchday: day,
      ).load();
      final manager = FantasyManager.withRepository(
        _FailingRemote(data),
        now: () => epoch,
        observeTime: false,
      );
      addTearDown(manager.dispose);
      await manager.settled;
      await tester.pumpWidget(
        buildTestApp(
          h.prefs,
          config: AppConfig.fromValues(fantasyModeEnabled: true),
          fantasyManager: manager,
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/squad');
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Conferma formazione');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(manager.canRestartDemo, isFalse);
      expect(find.text('Nuova partita demo'), findsNothing);
      expect(manager.persistenceError, isNotNull);
      expect(manager.isLocked, isTrue);
      expect(day.isLockedAt(epoch), isFalse);
      expect(find.text('Salvataggio non completato'), findsOneWidget);
      expect(find.text('Formazione bloccata'), findsNothing);
      expect(find.textContaining('Le scelte sono congelate'), findsNothing);
      expect(find.text('Formazione salvata'), findsNothing);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(
        tester
            .widgetList<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .every((popup) => !popup.enabled),
        isTrue,
      );
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/matchday');
      await tester.pumpAndSettle();
      expect(find.textContaining('Stato da verificare'), findsOneWidget);
      expect(
        find.textContaining('Previsioni chiuse · Si gioca!'),
        findsNothing,
      );
      expect(find.text('Formazione bloccata'), findsNothing);
      expect(find.textContaining('Le scelte sono congelate'), findsNothing);
    },
  );

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'saved squad survives reload; visible captain and swap controls require reconfirmation at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = await createHarness();
        final config = AppConfig.fromValues(fantasyModeEnabled: true);
        await tester.pumpWidget(
          buildTestApp(h.prefs, config: config, fantasyManager: h.manager),
        );
        await tester.pumpAndSettle();
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/squad');
        await tester.pumpAndSettle();
        expect(find.textContaining('Si apre la giornata'), findsOneWidget);
        expect(
          find.textContaining('Ultimo momento per scegliere'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Termina il periodo di gioco'),
          findsOneWidget,
        );
        final confirm = find.widgetWithText(
          FilledButton,
          'Conferma formazione',
        );
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('Formazione salvata'), findsOneWidget);
        final restored = await h.reload();
        await tester.pumpWidget(
          buildTestApp(h.prefs, config: config, fantasyManager: restored),
        );
        await tester.pumpAndSettle();
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/squad');
        await tester.pumpAndSettle();
        expect(find.text('Formazione salvata'), findsOneWidget);
        final captain = find.byKey(
          const ValueKey('squad-captain-bus-stazione'),
        );
        await tester.ensureVisible(captain);
        await tester.tap(captain);
        await tester.pumpAndSettle();
        expect(restored.captainId, 'bus-stazione');
        expect(restored.confirmed, isFalse);
        expect(find.text('Formazione salvata'), findsNothing);
        await tester.ensureVisible(find.text('Formazione da confermare'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        final swap = find.byKey(const ValueKey('squad-swap-lampioni-sud'));
        await tester.ensureVisible(swap);
        await tester.tap(swap);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Sostituisci con Attraversamenti scolastici'),
        );
        await tester.pumpAndSettle();
        expect(restored.starterIds, contains('attraversamenti-scuole'));
        expect(restored.confirmed, isFalse);
        expect(restored.lineupIssue, isNotNull);
        await tester.ensureVisible(find.text(restored.lineupIssue!));
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (width, scale) in [
    (320.0, 2.0),
    (390.0, 2.0),
    (720.0, 2.0),
    (899.0, 2.0),
    (900.0, 2.0),
    (1120.0, 2.0),
    (1440.0, 2.0),
    (320.0, 4.0),
    (390.0, 4.0),
  ]) {
    testWidgets(
      'Manager areas remain actionable at width $width and ${scale * 100}% text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final h = await createHarness();
        await h.prefs.setMunicipalityId('comune:Tuglie');
        await tester.pumpWidget(
          buildTestApp(
            h.prefs,
            config: AppConfig.fromValues(fantasyModeEnabled: true),
            fantasyManager: h.manager,
          ),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(
          tester.element(find.text('Crea la tua squadra')),
        );
        for (final route in ['/squad', '/matchday', '/market', '/leagues']) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: route);
        }
        router.go('/squad');
        await tester.pumpAndSettle();
        final confirm = find.widgetWithText(
          FilledButton,
          'Conferma formazione',
        );
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(h.manager.confirmed, isTrue);
        await h.at(day.locksAt);
        router.go('/matchday');
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Previsioni chiuse · Si gioca!'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _FailingRemote implements RemoteFantasyRepository {
  _FailingRemote(this.data);
  final FantasyData data;
  @override
  FantasyData get cached => data;
  @override
  bool get hasPendingTransfer => false;
  @override
  Future<FantasyData> load() async => data;
  @override
  Future<FantasyData> synchronize({required int expectedRevision}) async =>
      data;
  @override
  Future<FantasyData?> clear() async => null;
  @override
  Future<FantasyData> execute(
    FantasyCommand command, {
    required int expectedRevision,
  }) async => throw const ApiException(
    kind: ApiExceptionKind.network,
    code: 'network_error',
    message: 'Invio non confermato',
  );
  @override
  Future<FantasyData> retryPendingTransfer() => throw UnimplementedError();
  @override
  Future<FantasyTransferQuote> quoteTransfer(
    String outgoingId,
    String incomingId,
    int revision,
  ) => throw UnimplementedError();
}
