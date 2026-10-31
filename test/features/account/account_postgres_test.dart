import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/account/data/account_repository.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:fanta_comune/features/account/data/authenticated_session_source.dart';
import 'package:fanta_comune/features/account/data/fantasy_identity_recovery.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import 'package:fanta_comune/features/fantasy/data/api_fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_repository.dart';
import '../../helpers/memory_local_backend.dart';
import '../../support/fantasy_backend.dart';

class LinkClient extends CookieClient {
  bool loseLinkReply = false;
  final linkBodies = <String>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await super.send(request);
    if (request.url.path.endsWith('/guest-link')) {
      linkBodies.add((request as http.Request).body);
      if (loseLinkReply) {
        loseLinkReply = false;
        await response.stream.drain<void>();
        throw http.ClientException('reply lost after linking');
      }
    }
    return response;
  }
}

class Device {
  Device(this.prefs, this.client) {
    guest = ProposalSessionStore(
      client: client,
      data: prefs.localData,
      environment: 'account-pg',
    );
    account = AccountSessionStore(
      client: client,
      data: prefs.localData,
      environment: 'account-pg',
    );
    sessions = AuthenticatedSessionSource(guest: guest, account: account);
    recovery = FantasyIdentityRecovery(
      client: client,
      data: prefs.localData,
      guest: guest,
      account: account,
      environment: 'account-pg',
    );
    repository = AccountRepository(
      client: client,
      sessions: account,
      guest: guest,
      environment: 'account-pg',
      beforeIdentityChange: recovery.recover,
    );
    fantasy = ApiFantasyRepository(
      client: client,
      prefs: prefs,
      environment: 'account-pg',
      municipalityId: 'tuglie',
      sessions: sessions,
    );
  }
  final AppPrefs prefs;
  final ApiClient client;
  late ProposalSessionStore guest;
  late AccountSessionStore account;
  late AuthenticatedSessionSource sessions;
  late FantasyIdentityRecovery recovery;
  late AccountRepository repository;
  late ApiFantasyRepository fantasy;
  Future<void> login(BackendFixture fixture, String email) async {
    final challenge = await repository.requestCode(email);
    await repository.verify(
      challengeId: challenge.id,
      code: await fixture.accountCode(email),
    );
  }

  void dispose() {
    sessions.dispose();
    account.dispose();
    prefs.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'PostgreSQL guest transfer reply loss, login/link retry, old receipt replay and second device revocation',
    () async {
      HttpOverrides.global = null;
      final fixture = BackendFixture();
      await fixture.start();
      addTearDown(fixture.stop);
      SharedPreferences.setMockInitialValues({});
      final shared = await SharedPreferences.getInstance();
      final transport = LinkClient();
      addTearDown(transport.close);
      final one = Device(
        AppPrefs(
          shared,
          dataStore: LocalDataStore(backend: MemoryLocalBackend()),
        ),
        ApiClient(baseUrl: Uri.parse(fixture.url), client: transport),
      );
      addTearDown(one.dispose);
      await one.prefs.setFantasyStateJson('demo-not-imported');
      var team = await one.fantasy.load();
      final quote = await one.fantasy.quoteTransfer(
        'parco-nord',
        'fontanelle-ovest',
        team.revision,
      );
      transport.loseTransferReply = true;
      await expectLater(
        one.fantasy.execute(
          TransferFantasyCard(
            'parco-nord',
            'fontanelle-ovest',
            0,
            quote: quote,
          ),
          expectedRevision: team.revision,
        ),
        throwsA(isA<ApiException>()),
      );
      final receiptKey = one.prefs.localData
          .keysWithPrefix('fantasy-receipt:')
          .single;
      final receipt = one.prefs.localData.read(receiptKey);
      expect(receipt, isA<String>());
      final originalScope =
          (jsonDecode(receiptKey.substring('fantasy-receipt:'.length)) as List)
              .last;
      await one.login(fixture, 'one@example.invalid');
      expect(one.prefs.localData.read(receiptKey), isNull);
      expect(transport.keys.toSet().length, 1);
      transport.loseLinkReply = true;
      await expectLater(
        one.repository.linkGuest(),
        throwsA(isA<ApiException>()),
      );
      expect(one.repository.hasPendingLink, isTrue);
      expect((await one.repository.linkGuest())!.linked, isTrue);
      expect(transport.linkBodies.toSet().length, 1);
      expect(one.repository.hasPendingLink, isFalse);
      team = await one.fantasy.load();
      expect(team.state.transfers.length, 1);
      expect(one.prefs.fantasyStateJson, 'demo-not-imported');
      expect(team.state.squadIds, contains('fontanelle-ovest'));
      // Simulate a durable old guest command surviving linking. The receipt is
      // acknowledged under its original scope and never installed as account state.
      await one.prefs.localData.mutate<void>(
        receiptKey,
        (_) => LocalDataMutation(receipt, null),
      );
      await one.recovery.recover();
      expect(one.prefs.localData.read(receiptKey), isNull);
      team = await one.fantasy.load();
      expect(team.state.transfers.length, 1);
      final secondTransport = CookieClient();
      addTearDown(secondTransport.close);
      final two = Device(
        AppPrefs(
          shared,
          dataStore: LocalDataStore(backend: MemoryLocalBackend()),
        ),
        ApiClient(baseUrl: Uri.parse(fixture.url), client: secondTransport),
      );
      addTearDown(two.dispose);
      await fixture.command('clock', '2026-10-08T00:01:01Z');
      await two.login(fixture, 'one@example.invalid');
      var other = await two.fantasy.load();
      expect(other.state.squadIds, team.state.squadIds);
      expect(other.state.transfers.length, 1);
      await two.repository.updatePseudonym('Custode');
      expect(two.account.current!.pseudonym, 'Custode');
      final devices = await two.repository.devices();
      expect(devices.length, 2);
      await two.repository.revokeDevice(
        devices.singleWhere((d) => !d.isCurrent),
      );
      await expectLater(one.account.active(), throwsA(isA<ApiException>()));
      expect(one.account.current, isNull);
      expect(one.account.hasCredentials, isFalse);
      await two.account.logout();
      expect(two.account.current, isNull);
      // The original guest token is still useful for legacy receipt recovery,
      // but cannot regain the linked competitive team or mutate the account.
      final guest = await one.guest.active();
      await expectLater(
        one.client.getJson([
          'v1',
          'fantasy',
          'municipalities',
          'tuglie',
          'team',
        ], headers: guest.headers),
        throwsA(isA<ApiException>()),
      );
      expect(originalScope, isNotEmpty);
    },
  );
  test(
    'PostgreSQL team conflict is preserved until explicit keepAccount choice',
    () async {
      HttpOverrides.global = null;
      final fixture = BackendFixture();
      await fixture.start();
      addTearDown(fixture.stop);
      SharedPreferences.setMockInitialValues({});
      final shared = await SharedPreferences.getInstance();
      final transport = CookieClient();
      addTearDown(transport.close);
      final one = Device(
        AppPrefs(
          shared,
          dataStore: LocalDataStore(backend: MemoryLocalBackend()),
        ),
        ApiClient(baseUrl: Uri.parse(fixture.url), client: transport),
      );
      addTearDown(one.dispose);
      await one.login(fixture, 'conflict@example.invalid');
      final authoritative = await one.fantasy.load();
      await one.account.logout();
      var guest = await one.fantasy.load();
      guest = await one.fantasy.execute(
        const SetFantasyCaptain('bus-stazione'),
        expectedRevision: guest.revision,
      );
      await fixture.command('clock', '2026-10-08T00:01:01Z');
      await one.login(fixture, 'conflict@example.invalid');
      final conflict = await one.repository.linkGuest();
      expect(conflict!.linked, isFalse);
      expect(conflict.conflicts, isNotEmpty);
      final stillGuest = await one.client.getJson([
        'v1',
        'fantasy',
        'municipalities',
        'tuglie',
        'team',
      ], headers: (await one.guest.active()).headers);
      expect(stillGuest, isA<Map>());
      expect(
        (await one.fantasy.load()).state.captainId,
        authoritative.state.captainId,
      );
      expect(
        (await one.repository.linkGuest(keepAccount: true))!.linked,
        isTrue,
      );
      expect(
        (await one.fantasy.load()).state.captainId,
        authoritative.state.captainId,
      );
    },
  );
}
