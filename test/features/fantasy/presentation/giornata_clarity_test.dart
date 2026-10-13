import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart'
    hide FantasyCard;
import 'package:fanta_comune/features/fantasy/presentation/widgets/fantasy_widgets.dart';
import '../fantasy_test_support.dart';
import '../../../helpers/test_app.dart';
import '../../../copy_responsive_test.dart' show captureCopy;

Future<void> openDay(
  WidgetTester tester,
  Harness h, {
  GlobalKey? boundary,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: buildTestApp(
        h.prefs,
        config: AppConfig.fromValues(fantasyModeEnabled: true),
        fantasyManager: h.manager,
      ),
    ),
  );
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/matchday');
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final directory = Platform.environment['COPY_FONT_DIR'];
    if (directory == null) return;
    for (final (family, name) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family);
      loader.addFont(
        File(
          '$directory/$name',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
      await loader.load();
    }
  });

  testWidgets(
    'exact deadlines, optional missing forecasts and incomplete results',
    (tester) async {
      final h = await createHarness();
      await h.manager.setPrediction('buche-centro', CivicTrend.stable);
      await openDay(tester, h);
      expect(find.textContaining('Fai le tue previsioni'), findsOneWidget);
      expect(
        find.textContaining('scegli entro il 9/10/2026 alle'),
        findsOneWidget,
      );
      expect(
        find.text('Conferma la formazione in Squadra per ottenere punti'),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 previsioni inserite su 5 titolari'),
        findsOneWidget,
      );
      await h.at(day.locksAt.subtract(const Duration(seconds: 1)));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(15));
      await h.at(day.locksAt);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Previsioni chiuse · Si gioca!'),
        findsOneWidget,
      );
      expect(
        find.textContaining('termina il periodo di gioco il 10/10/2026 alle'),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('La tua previsione: Stabile'), findsOneWidget);
      expect(find.text('Non hai inserito una previsione'), findsNWidgets(4));
      expect(find.text('Spiega la previsione, se vuoi'), findsNothing);
      expect(find.textContaining('restano nascoste'), findsNothing);
      expect(
        find.textContaining('Formazione non valida o non confermata al blocco'),
        findsOneWidget,
      );
      await h.at(day.observationEndsAt.subtract(const Duration(seconds: 1)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Previsioni chiuse · Si gioca!'),
        findsOneWidget,
      );
      await h.at(day.observationEndsAt);
      await tester.pumpAndSettle();
      expect(find.textContaining('Consulta esiti e punti'), findsOneWidget);
      expect(
        find.textContaining('1 disponibili · 4 ancora attesi'),
        findsOneWidget,
      );
      expect(find.textContaining('Esito osservato: Stabile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, scale) in [(320.0, 2.0), (1440.0, 1.0)]) {
    testWidgets(
      'previous results and reflections remain accessible at $width/$scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final h = await createHarness();
        await h.manager.setPrediction('buche-centro', CivicTrend.improves);
        await h.manager.confirmLineup();
        await h.at(day.observationEndsAt);
        final previousPoints = h.manager.scoreForMatchday(day.id).total;
        expect(h.manager.hasPersonalResult(result()), isTrue);
        expect(await h.manager.startNextMatchday(nextDay), isTrue);
        await openDay(tester, h);
        expect(
          find.textContaining('Giornata 3 · Fai le tue previsioni'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Non ci sono ancora esiti per questa giornata'),
          findsOneWidget,
        );
        expect(
          find.textContaining('0 previsioni inserite su 5 titolari'),
          findsOneWidget,
        );
        expect(find.byType(ScoreReveal), findsNothing);
        final history = find.text('Esiti delle giornate precedenti');
        await tester.ensureVisible(history);
        await tester.tap(history);
        await tester.pumpAndSettle();
        expect(find.text('Giornata 2'), findsOneWidget);
        final reveal = tester.widget<ScoreReveal>(find.byType(ScoreReveal));
        expect(reveal.outcome.matchdayId, day.id);
        expect(reveal.personal, isTrue);
        expect(reveal.prediction, CivicTrend.improves);
        expect(reveal.reflection, isNull);
        final answer = ReflectionAnswer.values.first;
        final confirm = find.widgetWithText(
          OutlinedButton,
          'Conferma: ${answer.label}',
        );
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(
          find.text('Riflessione confermata: ${answer.label}'),
          findsOneWidget,
        );
        expect(
          h.manager.scoreForMatchday(day.id).total,
          greaterThan(previousPoints),
        );
        expect(h.manager.scoreForMatchday(nextDay.id).total, 0);
        expect(h.manager.predictions, isEmpty);
        final restored = await h.reload();
        expect(restored.reflectionFor(result()), answer);
        expect(
          restored.scoreForMatchday(day.id).total,
          h.manager.scoreForMatchday(day.id).total,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final mode in ['absent', 'previous', 'pending', 'complete']) {
    testWidgets('results distinguish $mode outcomes', (tester) async {
      final h = await createHarness();
      final outcomes = switch (mode) {
        'previous' => [result(dayId: 'previous')],
        'pending' => [
          result(status: FantasySourceStatus.pending),
          result(
            cardId: 'bus-stazione',
            status: FantasySourceStatus.unavailable,
          ),
        ],
        'complete' =>
          h.manager.starterIds.map((id) => result(cardId: id)).toList(),
        _ => <CardOutcome>[],
      };
      final manager = FantasyManager(
        h.prefs,
        now: () => day.observationEndsAt,
        initialMatchday: day,
        initialOutcomes: outcomes,
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
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/matchday');
      await tester.pumpAndSettle();
      expect(find.textContaining('Consulta esiti e punti'), findsOneWidget);
      expect(
        find.textContaining(
          mode == 'complete'
              ? '5 disponibili · 0 ancora attesi'
              : '0 disponibili · 5 ancora attesi',
        ),
        findsOneWidget,
      );
      expect(
        find.byType(ScoreReveal),
        mode == 'complete'
            ? findsNWidgets(5)
            : mode == 'pending'
            ? findsNWidgets(2)
            : findsNothing,
      );
      if (mode == 'complete') {
        expect(find.textContaining('Per gli esiti mancanti'), findsNothing);
      }
      if (mode == 'absent' || mode == 'previous') {
        expect(
          find.textContaining('Non ci sono ancora esiti per questa giornata'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'failed save never claims success; retry restores editable choices',
    (tester) async {
      await createTestPrefs({});
      final prefs = ControlledPrefs(await SharedPreferences.getInstance());
      final h = Harness(prefs);
      await h.manager.settled;
      prefs.fail = true;
      await h.manager.setPrediction('buche-centro', CivicTrend.stable);
      await h.manager.settled;
      await openDay(tester, h);
      expect(find.textContaining('Stato da verificare'), findsOneWidget);
      expect(find.textContaining('Prossima scadenza:'), findsNothing);
      expect(find.textContaining('previsioni inserite su'), findsNothing);
      prefs.fail = false;
      await tester.tap(find.text('Riprova salvataggio'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Stato da verificare'), findsNothing);
      expect(find.textContaining('Fai le tue previsioni'), findsOneWidget);
      expect(h.manager.predictions['buche-centro'], CivicTrend.stable);
    },
  );

  testWidgets(
    'credits help works with keyboard; captain and history have readable semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final h = await createHarness();
      await openDay(tester, h);
      expect(
        tester
            .getSemantics(find.textContaining('Giornata 2 · Fai'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      var reachedHelp = false;
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
          element,
        ) {
          if (element.widget is ExpansionTile) reachedHelp = true;
          return !reachedHelp;
        });
        if (reachedHelp) break;
      }
      expect(reachedHelp, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.textContaining('Parti da 100 crediti'), findsOneWidget);
      final card = find.byWidgetPredicate(
        (w) => w is FantasyCard && w.isCaptain,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(find.text('Capitano · punti ×1,5'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Capitano: i punti della carta')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Il capitano moltiplica.*8 punti diventano 12 punti'),
        ),
        findsOneWidget,
      );
      expect(find.text('Come è cambiato il problema'), findsNWidgets(5));
      expect(find.text('Migliorato'), findsWidgets);
      expect(find.textContaining('Storico disponibile:'), findsNWidgets(5));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  for (final (width, scale) in [
    (390.0, 1.0),
    (1440.0, 1.0),
    (320.0, 2.0),
    (390.0, 4.0),
  ]) {
    testWidgets('visual day and market $width at $scale', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = await createHarness();
      final key = GlobalKey();
      await openDay(tester, h, boundary: key);
      await captureCopy(tester, key, 'day-$width-$scale-open');
      await h.manager.confirmLineup();
      await h.at(day.locksAt);
      await tester.pumpAndSettle();
      await captureCopy(tester, key, 'day-$width-$scale-locked');
      final captain = find.byWidgetPredicate(
        (w) => w is FantasyCard && w.isCaptain,
      );
      await tester.ensureVisible(captain);
      await tester.pumpAndSettle();
      await captureCopy(tester, key, 'day-$width-$scale-card');
      await h.at(day.observationEndsAt);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Giornata 2 · Consulta'));
      await tester.pumpAndSettle();
      await captureCopy(tester, key, 'day-$width-$scale-results');
      expect(tester.takeException(), isNull);
      // Exercise the real market dialog with explicit quote prices too.
      final marketKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: marketKey,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => MarketComparison(
                      outgoing: h.manager.cards.first,
                      incoming: h.manager.cards.last,
                      outgoingPrice: 13,
                      incomingPrice: 17,
                      availableCredits: 8,
                      penalty: 4,
                      onConfirm: () {},
                    ),
                  ),
                  child: const Text('Apri confronto'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri confronto'));
      await tester.pumpAndSettle();
      await captureCopy(tester, marketKey, 'market-$width-$scale');
      expect(
        find.textContaining('Credito disponibile: 8 crediti'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Valore recuperato dalla cessione: +13 crediti'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Costo della nuova carta: −17 crediti'),
        findsOneWidget,
      );
      expect(find.textContaining('Saldo finale: 4 crediti'), findsOneWidget);
      expect(find.text('Penalità: −4 punti nella giornata'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.text('Penalità: −4 punti nella giornata'),
      );
      await tester.pumpAndSettle();
      await captureCopy(tester, marketKey, 'market-$width-$scale-balance');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MarketComparison), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
