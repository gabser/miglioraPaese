enum MunicipalityActivationState { active, collectingSignals, newMunicipality }

class MunicipalityCatalog {
  const MunicipalityCatalog._();

  static const _apiIdsByLocalId = <String, String>{
    'comune:Bologna': 'bologna',
    'comune:Tuglie': 'tuglie',
    'comune:Castel Bolognese': 'castel-bolognese',
  };

  static const _displayNamesByApiId = <String, String>{
    'bologna': 'Bologna',
    'tuglie': 'Tuglie',
    'castel-bolognese': 'Castel Bolognese',
  };

  static const activeCities = [
    'Milano',
    'Roma',
    'Torino',
    'Bologna',
    'Napoli',
    'Palermo',
    'Firenze',
    'Genova',
  ];

  static String idForCity(String city) => 'comune:${city.trim()}';

  static String displayNameFromId(String municipalityId) {
    if (municipalityId == 'demo') return 'Comune demo';
    final apiDisplayName = _displayNamesByApiId[municipalityId];
    if (apiDisplayName != null) return apiDisplayName;
    if (!municipalityId.startsWith('comune:')) return municipalityId;
    final name = municipalityId.substring('comune:'.length).trim();
    if (name.isEmpty) return 'Comune';
    for (final city in activeCities) {
      if (city.toLowerCase() == name.toLowerCase()) return city;
    }
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  static String? apiIdFor(String municipalityId) {
    final normalized = municipalityId
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'^comune:\s*'), 'comune:');
    if (_displayNamesByApiId.containsKey(normalized)) {
      return normalized;
    }
    for (final entry in _apiIdsByLocalId.entries) {
      if (entry.key.toLowerCase() == normalized) return entry.value;
    }
    return null;
  }

  static bool supportsApi(String municipalityId) =>
      apiIdFor(municipalityId) != null;

  static bool isActiveMunicipality(String municipalityId) {
    if (municipalityId == 'demo') return true;
    final normalized = displayNameFromId(municipalityId).toLowerCase();
    return activeCities.any((city) => city.toLowerCase() == normalized);
  }

  static MunicipalityActivationState activationStateFor(String municipalityId) {
    if (isActiveMunicipality(municipalityId)) {
      return MunicipalityActivationState.active;
    }
    return MunicipalityActivationState.newMunicipality;
  }
}
