import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';

/// A page's municipality is resolved once from its URL, never from a later
/// preference change. An invalid explicit query must not fall back to prefs.
class ProposalRouteContext {
  const ProposalRouteContext._(this.municipalityId, this.invalid);

  factory ProposalRouteContext.resolve(Uri uri, {String? preference}) {
    final values = uri.queryParametersAll['municipality'];
    if (values == null) return ProposalRouteContext.fromPreference(preference);
    if (values.length != 1) return const ProposalRouteContext._(null, true);
    final canonical = validate(values.single);
    return ProposalRouteContext._(canonical, canonical == null);
  }

  factory ProposalRouteContext.fromPreference(String? preference) {
    if (preference == null) return const ProposalRouteContext._(null, false);
    final canonical = validate(preference);
    return ProposalRouteContext._(canonical, canonical == null);
  }

  final String? municipalityId;
  final bool invalid;
  String get key => invalid ? 'invalid' : municipalityId ?? 'missing';

  static bool isProposalPath(String path) =>
      path == '/next-problems' ||
      path.startsWith('/next-problems/') ||
      path == '/suggest-problem' ||
      path == '/proposal-receipt' ||
      path.startsWith('/proposal-receipt/');

  static bool validProblemId(String? id) =>
      id != null &&
      id.trim().isNotEmpty &&
      id.runes.length <= 160 &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(id) &&
      !id.runes.any(
        (rune) => rune == 0xfffd || (rune >= 0xd800 && rune <= 0xdfff),
      );

  static String receiptLocation(String id, String municipalityId) =>
      _problemLocation('proposal-receipt', id, municipalityId);

  static String detailLocation(String id, String municipalityId) =>
      _problemLocation('next-problems', id, municipalityId);

  static String _problemLocation(
    String page,
    String id,
    String municipalityId,
  ) {
    final municipality = validate(municipalityId);
    if (!validProblemId(id) || municipality == null) {
      throw const FormatException('Collegamento alla proposta non valido.');
    }
    return Uri(
      pathSegments: ['', page, id],
      queryParameters: {'municipality': municipality},
    ).toString();
  }

  static String? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.runes.length > 127 ||
        RegExp(r'[\x00-\x1f\x7f/\\?#%]').hasMatch(trimmed) ||
        trimmed.runes.any(
          (rune) => rune == 0xfffd || (rune >= 0xd800 && rune <= 0xdfff),
        )) {
      return null;
    }
    final known = MunicipalityCatalog.apiIdFor(trimmed);
    if (known != null) return known;
    // Explicit demo is a legacy local selection, never an implicit default.
    if (trimmed == 'demo') return trimmed;
    if (!trimmed.toLowerCase().startsWith('comune:')) return null;
    final name = trimmed.substring(7).trim();
    if (name.runes.length < 2 || name.contains(':')) return null;
    return ProposalScope.canonicalMunicipality(trimmed);
  }

  static String location(String path, String? municipalityId) {
    final canonical = municipalityId == null ? null : validate(municipalityId);
    if (municipalityId != null && canonical == null) {
      throw const FormatException('Comune non valido nel collegamento.');
    }
    return Uri(
      path: path,
      queryParameters: canonical == null ? null : {'municipality': canonical},
    ).toString();
  }
}
