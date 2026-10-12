import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';

void main() {
  test('small semantic text has sufficient contrast on tinted surfaces', () {
    for (final tint in [
      AppTokens.blue,
      AppTokens.success,
      AppTokens.warning,
      AppTokens.danger,
    ]) {
      final foreground = AppTokens.foregroundFor(tint);
      final panel = Color.alphaBlend(
        tint.withValues(alpha: 0.12),
        Colors.white,
      );
      final chip = Color.alphaBlend(tint.withValues(alpha: 0.12), panel);
      for (final surface in [Colors.white, panel, chip]) {
        final contrast =
            (surface.computeLuminance() + 0.05) /
            (foreground.computeLuminance() + 0.05);
        expect(
          contrast,
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $surface',
        );
      }
    }
  });

  testWidgets('token artifact matches runtime typography and layout', (
    tester,
  ) async {
    final tokens =
        jsonDecode(File('assets/tokens.json').readAsStringSync())
            as Map<String, dynamic>;
    final typography = tokens['typography'] as Map<String, dynamic>;
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    final scale = typography['scale'] as Map<String, dynamic>;
    expect(theme.textTheme.bodyMedium!.fontFamily, typography['family']);
    final styles = {
      'headlineMedium': theme.textTheme.headlineMedium,
      'headlineSmall': theme.textTheme.headlineSmall,
      'titleLarge': theme.textTheme.titleLarge,
      'titleMedium': theme.textTheme.titleMedium,
      'titleSmall': theme.textTheme.titleSmall,
      'bodyLarge': theme.textTheme.bodyLarge,
      'bodyMedium': theme.textTheme.bodyMedium,
      'bodySmall': theme.textTheme.bodySmall,
      'labelLarge': theme.textTheme.labelLarge,
      'labelMedium': theme.textTheme.labelMedium,
      'labelSmall': theme.textTheme.labelSmall,
    };
    for (final entry in styles.entries) {
      expect(entry.value!.fontSize, scale[entry.key], reason: entry.key);
    }
    expect(
      tokens['layout']['narrowContentWidth'],
      AppTokens.narrowContentWidth,
    );
    expect(tokens['color']['canvas'], '#f6f8fb');
    expect(tokens['radius']['md'], AppTokens.radius);
  });

  testWidgets('status wraps at 200% and section title is a single heading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  FcSectionHeader(title: 'Proposte del Comune'),
                  FcStatusChip(
                    label: 'Comune in attivazione',
                    color: AppTokens.warning,
                    icon: Icons.info_outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .getSemantics(find.text('Proposte del Comune'))
          .flagsCollection
          .isHeader,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('zero values stay neutral and absent segments are excluded', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    Future<void> pump(double improve, double stable, double worsen) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FcPredictionBar(
              improve: improve,
              stable: stable,
              worsen: worsen,
            ),
          ),
        ),
      );
    }

    final segments = find.descendant(
      of: find.byType(FcPredictionBar),
      matching: find.byType(ColoredBox),
    );
    await pump(0, 0, 0);
    expect(
      find.bySemanticsLabel('Nessuna previsione disponibile'),
      findsOneWidget,
    );
    expect(tester.widget<ColoredBox>(segments).color, AppTokens.line);
    await pump(1, 0, 0);
    expect(segments, findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Previsioni: migliora 100%, stabile 0%, peggiora 0%',
      ),
      findsOneWidget,
    );
    expect(tester.widget<ColoredBox>(segments).color, AppTokens.success);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
