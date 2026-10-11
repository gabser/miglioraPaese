import 'dart:convert';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';

class ProposalScope {
  const ProposalScope({
    required this.municipalityId,
    required this.environment,
    required this.namespace,
  });
  factory ProposalScope.fromConfig({
    required String municipalityId,
    required AppConfig config,
    required String namespace,
  }) => ProposalScope(
    municipalityId: canonicalMunicipality(municipalityId),
    environment: environmentFor(config),
    namespace: namespace,
  );

  final String municipalityId;
  final String environment;
  final String namespace;
  String get key => jsonEncode([namespace, environment, municipalityId]);

  static String canonicalMunicipality(String id) {
    final trimmed = id.trim();
    final known = MunicipalityCatalog.apiIdFor(trimmed);
    if (known != null) return known;
    if (trimmed.toLowerCase().startsWith('comune:')) {
      final name = trimmed
          .substring(7)
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ');
      if (name.isEmpty) throw const FormatException('Comune mancante.');
      return 'comune:$name';
    }
    if (trimmed.isEmpty) throw const FormatException('Comune mancante.');
    return trimmed.toLowerCase();
  }

  static String environmentFor(AppConfig config) => jsonEncode([
    config.fantasyModeEnabled ? 'fantasy' : 'legacy',
    config.nextProblemsDataSource.name,
    config.apiBaseUrl.origin,
    config.apiBaseUrl.pathSegments.where((part) => part.isNotEmpty).toList(),
  ]);

  @override
  bool operator ==(Object other) => other is ProposalScope && key == other.key;
  @override
  int get hashCode => key.hashCode;
}
