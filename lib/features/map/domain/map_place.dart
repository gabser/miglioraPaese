import 'package:latlong2/latlong.dart';

enum PlaceContentKind { mission, proposal, problem }

class PlaceContentLink {
  const PlaceContentLink({required this.kind, required this.id});
  final PlaceContentKind kind;
  final String id;
}

class MapPlace {
  const MapPlace({
    required this.placeId,
    required this.osmId,
    required this.municipalityId,
    required this.name,
    required this.category,
    required this.position,
    required this.sourceUrl,
    required this.qualityNote,
    required this.coordinateMethod,
    required this.contentLinks,
  });

  /// Application identity is distinct from the source's OSM identity.
  final String placeId;
  final String osmId;
  final String municipalityId;
  final String name;
  final String category;
  final LatLng position;
  final Uri sourceUrl;
  final String qualityNote;
  final String coordinateMethod;
  final List<PlaceContentLink> contentLinks;

  static MapPlace fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>;
    final coordinates =
        (feature['geometry'] as Map<String, dynamic>)['coordinates'] as List;
    if (coordinates.length != 2) {
      throw const FormatException('Coordinate non valide');
    }
    final longitude = (coordinates[0] as num).toDouble();
    final latitude = (coordinates[1] as num).toDouble();
    if (!longitude.isFinite ||
        !latitude.isFinite ||
        longitude.abs() > 180 ||
        latitude.abs() > 90) {
      throw const FormatException('Coordinate non valide');
    }
    final osmId = feature['id'] as String;
    final links = (properties['content_links'] as List)
        .map((raw) {
          final value = raw as Map<String, dynamic>;
          return PlaceContentLink(
            kind: PlaceContentKind.values.byName(value['kind'] as String),
            id: value['id'] as String,
          );
        })
        .toList(growable: false);
    return MapPlace(
      placeId: 'sample:tuglie:${osmId.substring(4)}',
      osmId: osmId,
      municipalityId: properties['municipalityId'] as String,
      name: properties['name'] as String,
      category: properties['category'] as String,
      position: LatLng(latitude, longitude),
      sourceUrl: Uri.parse(properties['source_url'] as String),
      qualityNote: properties['quality_note'] as String,
      coordinateMethod: properties['coordinate_method'] as String,
      contentLinks: links,
    );
  }
}
