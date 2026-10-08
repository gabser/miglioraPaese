import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart'
    hide FantasyCard;
import 'package:fanta_comune/features/fantasy/presentation/widgets/fantasy_widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/config/app_config.dart';

import '../../../helpers/test_app.dart';
import '../fantasy_test_support.dart';

void main() {
  testWidgets(
    'pending reveal keeps its source badge and awards no personal result',
    (tester) async {
      final h = await createHarness();
      final pending = result(status: FantasySourceStatus.pending);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreReveal(
              card: h.manager.cards.first,
              outcome: pending,
              score: h.manager.scoreFor(pending),
              prediction: null,
              personal: false,
            ),
          ),
        ),
      );
      expect(find.text('Fonte in attesa'), findsOneWidget);
      expect(find.text('Fonte verificata'), findsNothing);
      expect(find.textContaining('nessun punto personale'), findsOneWidget);
    },
  );

  testWidgets('motivation input is saved and becomes read only at lock', (
    tester,
  ) async {
    final h = await createHarness();
    await tester.pumpWidget(
      buildTestApp(
        h.prefs,
        config: AppConfig.fromValues(fantasyModeEnabled: true),
        fantasyManager: h.manager,
      ),
    );
    await pumpRoutingFrame(tester);
    await tester.tap(find.text('Crea la tua rosa'));
    await pumpRoutingFrame(tester);
    await tester.tap(find.text('Giornata'));
    await pumpRoutingFrame(tester);
    final expand = find.text('Aggiungi una motivazione facoltativa').first;
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    final field = find.byKey(
      const ValueKey('motivation-matchday-2-buche-centro'),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Segnale dal quartiere');
    await tester.pump();
    expect(h.manager.motivations['buche-centro'], 'Segnale dal quartiere');
    await h.at(day.locksAt);
    await tester.pump();
    expect(tester.widget<TextFormField>(field).enabled, isFalse);
    expect(find.text('Segnale dal quartiere'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final viewport in const {
    'mobile': Size(390, 844),
    'tablet': Size(1024, 768),
    'desktop': Size(1440, 900),
  }.entries) {
    testWidgets(
      '${viewport.key}: extra transfer, source availability, lock and reflection',
      (tester) async {
        tester.view.physicalSize = viewport.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = await createHarness();
        await h.manager.transfer(
          outgoingId: 'parco-nord',
          incomingId: 'fontanelle-ovest',
        );
        await h.manager.transfer(
          outgoingId: 'fontanelle-ovest',
          incomingId: 'parco-nord',
        );
        await tester.pumpWidget(
          buildTestApp(
            h.prefs,
            config: AppConfig.fromValues(fantasyModeEnabled: true),
            fantasyManager: h.manager,
          ),
        );
        await pumpRoutingFrame(tester);
        await tester.tap(find.text('Crea la tua rosa'));
        await pumpRoutingFrame(tester);
        await tester.tap(find.text('Mercato'));
        await pumpRoutingFrame(tester);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pulizia del parco · 11 cr').last);
        await tester.pumpAndSettle();
        final blockedCard = find.byWidgetPredicate(
          (w) => w is FantasyCard && w.card.id == 'ciclabile-est',
        );
        final blockedButton = find.descendant(
          of: blockedCard,
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        );
        expect(tester.widget<FilledButton>(blockedButton).onPressed, isNull);
        expect(
          find.text('Fonte non disponibile: acquisto sospeso.'),
          findsOneWidget,
        );
        final card = find.byWidgetPredicate(
          (w) => w is FantasyCard && w.card.id == 'fontanelle-ovest',
        );
        final buy = find.descendant(
          of: card,
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        );
        await tester.ensureVisible(buy);
        await tester.tap(buy);
        await tester.pumpAndSettle();
        expect(find.text('Penalità: −4 punti nella giornata'), findsOneWidget);
        await tester.tap(find.text('Conferma'));
        await tester.pumpAndSettle();
        expect(h.manager.transferPenalty, 4);
        expect(h.manager.squadIds, contains('fontanelle-ovest'));
        await h.manager.setCaptain('bus-stazione');
        await h.manager.confirmLineup();
        await h.at(day.locksAt);
        await tester.pump();
        for (final button in tester.widgetList<FilledButton>(
          find.byWidgetPredicate((w) => w is FilledButton),
        )) {
          expect(button.onPressed, isNull);
        }
        await tester.tap(find.text('Squadra'));
        await pumpRoutingFrame(tester);
        final confirm = find.ancestor(
          of: find.text('Formazione confermata'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        );
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        expect(
          tester
              .widgetList<PopupMenuButton<String>>(
                find.byType(PopupMenuButton<String>),
              )
              .every((button) => !button.enabled),
          isTrue,
        );
        await tester.tap(find.text('Giornata'));
        await pumpRoutingFrame(tester);
        expect(find.text('Formazione bloccata'), findsOneWidget);
        expect(
          tester
              .widgetList<ChoiceChip>(find.byType(ChoiceChip))
              .every((chip) => chip.onSelected == null),
          isTrue,
        );
        expect(find.text('Conferma: Intervento osservato'), findsNothing);
        await h.at(day.observationEndsAt);
        await tester.pump();
        final reflection = find.text('Conferma: Intervento osservato');
        await tester.ensureVisible(reflection);
        await tester.tap(reflection);
        await tester.pumpAndSettle();
        expect(
          h.manager.reflectionFor(result()),
          ReflectionAnswer.observedIntervention,
        );
        expect(
          find.text('Riflessione confermata: Intervento osservato'),
          findsOneWidget,
        );
        expect(find.text('Conferma: Intervento osservato'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('dialog opened before lock refuses a late confirmation', (
    tester,
  ) async {
    final h = await createHarness();
    await tester.pumpWidget(
      buildTestApp(
        h.prefs,
        config: AppConfig.fromValues(fantasyModeEnabled: true),
        fantasyManager: h.manager,
      ),
    );
    await pumpRoutingFrame(tester);
    await tester.tap(find.text('Crea la tua rosa'));
    await pumpRoutingFrame(tester);
    await tester.tap(find.text('Mercato'));
    await pumpRoutingFrame(tester);
    final card = find.byWidgetPredicate(
      (w) => w is FantasyCard && w.card.id == 'fontanelle-ovest',
    );
    final buy = find.descendant(
      of: card,
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();
    h.time = day.locksAt;
    await tester.tap(find.text('Conferma'));
    await tester.pumpAndSettle();
    expect(h.manager.transfers, isEmpty);
    expect(find.text('Mercato chiuso: giornata bloccata.'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('timer and app resume lock the visible controls', (tester) async {
    final prefs = await createTestPrefs({});
    var time = epoch;
    final manager = FantasyManager(
      prefs,
      now: () => time,
      initialMatchday: day,
    );
    var disposed = false;
    addTearDown(() {
      if (!disposed) manager.dispose();
    });
    await tester.pumpWidget(
      buildTestApp(
        prefs,
        config: AppConfig.fromValues(fantasyModeEnabled: true),
        fantasyManager: manager,
      ),
    );
    await pumpRoutingFrame(tester);
    await tester.tap(find.text('Crea la tua rosa'));
    await pumpRoutingFrame(tester);
    time = day.locksAt;
    await tester.pump(const Duration(seconds: 1));
    expect(manager.snapshotFor(day.id), isNotNull);
    final confirm = find.ancestor(
      of: find.text('Conferma formazione'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    time = day.observationEndsAt;
    manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(manager.outcomes.where((o) => o.matchdayId == day.id), isNotEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
    disposed = true;
  });

  testWidgets(
    'fantasy privacy reset returns to welcome with no saved or in-memory game',
    (tester) async {
      final h = await createHarness();
      await h.manager.setPrediction('buche-centro', CivicTrend.stable);
      await tester.pumpWidget(
        buildTestApp(
          h.prefs,
          config: AppConfig.fromValues(fantasyModeEnabled: true),
          fantasyManager: h.manager,
        ),
      );
      await pumpRoutingFrame(tester);
      await tester.tap(find.text('Crea la tua rosa'));
      await pumpRoutingFrame(tester);
      GoRouter.of(tester.element(find.text('La mia squadra'))).go('/privacy');
      await pumpRoutingFrame(tester);
      await tester.ensureVisible(find.text('Azzera preferenze e riparti'));
      await tester.tap(find.text('Azzera preferenze e riparti'));
      await tester.pumpAndSettle();
      expect(find.text('Crea la tua rosa'), findsOneWidget);
      expect(h.prefs.fantasyStateJson, isNull);
      expect(h.manager.predictions, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed persistence exposes a working retry action', (
    tester,
  ) async {
    final original = await createTestPrefs({});
    final prefs = ControlledPrefs(await SharedPreferences.getInstance());
    final h = Harness(prefs);
    await h.manager.settled;
    prefs.fail = true;
    await h.manager.setMotivation('buche-centro', 'Retry');
    await h.manager.settled;
    await tester.pumpWidget(
      buildTestApp(
        original,
        config: AppConfig.fromValues(fantasyModeEnabled: true),
        fantasyManager: h.manager,
      ),
    );
    await pumpRoutingFrame(tester);
    await tester.tap(find.text('Crea la tua rosa'));
    await pumpRoutingFrame(tester);
    expect(find.textContaining('Salvataggio non riuscito'), findsOneWidget);
    prefs.fail = false;
    await tester.tap(find.text('Riprova salvataggio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Salvataggio non riuscito'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('feature flag apre benvenuto e squadra manager civico', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await createTestPrefs({});
    final config = AppConfig.fromValues(fantasyModeEnabled: true);

    await tester.pumpWidget(buildTestApp(prefs, config: config));
    await pumpRoutingFrame(tester);

    expect(
      find.text('Costruisci la tua squadra di priorità locali.'),
      findsOneWidget,
    );
    expect(find.text('Crea la tua rosa'), findsOneWidget);

    await tester.tap(find.text('Crea la tua rosa'));
    await pumpRoutingFrame(tester);

    expect(find.text('La mia squadra'), findsOneWidget);
    expect(find.text('Titolari · 5'), findsOneWidget);
    expect(find.text('Riserve · 3'), findsOneWidget);
    expect(find.text('Conferma formazione'), findsOneWidget);
  });

  testWidgets('navigazione espone le cinque aree principali', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await createTestPrefs({});
    final config = AppConfig.fromValues(fantasyModeEnabled: true);

    await tester.pumpWidget(buildTestApp(prefs, config: config));
    await pumpRoutingFrame(tester);
    await tester.tap(find.text('Crea la tua rosa'));
    await pumpRoutingFrame(tester);

    expect(find.text('Squadra'), findsOneWidget);
    expect(find.text('Giornata'), findsOneWidget);
    expect(find.text('Mercato'), findsOneWidget);
    expect(find.text('Leghe'), findsOneWidget);
    expect(find.text('Profilo'), findsOneWidget);

    await tester.tap(find.text('Giornata'));
    await pumpRoutingFrame(tester);
    expect(find.text('Fai le tue previsioni'), findsOneWidget);
    expect(find.text('0/5 previsioni inserite'), findsOneWidget);
  });

  for (final viewport in const {
    'tablet': Size(1024, 768),
    'desktop': Size(1440, 900),
  }.entries) {
    testWidgets('layout ${viewport.key} non produce overflow', (tester) async {
      tester.view.physicalSize = viewport.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await createTestPrefs({});
      final config = AppConfig.fromValues(fantasyModeEnabled: true);

      await tester.pumpWidget(buildTestApp(prefs, config: config));
      await pumpRoutingFrame(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Crea la tua rosa'));
      await pumpRoutingFrame(tester);
      expect(find.text('La mia squadra'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
