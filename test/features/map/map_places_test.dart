import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/features/map/data/map_places_repository.dart';
import 'package:fanta_comune/features/map/domain/map_place.dart';
import 'package:fanta_comune/features/map/logic/map_places_controller.dart';

class _FakeRepository implements MapPlacesRepository {
  final requests = <String, Completer<MapPlacesSnapshot>>{};

  @override
  Future<MapPlacesSnapshot> load(String municipalityId) =>
      (requests[municipalityId] = Completer<MapPlacesSnapshot>()).future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GeoJSON longitude/latitude becomes LatLng latitude/longitude', () {
    final place = MapPlace.fromGeoJson({
      'id': 'osm:node/123',
      'properties': {
        'municipalityId': 'tuglie',
        'name': 'Test',
        'category': 'park',
        'source_url': 'https://www.openstreetmap.org/node/123',
        'quality_note': 'Da verificare',
        'coordinate_method': 'node_lon_lat',
        'content_links': [],
      },
      'geometry': {
        'coordinates': [18.1, 40.07],
      },
    });
    expect(place.position.latitude, 40.07);
    expect(place.position.longitude, 18.1);
    expect(place.placeId, isNot(place.osmId));
  });

  test(
    'asset repository reads nine places and boundary without network',
    () async {
      final repository = AssetMapPlacesRepository(bundle: rootBundle);
      final snapshot = await repository.load('tuglie');
      expect(snapshot.places, hasLength(9));
      expect(snapshot.boundary, hasLength(322));
      expect(
        snapshot.places.every((place) => place.contentLinks.isEmpty),
        true,
      );
    },
  );

  test('selection and municipality change discard stale response', () async {
    final repository = _FakeRepository();
    final controller = MapPlacesController(repository);
    final first = controller.load('tuglie');
    final place = MapPlace.fromGeoJson({
      'id': 'osm:node/123',
      'properties': {
        'municipalityId': 'tuglie',
        'name': 'Test',
        'category': 'park',
        'source_url': 'https://www.openstreetmap.org/node/123',
        'quality_note': 'Da verificare',
        'coordinate_method': 'node_lon_lat',
        'content_links': [],
      },
      'geometry': {
        'coordinates': [18.1, 40.07],
      },
    });
    repository.requests['tuglie']!.complete(
      MapPlacesSnapshot(places: [place], boundary: []),
    );
    await first;
    controller.select(place.placeId);
    expect(controller.selectedPlace?.name, 'Test');
    final stale = controller.load('tuglie');
    final other = controller.load('bologna');
    expect(controller.selectedPlace, isNull);
    repository.requests['bologna']!.complete(
      const MapPlacesSnapshot(places: [], boundary: []),
    );
    await other;
    repository.requests['tuglie']!.complete(
      MapPlacesSnapshot(places: [place], boundary: []),
    );
    await stale;
    expect(controller.status, MapDataStatus.empty);
    expect(controller.snapshot?.places, isEmpty);
    controller.dispose();
  });

  test('data error and filter empty are separate states', () async {
    final repository = _FakeRepository();
    final controller = MapPlacesController(repository);
    final loading = controller.load('tuglie');
    expect(controller.status, MapDataStatus.loading);
    repository.requests['tuglie']!.completeError(StateError('offline'));
    await loading;
    expect(controller.status, MapDataStatus.error);
    final recovery = controller.load('tuglie');
    final place = MapPlace.fromGeoJson({
      'id': 'osm:node/123',
      'properties': {
        'municipalityId': 'tuglie',
        'name': 'Test',
        'category': 'park',
        'source_url': 'https://www.openstreetmap.org/node/123',
        'quality_note': 'Da verificare',
        'coordinate_method': 'node_lon_lat',
        'content_links': [],
      },
      'geometry': {
        'coordinates': [18.1, 40.07],
      },
    });
    repository.requests['tuglie']!.complete(
      MapPlacesSnapshot(places: [place], boundary: []),
    );
    await recovery;
    expect(controller.status, MapDataStatus.ready);
    controller.search('inesistente');
    expect(controller.visiblePlaces, isEmpty);
    expect(controller.status, MapDataStatus.ready);
    controller.search('');
    expect(controller.visiblePlaces, hasLength(1));
    controller.filter('townhall');
    expect(controller.visiblePlaces, isEmpty);
    controller.filter('park');
    expect(controller.visiblePlaces, hasLength(1));
    controller.filter(null);
    expect(controller.visiblePlaces, hasLength(1));
    controller.dispose();
  });
}
