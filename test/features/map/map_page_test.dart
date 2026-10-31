import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/map/data/map_places_repository.dart';
import 'package:fanta_comune/features/map/domain/map_place.dart';
import 'package:fanta_comune/features/map/presentation/tuglie_map_page.dart';

class _LocalTileProvider extends TileProvider {
  _LocalTileProvider();
  static final bytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP49P3XfwAJpQPjiokzCAAAAABJRU5ErkJggg==',
    ),
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(bytes);
}

class _RecoveringRepository implements MapPlacesRepository {
  int calls = 0;

  @override
  Future<MapPlacesSnapshot> load(String municipalityId) async {
    calls++;
    if (calls == 1) throw StateError('campione non disponibile');
    return _OnePlaceRepository().load(municipalityId);
  }
}

class _EmptyRepository implements MapPlacesRepository {
  @override
  Future<MapPlacesSnapshot> load(String municipalityId) async =>
      const MapPlacesSnapshot(places: [], boundary: []);
}

class _SnapshotRepository implements MapPlacesRepository {
  _SnapshotRepository(this.snapshot);
  final MapPlacesSnapshot snapshot;

  @override
  Future<MapPlacesSnapshot> load(String municipalityId) async => snapshot;
}

class _OnePlaceRepository implements MapPlacesRepository {
  @override
  Future<MapPlacesSnapshot> load(String municipalityId) async =>
      MapPlacesSnapshot(
        places: [
          MapPlace.fromGeoJson({
            'id': 'osm:node/123',
            'properties': {
              'municipalityId': 'tuglie',
              'name': 'Municipio di Tuglie',
              'category': 'townhall',
              'source_url': 'https://www.openstreetmap.org/node/123',
              'quality_note': 'Da verificare',
              'coordinate_method': 'node_lon_lat',
              'content_links': [],
            },
            'geometry': {
              'coordinates': [18.1, 40.07],
            },
          }),
        ],
        boundary: const [],
      );
}

class _TwoPlaceRepository implements MapPlacesRepository {
  @override
  Future<MapPlacesSnapshot> load(String municipalityId) async {
    final first = await _OnePlaceRepository().load(municipalityId);
    return MapPlacesSnapshot(
      places: [
        ...first.places,
        MapPlace.fromGeoJson({
          'id': 'osm:node/124',
          'properties': {
            'municipalityId': 'tuglie',
            'name': 'Parco di prova',
            'category': 'park',
            'source_url': 'https://www.openstreetmap.org/node/124',
            'quality_note': 'Da verificare',
            'coordinate_method': 'node_lon_lat',
            'content_links': [],
          },
          'geometry': {
            'coordinates': [18.101, 40.071],
          },
        }),
      ],
      boundary: const [],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('list and marker open the same detail without tile network', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'municipality_id': 'comune:Tuglie',
    });
    final prefs = await AppPrefs.init();
    final snapshot = await AssetMapPlacesRepository(
      bundle: rootBundle,
    ).load('tuglie');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppConfig>.value(
            value: AppConfig.fromValues(tuglieMapEnabled: true),
          ),
          ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        ],
        child: MaterialApp(
          home: TuglieMapPage(
            municipalityId: 'tuglie',
            repository: _SnapshotRepository(snapshot),
            tileProvider: _LocalTileProvider(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.minZoom, 12);
    expect(map.options.maxZoom, 19);
    final initialFit = map.options.initialCameraFit;
    expect(initialFit, isA<FitBounds>());
    final bounds = (initialFit! as FitBounds).bounds;
    expect(
      snapshot.places.every((place) => bounds.contains(place.position)),
      isTrue,
    );
    final markerContext = tester.element(find.byType(MarkerLayer));
    final initialCamera = MapCamera.of(markerContext);
    await tester.tap(find.byTooltip('Intero Comune'));
    await tester.pump();
    final municipalityCamera = MapCamera.of(markerContext);
    expect(municipalityCamera.zoom, lessThan(initialCamera.zoom));
    expect(
      snapshot.boundary.every(
        (point) => municipalityCamera.visibleBounds.contains(point),
      ),
      isTrue,
    );
    await tester.tap(find.byTooltip('Ripristina vista'));
    await tester.pump();
    expect(MapCamera.of(markerContext).zoom, closeTo(initialCamera.zoom, 0.01));
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(9),
    );
    await tester.tap(find.byTooltip('Mostra confine'));
    await tester.pump();
    expect(
      tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons,
      hasLength(1),
    );
    await tester.tap(find.byTooltip('Nascondi confine'));
    await tester.pump();
    expect(find.byType(PolygonLayer), findsNothing);
    final row = find.text('Municipio di Tuglie');
    await tester.tap(row.first);
    await tester.pump();
    expect(find.text('Nessun contenuto collegato'), findsOneWidget);
    expect(find.text('Categoria: Municipio'), findsOneWidget);
    expect(
      find.text('Fonte: OpenStreetMap · osm:way/381917183'),
      findsOneWidget,
    );
    expect(
      find.text('Posizione: centroide della superficie OSM'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Ingresso, accesso pubblico e precisione'),
      findsOneWidget,
    );
    expect(find.text('Apri fonte OSM'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Chiudi dettaglio'));
    await tester.pump();
    await tester.tap(find.byTooltip('Chiudi dettaglio'));
    await tester.pump();
    expect(find.text('Nessun contenuto collegato'), findsNothing);
    await tester.tap(find.byTooltip('Municipio di Tuglie'));
    await tester.pump();
    expect(find.text('Nessun contenuto collegato'), findsOneWidget);
    expect(
      find.text('Fonte: OpenStreetMap · osm:way/381917183'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('marker-sample:tuglie:way/381917183')),
      findsOneWidget,
    );
    expect(find.textContaining('© OpenStreetMap contributors'), findsOneWidget);
    await prefs.setMunicipalityId('comune:Bologna');
    await tester.pump();
    await tester.pump();
    expect(
      find.textContaining('non corrisponde al Comune selezionato'),
      findsOneWidget,
    );
    expect(find.text('Nessun contenuto collegato'), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
    await prefs.setMunicipalityId('comune:Tuglie');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nessun contenuto collegato'), findsNothing);
    prefs.dispose();
  });

  testWidgets('search can show no results while map data remains loaded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'municipality_id': 'comune:Tuglie',
    });
    final prefs = await AppPrefs.init();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppConfig>.value(
            value: AppConfig.fromValues(tuglieMapEnabled: true),
          ),
          ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        ],
        child: MaterialApp(
          home: TuglieMapPage(
            municipalityId: 'tuglie',
            repository: _TwoPlaceRepository(),
            tileProvider: _LocalTileProvider(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.byKey(const ValueKey('map-place-search')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('map-place-search')),
      'inesistente',
    );
    await tester.pump();
    expect(find.text('Nessun luogo corrisponde al filtro.'), findsOneWidget);
    expect(find.text('Luoghi reali · 2'), findsOneWidget);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      isEmpty,
    );
    await tester.enterText(find.byKey(const ValueKey('map-place-search')), '');
    await tester.pump();
    expect(find.text('Nessun luogo corrisponde al filtro.'), findsNothing);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(2),
    );
    await tester.tap(find.byKey(const ValueKey('map-category-filter')));
    await tester.pump(const Duration(milliseconds: 300));
    final parkOption = find.text('Parco').last;
    expect(parkOption, findsOneWidget);
    await tester.tap(parkOption);
    await tester.pump();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(1),
    );
    expect(
      find.byKey(const ValueKey('place-sample:tuglie:node/123')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('place-sample:tuglie:node/124')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('map-category-filter')));
    await tester.pump(const Duration(milliseconds: 300));
    final allOption = find.text('Tutte le categorie').last;
    expect(allOption, findsOneWidget);
    await tester.tap(allOption);
    await tester.pump();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(2),
    );
    expect(
      find.byKey(const ValueKey('place-sample:tuglie:node/123')),
      findsOneWidget,
    );
    prefs.dispose();
  });

  testWidgets('data error has a retry action', (tester) async {
    SharedPreferences.setMockInitialValues({
      'municipality_id': 'comune:Tuglie',
    });
    final prefs = await AppPrefs.init();
    final config = AppConfig.fromValues(tuglieMapEnabled: true);
    final repository = _RecoveringRepository();
    Widget app(Widget child) => MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: config),
        ChangeNotifierProvider<AppPrefs>.value(value: prefs),
      ],
      child: MaterialApp(home: child),
    );
    await tester.pumpWidget(
      app(
        TuglieMapPage(
          municipalityId: 'tuglie',
          repository: repository,
          tileProvider: _LocalTileProvider(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('I luoghi non sono disponibili.'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    await tester.tap(find.text('Riprova'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.calls, 2);
    expect(find.text('Luoghi reali · 1'), findsOneWidget);
    prefs.dispose();
  });

  testWidgets('empty data has its own message and no retry', (tester) async {
    SharedPreferences.setMockInitialValues({
      'municipality_id': 'comune:Tuglie',
    });
    final prefs = await AppPrefs.init();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppConfig>.value(
            value: AppConfig.fromValues(tuglieMapEnabled: true),
          ),
          ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        ],
        child: MaterialApp(
          home: TuglieMapPage(
            municipalityId: 'tuglie',
            repository: _EmptyRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('Nessun luogo disponibile per questo Comune.'),
      findsOneWidget,
    );
    expect(find.text('Riprova'), findsNothing);
    prefs.dispose();
  });

  testWidgets('map controls, mouse drag and wheel change the camera', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'municipality_id': 'comune:Tuglie',
    });
    final prefs = await AppPrefs.init();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppConfig>.value(
            value: AppConfig.fromValues(tuglieMapEnabled: true),
          ),
          ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        ],
        child: MaterialApp(
          home: TuglieMapPage(
            municipalityId: 'tuglie',
            repository: _OnePlaceRepository(),
            tileProvider: _LocalTileProvider(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final markerContext = tester.element(find.byType(MarkerLayer));
    final initial = MapCamera.of(markerContext);
    await tester.tap(find.byTooltip('Zoom avanti'));
    await tester.pump();
    expect(MapCamera.of(markerContext).zoom, closeTo(initial.zoom + 1, 0.01));
    await tester.tap(find.byTooltip('Zoom indietro'));
    await tester.pump();
    expect(MapCamera.of(markerContext).zoom, closeTo(initial.zoom, 0.01));

    await tester.dragFrom(
      const Offset(100, 150),
      const Offset(80, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    final dragged = MapCamera.of(markerContext);
    expect(dragged.center, isNot(initial.center));
    expect(dragged.rotation, 0);

    await tester.sendEventToBinding(
      const PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: Offset(100, 150),
        scrollDelta: Offset(0, -120),
      ),
    );
    await tester.pump();
    expect(MapCamera.of(markerContext).zoom, greaterThan(dragged.zoom));
    prefs.dispose();
  });

  testWidgets('keyboard can open a place from the list', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'municipality_id': 'comune:Tuglie',
    });
    final prefs = await AppPrefs.init();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppConfig>.value(
            value: AppConfig.fromValues(tuglieMapEnabled: true),
          ),
          ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        ],
        child: MaterialApp(
          home: TuglieMapPage(
            municipalityId: 'tuglie',
            repository: _OnePlaceRepository(),
            tileProvider: _LocalTileProvider(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Apri Municipio di Tuglie'), findsOneWidget);
    final row = find.text('Municipio di Tuglie');
    expect(row, findsOneWidget);
    for (var i = 0; i < 20 && !Focus.of(tester.element(row)).hasFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(Focus.of(tester.element(row)).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Nessun contenuto collegato'), findsOneWidget);
    semantics.dispose();
    prefs.dispose();
  });

  for (final (viewport, textScale) in [
    (const Size(375, 812), 1.0),
    (const Size(375, 812), 2.0),
    (const Size(812, 375), 1.0),
    (const Size(812, 375), 2.0),
  ]) {
    testWidgets('attribution fits $viewport at ${textScale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'municipality_id': 'comune:Tuglie',
      });
      final prefs = await AppPrefs.init();
      addTearDown(prefs.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppConfig>.value(
              value: AppConfig.fromValues(
                tuglieMapEnabled: true,
                mapProviderAttribution: 'Tile locali di test',
                mapProviderAttributionUrl: 'https://example.org/tiles',
              ),
            ),
            ChangeNotifierProvider<AppPrefs>.value(value: prefs),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: TuglieMapPage(
                municipalityId: 'tuglie',
                repository: _OnePlaceRepository(),
                tileProvider: _LocalTileProvider(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      for (final label in [
        '© OpenStreetMap contributors · ODbL',
        'Segnala un problema cartografico',
        'Tile locali di test',
      ]) {
        final finder = find.text(label);
        expect(finder, findsOneWidget);
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(viewport.width));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(viewport.height));
        expect(finder.hitTestable(), findsOneWidget);
      }
      expect(find.text('Luoghi reali · 1'), findsOneWidget);
    });
  }
}
