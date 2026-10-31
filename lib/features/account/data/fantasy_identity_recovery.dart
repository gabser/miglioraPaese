import 'dart:convert';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import 'account_session_store.dart';

/// Acknowledge durable guest commands before switching principal or linking.
/// Cached command replies are never installed as a new account's team.
class FantasyIdentityRecovery {
  FantasyIdentityRecovery({
    required this.client,
    required this.data,
    required this.guest,
    required this.account,
    required this.environment,
  });
  final ApiClient client;
  final LocalDataStore data;
  final ProposalSessionStore guest;
  final AccountSessionStore account;
  final String environment;
  Future<void> recover() async {
    for (final key in data.keysWithPrefix('fantasy-receipt:')) {
      final encodedScope = key.substring('fantasy-receipt:'.length);
      final league = encodedScope.endsWith('/league-creation');
      final rawScope = jsonDecode(
        league
            ? encodedScope.substring(
                0,
                encodedScope.length - '/league-creation'.length,
              )
            : encodedScope,
      );
      if (rawScope is! List ||
          rawScope.length != 4 ||
          rawScope.any((v) => v is! String))
        throw const LocalDataCorruptException();
      if (rawScope[0] != environment) continue;
      final stored = data.read(key);
      if (stored is! String) throw const LocalDataCorruptException();
      final body = jsonDecode(stored);
      if (body is! Map<String, dynamic> || body['idempotencyKey'] is! String)
        throw const LocalDataCorruptException();
      final guestLease = await guest.active();
      final path = ['v1', 'fantasy', 'municipalities', rawScope[1] as String];
      Map<String, String> headers = guestLease.headers;
      ProposalSessionLease? accountLease;
      try {
        final team = await client.getJson([...path, 'team'], headers: headers);
        guest.checkLease(guestLease);
        if (team is! Map ||
            team['seasonId'] != rawScope[2] ||
            team['sessionScope'] != rawScope[3])
          throw const LocalDataResetException();
      } on ApiException catch (error) {
        if (error.code != 'team_not_found' || !account.hasCredentials) rethrow;
        accountLease = await account.active();
        headers = accountLease.headers;
        final season = await client.getJson([
          ...path,
          'season',
        ], headers: headers);
        account.checkLease(accountLease);
        if (season is! Map ||
            season['season'] is! Map ||
            (season['season'] as Map)['id'] != rawScope[2])
          throw const LocalDataResetException();
      }
      final response = await client.postJson(
        [
          ...path,
          ...league ? ['leagues'] : ['transfers', 'confirmation'],
        ],
        body: body.cast<String, Object?>(),
        headers: headers,
      );
      guest.checkLease(guestLease);
      if (accountLease != null) account.checkLease(accountLease);
      if (response is! Map ||
          response['seasonId'] != rawScope[2] ||
          (!league && response['sessionScope'] != rawScope[3]))
        throw ApiException.invalidPayload(
          'Il recupero del comando ospite non è confermato.',
        );
      await data.mutate<void>(key, (current) {
        guest.checkLease(guestLease);
        if (accountLease != null) account.checkLease(accountLease);
        if (current != stored) throw const LocalDataResetException();
        return const LocalDataMutation(null, null);
      }, expectedEpoch: guestLease.epoch);
    }
  }
}
