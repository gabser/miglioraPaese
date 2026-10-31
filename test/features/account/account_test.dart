import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/account/data/account_intent_store.dart';
import 'package:fanta_comune/features/account/data/account_repository.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:fanta_comune/features/account/data/authenticated_session_source.dart';
import 'package:fanta_comune/features/account/domain/account_models.dart';
import 'package:fanta_comune/features/account/logic/account_controller.dart';
import 'package:fanta_comune/features/account/presentation/account_page.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import '../../helpers/memory_local_backend.dart';

const id = '11111111-1111-1111-1111-111111111111';
final token = 'A' * 43;
Map<String, Object?> profile() => {
  'id': id,
  'email': 'one@example.invalid',
  'pseudonym': 'Sentinella',
  'emailVerified': true,
};
Map<String, Object?> session() => {
  'token': token,
  'sessionId': id,
  'submissionScope': id,
  'expiresAt': '2027-01-01T00:00:00Z',
  'account': profile(),
};
http.Response json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

class Harness {
  Harness(Future<http.Response> Function(http.Request) handler) {
    data = LocalDataStore(backend: MemoryLocalBackend());
    client = ApiClient(
      baseUrl: Uri.parse('https://fixture.invalid'),
      client: MockClient(handler),
    );
    sessions = AccountSessionStore(
      client: client,
      data: data,
      environment: 'test',
    );
    guest = ProposalSessionStore(
      client: client,
      data: data,
      environment: 'test',
    );
    repository = AccountRepository(
      client: client,
      sessions: sessions,
      guest: guest,
      environment: 'test',
    );
    intents = AccountIntentStore(data, 'test');
  }
  late LocalDataStore data;
  late ApiClient client;
  late AccountSessionStore sessions;
  late ProposalSessionStore guest;
  late AccountRepository repository;
  late AccountIntentStore intents;
  void dispose() {
    sessions.dispose();
    data.dispose();
  }
}

Future<http.Response> defaultReply(http.Request request) async {
  switch (request.url.path) {
    case '/v1/auth/code':
      return json({
        'challengeId': id,
        'expiresAt': '2026-10-14T00:00:00Z',
        'retryAfterSeconds': 60,
        'delivery': 'simulated',
      });
    case '/v1/auth/verify':
      return json(session());
    case '/v1/auth/me':
      return json(session());
    case '/v1/auth/logout':
      return json({'revoked': true});
    case '/v1/auth/devices':
      return json({'items': []});
    default:
      throw StateError('Unexpected path ${request.url.path}');
  }
}

void main() {
  setUpAll(() async {
    final fontRoot = Platform.environment['SENTINELLE_VISUAL_FONT_DIR'];
    if (fontRoot == null) return;
    final fonts = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf']) {
      fonts.addFont(
        File(
          '$fontRoot/$name',
        ).readAsBytes().then((v) => ByteData.sublistView(v)),
      );
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      File(
        '$fontRoot/MaterialIcons-Regular.otf',
      ).readAsBytes().then((v) => ByteData.sublistView(v)),
    );
    await icons.load();
  });
  test(
    'account flag defaults off and intents allow only safe destinations once',
    () async {
      expect(AppConfig.fromValues().accountModeEnabled, isFalse);
      final h = Harness(defaultReply);
      addTearDown(h.dispose);
      for (final route in [
        '/leagues?invite=secret',
        'https://evil.invalid',
        '/mission',
        '/account',
      ]) {
        await expectLater(h.intents.remember(route), throwsArgumentError);
      }
      await h.intents.remember('/squad');
      expect(await h.intents.consume(), '/squad');
      expect(await h.intents.consume(), isNull);
    },
  );
  test('profile mapper refuses missing verification and wrong fields', () {
    for (final bad in [
      null,
      {},
      {...profile(), 'emailVerified': false},
      {...profile(), 'pseudonym': 42},
    ]) {
      expect(() => AccountProfile.fromJson(bad), throwsFormatException);
    }
  });
  test(
    'missing token does not leave authentication stuck; malformed token reply is revoked',
    () async {
      var missing = true, revokes = 0;
      final h = Harness((r) async {
        if (r.url.path.endsWith('/verify'))
          return json(
            missing
                ? ({...session()}..remove('token'))
                : {...session(), 'expiresAt': 'wrong'},
          );
        if (r.url.path.endsWith('/logout')) revokes++;
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await expectLater(
        h.sessions.verify(challengeId: id, code: '000000'),
        throwsA(isA<ApiException>()),
      );
      expect(h.sessions.authenticating, isFalse);
      expect(h.sessions.hasCredentials, isFalse);
      missing = false;
      await expectLater(
        h.sessions.verify(challengeId: id, code: '000000'),
        throwsA(isA<ApiException>()),
      );
      expect(h.sessions.authenticating, isFalse);
      expect(revokes, 1);
    },
  );
  test(
    'late verification after logout cannot install credentials and revokes raw reply',
    () async {
      final gate = Completer<http.Response>();
      var revokes = 0;
      final h = Harness((r) async {
        if (r.url.path.endsWith('/verify')) return gate.future;
        if (r.url.path.endsWith('/logout')) revokes++;
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      final pending = h.sessions.verify(challengeId: id, code: '000000');
      await Future<void>.delayed(Duration.zero);
      await h.sessions.logout();
      gate.complete(json(session()));
      await expectLater(pending, throwsA(isA<LocalDataResetException>()));
      expect(h.sessions.hasCredentials, isFalse);
      expect(h.sessions.current, isNull);
      expect(revokes, 1);
    },
  );
  test(
    'logout clears profile immediately and blocks competitive lease during transport failure',
    () async {
      var offline = false;
      final h = Harness((r) async {
        if (offline && r.url.path.endsWith('/logout'))
          throw http.ClientException('offline');
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.sessions.verify(challengeId: id, code: '000000');
      final source = AuthenticatedSessionSource(
        guest: h.guest,
        account: h.sessions,
      );
      addTearDown(source.dispose);
      final lease = await source.active();
      offline = true;
      final pending = h.sessions.logout();
      expect(h.sessions.current, isNull);
      expect(
        () => source.checkLease(lease),
        throwsA(isA<LocalDataResetException>()),
      );
      await expectLater(pending, throwsA(isA<ApiException>()));
      expect(h.sessions.signingOut, isTrue);
      await expectLater(
        source.active(),
        throwsA(isA<LocalDataResetException>()),
      );
      offline = false;
      await h.sessions.logout();
      expect(h.sessions.hasCredentials, isFalse);
    },
  );
  test(
    'controller presents code errors and resend cooldown; resets after failure',
    () async {
      var now = DateTime.utc(2026, 10, 14);
      final h = Harness((r) async {
        if (r.url.path.endsWith('/verify'))
          return json({'error': 'code_invalid', 'message': 'invalid'}, 422);
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      final c = AccountController(
        repository: h.repository,
        intents: h.intents,
        now: () => now,
      );
      addTearDown(c.dispose);

      await c.settled;
      expect(await c.sendCode(' One@EXAMPLE.INVALID '), isTrue);
      expect(c.email, 'one@example.invalid');
      expect(c.resendRemaining, 61);
      now = now.add(const Duration(seconds: 62));
      expect(c.resendRemaining, 0);
      expect(await c.verify('000000'), isFalse);
      expect(c.error, contains('sei cifre'));
      expect(c.busy, isFalse);
      expect(h.sessions.authenticating, isFalse);
      c.resetChallenge();
      expect(c.challenge, isNull);
    },
  );
  for (final width in [390.0, 1024.0, 1440.0]) {
    testWidgets(
      'account email/code inline validation and keyboard layout $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final h = Harness(defaultReply);
        final c = AccountController(
          repository: h.repository,
          intents: h.intents,
        );

        addTearDown(h.dispose);
        await c.settled;
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: c,
            child: RepaintBoundary(
              key: captureKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                home: const AccountPage(),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.text('Richiedi codice locale'));
        await tester.tap(find.text('Richiedi codice locale'));
        await tester.pump();
        expect(
          find.text('Usa un indirizzo sintetico dei domini indicati.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('account-email')),
          'one@example.invalid',
        );
        await tester.ensureVisible(find.text('Richiedi codice locale'));
        await tester.tap(find.text('Richiedi codice locale'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('account-code')), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('account-code')),
          '12',
        );
        await tester.ensureVisible(find.text('Verifica e accedi'));
        await tester.tap(find.text('Verifica e accedi'));
        await tester.pump();
        expect(find.text('Inserisci sei cifre.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 300));
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory('/tmp/sentinelle-account-visuals');
          await folder.create(recursive: true);
          await File(
            '${folder.path}/account-keyboard-error-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
  test(
    'authoritative session revocation clears identity and invalidates old leases',
    () async {
      var revoked = false;
      final h = Harness((r) async {
        if (revoked && r.url.path.endsWith('/me'))
          return json({
            'error': 'proposal_session_revoked',
            'message': 'revoked',
          }, 401);
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.sessions.verify(challengeId: id, code: '000000');
      final source = AuthenticatedSessionSource(
        guest: h.guest,
        account: h.sessions,
      );
      addTearDown(source.dispose);
      final lease = await source.active();
      revoked = true;
      await expectLater(h.sessions.active(), throwsA(isA<ApiException>()));
      expect(h.sessions.current, isNull);
      expect(h.sessions.hasCredentials, isFalse);
      expect(
        () => source.checkLease(lease),
        throwsA(isA<LocalDataResetException>()),
      );
    },
  );
  for (final width in [390.0, 1024.0, 1440.0]) {
    testWidgets(
      'account conflict, device confirmation and offline error $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var offline = false;
        final h = Harness((r) async {
          if (offline) throw http.ClientException('offline');
          if (r.url.path.endsWith('/devices'))
            return json({
              'items': [
                {
                  'id': id,
                  'name': 'Browser sintetico',
                  'isCurrent': true,
                  'createdAt': '2026-10-14T00:00:00Z',
                },
              ],
            });
          if (r.url.path.endsWith('/profile'))
            return json({'account': profile()});
          return defaultReply(r);
        });
        await h.sessions.verify(challengeId: id, code: '000000');
        final c = AccountController(
          repository: h.repository,
          intents: h.intents,
        );
        await c.settled;
        c.conflicts = const [
          GuestLinkConflict(seasonId: 'season', municipalityId: 'tuglie'),
        ];
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: c,
            child: RepaintBoundary(
              key: captureKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                home: const AccountPage(),
              ),
            ),
          ),
        );
        await tester.ensureVisible(
          find.text('Conserva account e abbandona ospite'),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('/tmp/sentinelle-account-visuals');
          await directory.create(recursive: true);
          await File(
            '${directory.path}/account-conflict-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.text('Conserva account e abbandona ospite'));
        await tester.pumpAndSettle();
        expect(
          find.text('Conservare la squadra dell’account?'),
          findsOneWidget,
        );
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        expect(c.conflicts, isNotEmpty);
        offline = true;
        await c.refresh();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('account-error')));
        expect(find.textContaining('non è raggiungibile'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/sentinelle-account-visuals/account-offline-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        h.dispose();
      },
    );
  }
  testWidgets(
    'anonymous exploration resumes only the whitelisted navigation intent',
    (tester) async {
      final h = Harness(defaultReply);
      final c = AccountController(repository: h.repository, intents: h.intents);
      await c.settled;
      final router = GoRouter(
        initialLocation: '/account',
        routes: [
          GoRoute(
            path: '/account',
            builder: (_, __) => const AccountPage(returnTo: '/squad'),
          ),
          GoRoute(
            path: '/squad',
            builder: (_, __) =>
                const Scaffold(body: Text('Squadra esplorabile')),
          ),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: c,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Continua a esplorare senza account'),
      );
      await tester.tap(find.text('Continua a esplorare senza account'));
      await tester.pumpAndSettle();
      expect(find.text('Squadra esplorabile'), findsOneWidget);
      expect(h.sessions.hasCredentials, isFalse);
      expect(await h.intents.consume(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      c.dispose();
      h.dispose();
    },
  );
}
