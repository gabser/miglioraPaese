import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:fanta_comune/features/map/domain/map_place.dart';

abstract class MapPlacesRepository {
  Future<MapPlacesSnapshot> load(String municipalityId);
}

class MapPlacesSnapshot {
  const MapPlacesSnapshot({required this.places, required this.boundary});
  final List<MapPlace> places;
  final List<LatLng> boundary;
}

class AssetMapPlacesRepository implements MapPlacesRepository {
  const AssetMapPlacesRepository({this.bundle});
  final AssetBundle? bundle;

  @override
  Future<MapPlacesSnapshot> load(String municipalityId) async {
    if (municipalityId != 'tuglie') {
      return const MapPlacesSnapshot(places: [], boundary: []);
    }
    final raw = await Future.wait([
      (bundle ?? rootBundle).loadString('assets/map/tuglie/places.geojson'),
      (bundle ?? rootBundle).loadString('assets/map/tuglie/boundary.geojson'),
    ]);
    final placesJson = jsonDecode(raw[0]) as Map<String, dynamic>;
    final boundaryJson = jsonDecode(raw[1]) as Map<String, dynamic>;
    final places = (placesJson['features'] as List)
        .map((feature) => MapPlace.fromGeoJson(feature as Map<String, dynamic>))
        .where((place) => place.municipalityId == municipalityId)
        .toList(growable: false);
    final coordinates =
        (((boundaryJson['features'] as List).single
                    as Map<String, dynamic>)['geometry']
                as Map<String, dynamic>)['coordinates']
            as List;
    final ring = (coordinates.single as List)
        .map((point) {
          final values = point as List;
          return LatLng(
            (values[1] as num).toDouble(),
            (values[0] as num).toDouble(),
          );
        })
        .toList(growable: false);
    return MapPlacesSnapshot(places: places, boundary: ring);
  }
}
