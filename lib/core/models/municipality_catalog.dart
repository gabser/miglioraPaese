enum MunicipalityActivationState {
  active,
  collectingSignals,
  newMunicipality,
}

class MunicipalityCatalog {
  const MunicipalityCatalog._();

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
    if (!municipalityId.startsWith('comune:')) return municipalityId;
    final name = municipalityId.substring('comune:'.length).trim();
    return name.isEmpty ? 'Comune' : name;
  }

  static bool isActiveMunicipality(String municipalityId) {
    if (municipalityId == 'demo') return true;
    final normalized = displayNameFromId(municipalityId).toLowerCase();
    return activeCities.any((city) => city.toLowerCase() == normalized);
  }

  static MunicipalityActivationState activationStateFor(
    String municipalityId,
  ) {
    if (isActiveMunicipality(municipalityId)) {
      return MunicipalityActivationState.active;
    }
    return MunicipalityActivationState.newMunicipality;
  }
}
