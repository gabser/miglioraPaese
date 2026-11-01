import 'dart:async';
import 'dart:ui' as ui;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_point_map.dart';
import '../../../helpers/proposal_form_actions.dart';

class _FailedImage extends ImageProvider<_FailedImage> {
  @override
  Future<_FailedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _FailedImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Future.error(StateError('offline tiles')));
}

class _FailedTiles extends TileProvider {
  bool fail = true;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      fail ? _FailedImage() : MemoryImage(LocalProposalTiles.bytes);
}

class _DeferredImage extends ImageProvider<_DeferredImage> {
  _DeferredImage(this.frame);
  final Completer<ImageInfo> frame;
  @override
  Future<_DeferredImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _DeferredImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(frame.future);
}

class _ReloadingTiles extends TileProvider {
  bool hold = false;
  final pending = <Completer<ImageInfo>>[];
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (!hold) return MemoryImage(LocalProposalTiles.bytes);
    final frame = Completer<ImageInfo>();
    pending.add(frame);
    return _DeferredImage(frame);
  }

  Future<void> finishLoading() async {
    final codec = await ui.instantiateImageCodec(LocalProposalTiles.bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    for (final pendingFrame in pending) {
      pendingFrame.complete(ImageInfo(image: frame.image.clone()));
    }
    pending.clear();
    frame.image.dispose();
  }
}

void main() {
  test('every requested Comune has its own framing and demo has no map', () {
    for (final id in [
      'Tuglie',
      'Bologna',
      'Castel Bolognese',
      'Milano',
      'Roma',
      'Torino',
      'Napoli',
      'Palermo',
      'Firenze',
      'Genova',
    ]) {
      expect(ProposalMapViews.forMunicipality('comune:$id'), isNotNull);
    }
    expect(ProposalMapViews.forMunicipality('demo'), isNull);
  });

  Future<void> pumpMap(
    WidgetTester tester, {
    required TileProvider tiles,
    ProposalCoordinates? point,
    ValueChanged<ProposalCoordinates>? onConfirmed,
  }) async {
    await tester.pumpWidget(
      Provider<AppConfig>.value(
        value: AppConfig.fromValues(
          mapTileUrl: 'https://tiles.invalid/{z}/{x}/{y}.png',
        ),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProposalPointMap(
                municipalityId: 'tuglie',
                coordinates: point,
                onConfirmed: onConfirmed,
                tileProvider: tiles,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(LocalProposalTiles.bytes),
        tester.element(find.byType(ProposalPointMap)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'no implicit pin; tap moves, accessible controls pan, keyboard confirms',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final points = <ProposalCoordinates>[];
      await pumpMap(
        tester,
        tiles: LocalProposalTiles(),
        onConfirmed: points.add,
      );
      expect(find.byType(MarkerLayer), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Usa questo punto'),
            )
            .onPressed,
        isNull,
      );
      final map = find.byType(FlutterMap);
      await tester.tapAt(tester.getCenter(map));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(MarkerLayer), findsOneWidget);
      await tapProposal(tester, find.text('Usa questo punto'));
      expect(points, hasLength(1));
      await tester.tapAt(tester.getCenter(map) + const Offset(25, 20));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tapProposal(tester, find.text('Usa questo punto'));
      expect(points.last, isNot(points.first));
      await tapProposal(tester, find.byTooltip('Sposta mappa a nord'));
      await tapProposal(tester, find.text('Seleziona il centro'));
      // Focus the actual Material button and activate it with Enter.
      Focus.of(tester.element(find.text('Usa questo punto'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(points, hasLength(3));
      expect(points.last.latitude, greaterThan(points.first.latitude));
      expect(
        tester.getSemantics(find.text('Seleziona il centro')).label,
        contains('Seleziona il centro'),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'returning to evicted tiles blocks selection and confirmation until the new images load',
    (tester) async {
      final tiles = _ReloadingTiles();
      final points = <ProposalCoordinates>[];
      await pumpMap(tester, tiles: tiles, onConfirmed: points.add);
      final map = find.byType(FlutterMap);
      final controller = tester.widget<FlutterMap>(map).mapController!;
      final original = controller.camera.center;
      final zoom = controller.camera.zoom;
      final selectCenter = find.widgetWithText(
        OutlinedButton,
        'Seleziona il centro',
      );
      final confirm = find.widgetWithText(FilledButton, 'Usa questo punto');
      await confirmProposalCenter(tester);
      expect(points, hasLength(1));
      final previouslyEnabledConfirm = tester
          .widget<FilledButton>(confirm)
          .onPressed!;
      // Load another zone and allow flutter_map to evict the original tiles.
      controller.move(const LatLng(41, 19), zoom);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      tiles.hold = true;
      controller.move(original, zoom);
      await tester.pumpAndSettle();
      expect(
        tiles.pending,
        isNotEmpty,
        reason: 'Returning must request new instances of the evicted tiles.',
      );
      expect(tester.widget<OutlinedButton>(selectCenter).onPressed, isNull);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      previouslyEnabledConfirm();
      expect(
        points,
        hasLength(1),
        reason:
            'An action queued before the tile was evicted must also be rejected.',
      );
      await tester.tapAt(tester.getCenter(map) + const Offset(25, 20));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .single
            .point,
        original,
      );
      expect(points, hasLength(1));
      // Actual image completion must enable the same controls again.
      await tester.runAsync(tiles.finishLoading);
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(selectCenter).onPressed, isNotNull);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tapProposal(tester, find.text('Usa questo punto'));
      expect(points, hasLength(2));
      expect(points.last, points.first);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed tiles block new selection and preserve confirmed coordinates',
    (tester) async {
      final pin = ProposalCoordinates(latitude: 40.07, longitude: 18.09);
      final points = <ProposalCoordinates>[];
      final tiles = _FailedTiles();
      await pumpMap(tester, tiles: tiles, point: pin, onConfirmed: points.add);
      expect(find.textContaining('Mappa non disponibile.'), findsOneWidget);
      expect(find.textContaining('Punto confermato:'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Seleziona il centro'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Usa questo punto'),
            )
            .onPressed,
        isNull,
      );
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(points, isEmpty);
      expect(find.byType(MarkerLayer), findsOneWidget);
      tiles.fail = false;
      await tapProposal(tester, find.text('Ricarica mappa'));
      await tapProposal(tester, find.text('Seleziona il centro'));
      await tapProposal(tester, find.text('Usa questo punto'));
      expect(points.single, pin);
      expect(find.textContaining('Mappa non disponibile.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
