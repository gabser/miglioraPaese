import 'package:flutter/foundation.dart';
import 'package:fanta_comune/features/map/data/map_places_repository.dart';
import 'package:fanta_comune/features/map/domain/map_place.dart';

enum MapDataStatus { loading, ready, empty, error }

class MapPlacesController extends ChangeNotifier {
  MapPlacesController(this.repository);
  final MapPlacesRepository repository;
  int _request = 0;
  String? municipalityId;
  MapDataStatus status = MapDataStatus.empty;
  MapPlacesSnapshot? snapshot;
  String? selectedPlaceId;
  String? category;
  String query = '';

  List<MapPlace> get visiblePlaces =>
      snapshot?.places
          .where(
            (place) =>
                (category == null || place.category == category) &&
                (query.isEmpty || place.name.toLowerCase().contains(query)),
          )
          .toList(growable: false) ??
      [];
  MapPlace? get selectedPlace {
    for (final place in snapshot?.places ?? <MapPlace>[]) {
      if (place.placeId == selectedPlaceId) return place;
    }
    return null;
  }

  Future<void> load(String? id) async {
    final request = ++_request;
    municipalityId = id;
    snapshot = null;
    selectedPlaceId = null;
    category = null;
    query = '';
    status = MapDataStatus.loading;
    notifyListeners();
    try {
      final result = id == null
          ? const MapPlacesSnapshot(places: [], boundary: [])
          : await repository.load(id);
      if (request != _request) return;
      snapshot = result;
      status = result.places.isEmpty
          ? MapDataStatus.empty
          : MapDataStatus.ready;
    } catch (_) {
      if (request != _request) return;
      status = MapDataStatus.error;
    }
    notifyListeners();
  }

  void select(String? placeId) {
    selectedPlaceId =
        snapshot?.places.any((place) => place.placeId == placeId) == true
        ? placeId
        : null;
    notifyListeners();
  }

  void filter(String? value) {
    category = value;
    selectedPlaceId = null;
    notifyListeners();
  }

  void search(String value) {
    query = value.trim().toLowerCase();
    selectedPlaceId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    ++_request;
    super.dispose();
  }
}
