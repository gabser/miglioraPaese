import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

void main() {
  test(
    'limits use trimmed Unicode code points including emoji, ZWJ and combining marks',
    () {
      for (final limit in [120, 1000, 20, 200]) {
        for (final length in [limit - 1, limit]) {
          final text = '👩\u200d🌳${List.filled(length - 3, '😀').join()}';
          expect(ProposalLimits.length('  $text  '), length);
          expect(ProposalLimits.text('  $text  ', limit), text);
        }
        expect(
          () => ProposalLimits.text(List.filled(limit + 1, '😀').join(), limit),
          throwsFormatException,
        );
      }
      expect(ProposalLimits.text(' a\u0301 ', 2), 'a\u0301');
      expect(() => ProposalLimits.text('\ud800', 120), throwsFormatException);
      expect(
        () => ProposalLimits.text('Via\u0000Roma', 120),
        throwsFormatException,
      );
    },
  );

  test(
    'place roundtrip distinguishes legacy absence, municipality and optional references',
    () {
      expect(ProposalLocation.fromJson(null), isNull);
      expect(
        ProposalLocation.fromJson({'kind': 'municipality'}),
        const ProposalLocation.municipality(),
      );
      final place = ProposalLocation.specific(
        label: ' Via Milano ',
        civic: ' 12/A ',
        reference: ' Ingresso nord ',
      );
      expect(place.toJson(), {
        'kind': 'specific',
        'label': 'Via Milano',
        'civic': '12/A',
        'reference': 'Ingresso nord',
      });
      expect(ProposalLocation.fromJson(place.toJson()), place);
      expect(place.displayLabel, 'Via Milano, 12/A');
      expect(ProposalLocation.specific(label: 'Parco', civic: ' ').toJson(), {
        'kind': 'specific',
        'label': 'Parco',
      });
    },
  );

  test(
    'malformed present place fails closed instead of becoming legacy absence',
    () {
      for (final value in [
        false,
        [],
        'Via Roma',
        {},
        {'kind': 'unknown'},
        {'kind': 'municipality', 'label': 'Hidden'},
        {'kind': 'specific'},
        {'kind': 'specific', 'label': ''},
        {'kind': 'specific', 'label': 1},
        {'kind': 'specific', 'label': 'Parco', 'civic': null},
        {
          'kind': 'specific',
          'label': 'Parco',
          'coordinates': [1, 2],
        },
        {'kind': 'specific', 'label': List.filled(121, '😀').join()},
      ]) {
        expect(
          () => ProposalLocation.fromJson(value),
          throwsFormatException,
          reason: '$value',
        );
      }
    },
  );

  test(
    'mock accepts same titles with separate places and preserves location on votes and promotion',
    () async {
      final store = CivicLoopStore(currentUserId: 'place-test');
      final repo = MockNextProblemsRepository(
        currentUserId: 'place-test',
        store: store,
      );
      final first = await repo.submitSuggestedProblem(
        municipalityId: 'comune:Pincara',
        title: ' Alberi ',
        description: ' Potatura ',
        category: ProblemKey.green,
        location: ProposalLocation.specific(label: 'Via Milano'),
      );
      final second = await repo.submitSuggestedProblem(
        municipalityId: 'comune:Pincara',
        title: 'Alberi',
        description: 'Potatura',
        category: ProblemKey.green,
        location: const ProposalLocation.municipality(),
      );
      expect(first.id, isNot(second.id));
      expect(first.title, 'Alberi');
      final voted = await repo.voteSuggestedProblem(
        municipalityId: 'comune:Pincara',
        problemId: first.id,
        vote: VoteChoice.up,
      );
      expect(voted.location, first.location);
      expect(voted.location!.displayLabel, 'Via Milano');
      expect(
        store.promotedProblems('comune:Pincara').single.zoneName,
        'Via Milano',
      );
    },
  );
}
