enum MunicipalityActivationState { active, collectingSignals, newMunicipality }

class MunicipalityCatalog {
  const MunicipalityCatalog._();

  static const _apiIdsByLocalId = <String, String>{
    'comune:Bologna': 'bologna',
    'comune:Castel Bolognese': 'castel-bolognese',
  };

  static const _displayNamesByApiId = <String, String>{
    'bologna': 'Bologna',
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
    return name.isEmpty ? 'Comune' : name;
  }

  static String? apiIdFor(String municipalityId) {
    if (_displayNamesByApiId.containsKey(municipalityId)) {
      return municipalityId;
    }
    return _apiIdsByLocalId[municipalityId];
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
