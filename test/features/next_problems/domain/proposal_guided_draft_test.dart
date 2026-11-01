import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_case_catalog.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_draft.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_draft_controller.dart';
import '../../../helpers/memory_local_backend.dart';

void main() {
  test(
    'v1 migration retains all raw text, place and revision as a custom case',
    () {
      final draft = ProposalDraft.fromJson({
        'version': 1,
        'revision': 17,
        'title': ' Titolo personale ',
        'description': ' Testo precedente ',
        'category': 'green',
        'locationKind': 'specific',
        'locationLabel': ' Via Roma ',
        'civic': '12/A',
        'reference': 'Ingresso',
      });
      expect(draft.caseIndex, -1);
      expect(draft.step, 0);
      expect(draft.titleCustomized && draft.descriptionCustomized, isTrue);
      expect(draft.customDescription, ' Testo precedente ');
      expect(draft.coordinates, isNull);
      final migrated = ProposalDraft.fromJson(draft.toJson());
      expect(migrated.toJson(), draft.toJson());
      expect(migrated.title, ' Titolo personale ');
      expect(migrated.location.displayLabel, 'Via Roma, 12/A');
      expect(migrated.revision, 17);
    },
  );

  test('catalog covers 13 categories and generates only supplied facts', () {
    expect(ProposalCaseCatalog.cases.keys.toSet(), ProblemKey.values.toSet());
    for (final category in ProblemKey.values) {
      expect(ProposalCaseCatalog.cases[category], hasLength(3));
      for (var index = 0; index < 3; index++) {
        final generated = ProposalCaseCatalog.generate(
          ProposalDraft(category: category, caseIndex: index),
        );
        expect(generated.title, ProposalCaseCatalog.cases[category]![index]);
        expect(generated.description, '${generated.title}.');
      }
    }
    final generated = ProposalCaseCatalog.generate(
      const ProposalDraft(
        category: ProblemKey.noise,
        caseIndex: 0,
        detail: 'Notte',
        locationKind: ProposalLocationKind.municipality,
      ),
    );
    expect(
      generated.description,
      'Musica alta. Momento: notte. Luogo: Intero Comune.',
    );
  });

  test(
    'step, choices, pin and per-field manual edits survive restart and scope isolation',
    () async {
      final backend = MemoryLocalBackend();
      var data = LocalDataStore(backend: backend);
      ProposalScope scope(String id) => ProposalScope.fromConfig(
        municipalityId: id,
        config: AppConfig.fromValues(),
        namespace: data.namespace,
      );
      var store = ProposalDraftStore(data);
      var controller = ProposalDraftController(
        store: store,
        scope: scope('bologna'),
      );
      final pin = ProposalCoordinates(latitude: 44.49, longitude: 11.34);
      controller.chooseCategory(ProblemKey.lighting);
      controller.chooseCase(0);
      controller.chooseDetail('3');
      controller.choosePin(pin);
      controller.goToStep(2);
      controller.regenerate();
      controller.edit(
        controller.draft.copyWith(
          title: 'Titolo modificato',
          titleCustomized: true,
        ),
      );
      expect(await controller.flush(), isTrue);
      controller.dispose();
      data.dispose();
      data = LocalDataStore(backend: backend);
      store = ProposalDraftStore(data);
      controller = ProposalDraftController(
        store: store,
        scope: scope('bologna'),
      );
      expect(controller.draft.step, 2);
      expect(controller.draft.coordinates, pin);
      expect(controller.draft.detail, '3');
      expect(controller.draft.title, 'Titolo modificato');
      controller.goToStep(0);
      controller.chooseCategory(ProblemKey.noise);
      expect(controller.draft.caseIndex, isNull);
      expect(controller.draft.detail, isNull);
      controller.chooseCase(1);
      controller.chooseDetail('Sera');
      controller.regenerate();
      expect(controller.draft.title, 'Titolo modificato');
      expect(
        controller.draft.description,
        contains('Rumori da lavori. Momento: sera.'),
      );
      controller.regenerate(force: true);
      expect(controller.draft.title, 'Rumori da lavori');
      expect(controller.draft.titleCustomized, isFalse);
      expect(store.load(scope('comune:Milano')), isNull);
      controller.chooseKind(ProposalLocationKind.municipality);
      expect(controller.draft.coordinates, isNull);
      controller.chooseKind(ProposalLocationKind.specific);
      expect(controller.draft.coordinates, isNull);
      controller.choosePin(pin);
      controller.choosePin(null);
      expect(controller.draft.coordinates, isNull);
      await controller.flush();
      controller.dispose();
    },
  );

  test(
    'coordinates validate and participate in equality and normalized payloads',
    () {
      final pin = ProposalCoordinates(latitude: 0, longitude: -180);
      final location = ProposalLocation.specific(coordinates: pin);
      expect(location.displayLabel, 'Punto sulla mappa');
      expect(ProposalLocation.fromJson(location.toJson()), location);
      expect(
        location,
        isNot(
          ProposalLocation.specific(
            coordinates: ProposalCoordinates(latitude: 1, longitude: -180),
          ),
        ),
      );
      for (final coordinates in [
        {'latitude': 1},
        {'longitude': 2},
        {'latitude': '1', 'longitude': 2},
        {'latitude': double.nan, 'longitude': 2},
        {'latitude': 1, 'longitude': double.infinity},
        {'latitude': 91, 'longitude': 2},
        {'latitude': 1, 'longitude': -181},
        {'latitude': 1, 'longitude': 2, 'extra': 3},
      ]) {
        expect(
          () => ProposalLocation.fromJson({
            'kind': 'specific',
            'coordinates': coordinates,
          }),
          throwsFormatException,
        );
      }
      expect(
        () => ProposalLocation.fromJson({
          'kind': 'municipality',
          'coordinates': pin.toJson(),
        }),
        throwsFormatException,
      );
    },
  );
}
