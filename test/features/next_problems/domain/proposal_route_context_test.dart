import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';

void main() {
  test('an explicit URL wins over prefs and canonicalizes known aliases', () {
    final context = ProposalRouteContext.resolve(
      Uri(
        path: '/suggest-problem',
        queryParameters: {'municipality': ' COMUNE: Castel   Bolognese '},
      ),
      preference: 'comune:Bologna',
    );
    expect(context.municipalityId, 'castel-bolognese');
    expect(context.invalid, false);
  });

  test('invalid explicit values never inherit a valid preference', () {
    for (final value in [
      '',
      ' ',
      'unknown',
      'comune:',
      'comune:x',
      'comune:../Roma',
      'comune:Bo\u0000logna',
      'comune:A?x',
      'comune:%42ologna',
      'comune:Regione:Comune',
      'comune:\ud800x',
      'comune:${'A' * 121}',
    ]) {
      final context = ProposalRouteContext.resolve(
        Uri(path: '/suggest-problem', queryParameters: {'municipality': value}),
        preference: 'comune:Bologna',
      );
      expect(context.invalid, true, reason: value);
      expect(context.municipalityId, isNull, reason: value);
    }
    final duplicates = ProposalRouteContext.resolve(
      Uri.parse(
        '/next-problems?municipality=bologna&municipality=castel-bolognese',
      ),
      preference: 'comune:Bologna',
    );
    expect(duplicates.invalid, true);
  });

  test(
    'missing URL context uses a valid preference without a demo default',
    () {
      final uri = Uri.parse('/next-problems');
      expect(
        ProposalRouteContext.resolve(
          uri,
          preference: 'comune:Bologna',
        ).municipalityId,
        'bologna',
      );
      expect(ProposalRouteContext.resolve(uri).municipalityId, isNull);
      expect(ProposalRouteContext.resolve(uri).invalid, false);
      expect(
        ProposalRouteContext.resolve(uri, preference: 'unknown').invalid,
        true,
      );
    },
  );

  test('custom municipality names round-trip as one encoded query value', () {
    const id = "comune:Castel Sant'Elia";
    final location = ProposalRouteContext.location('/suggest-problem', id);
    final context = ProposalRouteContext.resolve(Uri.parse(location));
    expect(context.municipalityId, "comune:castel sant'elia");
    expect(
      ProposalRouteContext.location('/next-problems', context.municipalityId),
      contains('municipality='),
    );
    expect(
      () => ProposalRouteContext.location('/suggest-problem', 'unknown'),
      throwsFormatException,
    );
  });
}
