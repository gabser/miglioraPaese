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

class ProposalLocation {
  const ProposalLocation.municipality()
    : kind = ProposalLocationKind.municipality,
      label = null,
      civic = null,
      reference = null;

  const ProposalLocation._(this.label, this.civic, this.reference)
    : kind = ProposalLocationKind.specific;

  factory ProposalLocation.specific({
    required String label,
    String? civic,
    String? reference,
  }) {
    String? optional(String? value, int limit) =>
        value == null || value.trim().isEmpty
        ? null
        : ProposalLimits.text(value, limit);
    return ProposalLocation._(
      ProposalLimits.text(label, ProposalLimits.label),
      optional(civic, ProposalLimits.civic),
      optional(reference, ProposalLimits.reference),
    );
  }

  final ProposalLocationKind kind;
  final String? label;
  final String? civic;
  final String? reference;

  String get displayLabel => kind == ProposalLocationKind.municipality
      ? 'Intero Comune'
      : [label, civic].whereType<String>().join(', ');

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (kind == ProposalLocationKind.specific) 'label': label,
    if (civic != null) 'civic': civic,
    if (reference != null) 'reference': reference,
  };

  static ProposalLocation? fromJson(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>)
      throw const FormatException('Luogo non valido.');
    if (value['kind'] == 'municipality' && value.length == 1)
      return const ProposalLocation.municipality();
    if (value['kind'] != 'specific' ||
        value['label'] is! String ||
        value.keys.any(
          (key) => !['kind', 'label', 'civic', 'reference'].contains(key),
        ) ||
        [
          'civic',
          'reference',
        ].any((key) => value.containsKey(key) && value[key] is! String)) {
      throw const FormatException('Luogo non valido.');
    }
    return ProposalLocation.specific(
      label: value['label'] as String,
      civic: value['civic'] as String?,
      reference: value['reference'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProposalLocation &&
      kind == other.kind &&
      label == other.label &&
      civic == other.civic &&
      reference == other.reference;
  @override
  int get hashCode => Object.hash(kind, label, civic, reference);
}
