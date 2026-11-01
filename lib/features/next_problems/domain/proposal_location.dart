enum ProposalLocationKind { specific, municipality }

abstract final class ProposalLimits {
  static const title = 120;
  static const description = 1000;
  static const label = 120;
  static const civic = 20;
  static const reference = 200;

  static int length(String text) => text.trim().runes.length;

  static String text(String raw, int limit) {
    final value = raw.trim();
    if (value.isEmpty ||
        value.contains('\u0000') ||
        value.runes.any((rune) => rune >= 0xD800 && rune <= 0xDFFF) ||
        length(value) > limit) {
      throw const FormatException('Testo mancante, non valido o troppo lungo.');
    }
    return value;
  }
}

/// A complete, finite pair; transport validation never coerces strings.
class ProposalCoordinates {
  factory ProposalCoordinates({
    required double latitude,
    required double longitude,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Coordinate non valide.');
    }
    return ProposalCoordinates._(latitude, longitude);
  }
  const ProposalCoordinates._(this.latitude, this.longitude);
  final double latitude, longitude;
  Map<String, Object> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
  static ProposalCoordinates fromJson(Object? raw) {
    if (raw is! Map ||
        raw.length != 2 ||
        raw['latitude'] is! num ||
        raw['longitude'] is! num) {
      throw const FormatException('Coordinate non valide.');
    }
    return ProposalCoordinates(
      latitude: (raw['latitude'] as num).toDouble(),
      longitude: (raw['longitude'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProposalCoordinates &&
      latitude == other.latitude &&
      longitude == other.longitude;
  @override
  int get hashCode => Object.hash(latitude, longitude);
}

class ProposalLocation {
  const ProposalLocation.municipality()
    : kind = ProposalLocationKind.municipality,
      label = null,
      civic = null,
      reference = null,
      coordinates = null;

  const ProposalLocation._(
    this.label,
    this.civic,
    this.reference,
    this.coordinates,
  ) : kind = ProposalLocationKind.specific;

  factory ProposalLocation.specific({
    String? label,
    String? civic,
    String? reference,
    ProposalCoordinates? coordinates,
  }) {
    String? optional(String? value, int limit) =>
        value == null || value.trim().isEmpty
        ? null
        : ProposalLimits.text(value, limit);
    final name = optional(label, ProposalLimits.label);
    if (name == null && coordinates == null) {
      throw const FormatException('Scegli un punto o indica il luogo.');
    }
    return ProposalLocation._(
      name,
      optional(civic, ProposalLimits.civic),
      optional(reference, ProposalLimits.reference),
      coordinates,
    );
  }

  final ProposalLocationKind kind;
  final String? label, civic, reference;
  final ProposalCoordinates? coordinates;

  String get displayLabel => kind == ProposalLocationKind.municipality
      ? 'Intero Comune'
      : [label ?? 'Punto sulla mappa', civic].whereType<String>().join(', ');

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (label != null) 'label': label,
    if (civic != null) 'civic': civic,
    if (reference != null) 'reference': reference,
    if (coordinates != null) 'coordinates': coordinates!.toJson(),
  };

  static ProposalLocation? fromJson(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Luogo non valido.');
    }
    if (value['kind'] == 'municipality' && value.length == 1) {
      return const ProposalLocation.municipality();
    }
    if (value['kind'] != 'specific' ||
        value.keys.any(
          (key) => ![
            'kind',
            'label',
            'civic',
            'reference',
            'coordinates',
          ].contains(key),
        ) ||
        [
          'label',
          'civic',
          'reference',
        ].any((key) => value.containsKey(key) && value[key] is! String)) {
      throw const FormatException('Luogo non valido.');
    }
    return ProposalLocation.specific(
      label: value['label'] as String?,
      civic: value['civic'] as String?,
      reference: value['reference'] as String?,
      coordinates: value.containsKey('coordinates')
          ? ProposalCoordinates.fromJson(value['coordinates'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProposalLocation &&
      kind == other.kind &&
      label == other.label &&
      civic == other.civic &&
      reference == other.reference &&
      coordinates == other.coordinates;
  @override
  int get hashCode => Object.hash(kind, label, civic, reference, coordinates);
}
