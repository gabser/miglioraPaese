import 'package:flutter_test/flutter_test.dart';

import 'package:fanta_comune/core/models/municipality_catalog.dart';

void main() {
  test('maps only explicit local municipality IDs to API IDs', () {
    expect(MunicipalityCatalog.apiIdFor('comune:Bologna'), 'bologna');
    expect(
      MunicipalityCatalog.apiIdFor('comune:Castel Bolognese'),
      'castel-bolognese',
    );
    expect(MunicipalityCatalog.apiIdFor('bologna'), 'bologna');
    expect(MunicipalityCatalog.apiIdFor('comune:Tuglie'), 'tuglie');
    expect(MunicipalityCatalog.apiIdFor('tuglie'), 'tuglie');
    expect(MunicipalityCatalog.apiIdFor('comune:Milano'), isNull);
    expect(MunicipalityCatalog.apiIdFor('demo'), isNull);
  });

  test('renders API municipality IDs with their display name', () {
    expect(MunicipalityCatalog.displayNameFromId('bologna'), 'Bologna');
    expect(
      MunicipalityCatalog.displayNameFromId('castel-bolognese'),
      'Castel Bolognese',
    );
    expect(MunicipalityCatalog.displayNameFromId('tuglie'), 'Tuglie');
  });
}
