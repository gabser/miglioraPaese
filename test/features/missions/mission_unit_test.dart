import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/account/data/account_intent_store.dart';
import 'package:fanta_comune/features/missions/data/mission_draft_store.dart';
import 'package:fanta_comune/features/missions/data/mission_photo_picker.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import 'package:fanta_comune/features/missions/logic/mission_controller.dart';
import 'mission_test_support.dart';

class WaitingPicker implements MissionPhotoPicker {
  final gate = Completer<Uint8List?>();
  @override
  Future<Uint8List?> pick({required bool camera}) => gate.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'missions default off; enabled requires account; login destination excludes opaque tokens',
    () async {
      expect(AppConfig.fromValues().missionsModeEnabled, isFalse);
      expect(
        () => AppConfig.fromValues(missionsModeEnabled: true),
        throwsArgumentError,
      );
      final h = MissionHarness();
      addTearDown(h.dispose);
      final intents = AccountIntentStore(h.data, 'test');
      await intents.remember('/missions/$missionId');
      expect(await intents.consume(), '/missions/$missionId');
      for (final unsafe in [
        '/missions/$missionId?token=opaque',
        '/missions/../account',
        '/missions/%2fsecret',
        '/missions/secret/token',
      ])
        await expectLater(intents.remember(unsafe), throwsArgumentError);
    },
  );
  test(
    'strict mission/booking mapper uses integer protocol and rejects private area/timezone/unknown status',
    () {
      expect(mission().protocolVersion, 1);
      expect(MissionBooking.fromJson(bookingJson()).protocolVersion, 1);
      for (final bad in [
        {
          ...missionJson(),
          'area': {'label': 'a', 'boundary': 'b', 'public': false},
        },
        {...missionJson(), 'startsAt': '2026-10-14T10:00:00'},
        {
          ...missionJson(),
          'protocol': {...(missionJson()['protocol'] as Map), 'version': '1'},
        },
      ])
        expect(() => Mission.fromJson(bad), throwsFormatException);
      expect(
        () => MissionBooking.fromJson({...bookingJson(), 'status': 'approved'}),
        throwsFormatException,
      );
    },
  );
  test(
    'receipt validates proof metadata and preserves complete server snapshot',
    () {
      final raw = <String, Object?>{
        'id': 'receipt',
        'bookingId': bookingId,
        'missionId': missionId,
        'municipalityId': 'tuglie',
        'windowId': 'synthetic-week-1',
        'protocolVersion': 1,
        'status': 'pendingReview',
        'answer': 'noIssue',
        'submittedAt': '2026-10-14T10:00:00Z',
        'xpAwarded': 0,
        'proofIds': ['proof'],
        'proofs': [
          {
            'id': 'proof',
            'sha256': 'a' * 64,
            'sizeBytes': 75,
            'mimeType': 'image/png',
            'width': 1,
            'height': 1,
          },
        ],
      };
      final receipt = MissionReceipt.fromJson(raw);
      expect(receipt.snapshot, raw);
      expect(receipt.proofs.single.sizeBytes, 75);
      expect(
        () => MissionReceipt.fromJson({
          ...raw,
          'proofIds': ['other'],
        }),
        throwsFormatException,
      );
      expect(
        () => MissionReceipt.fromJson({...raw, 'proofs': null}),
        throwsFormatException,
      );
      expect(
        () => MissionReceipt.fromJson({...raw, 'protocolVersion': '1'}),
        throwsFormatException,
      );
      expect(
        () => MissionReceipt.fromJson({...raw, 'xpAwarded': 10}),
        throwsFormatException,
      );
    },
  );
  test(
    'PNG normalization strips metadata and bounds input/type/pixels',
    () async {
      final bytes = await MissionPhotoNormalizer.normalize(syntheticPng());
      expect(ascii.decode(bytes, allowInvalid: true), isNot(contains('GPS')));
      expect(bytes.take(4), [137, 80, 78, 71]);
      await expectLater(
        MissionPhotoNormalizer.normalize(Uint8List(2 * 1024 * 1024 + 1)),
        throwsStateError,
      );
      await expectLater(
        MissionPhotoNormalizer.normalize(Uint8List.fromList([1, 2, 3])),
        throwsStateError,
      );
    },
  );
  test(
    'offline drafts restore answers/photos and rejected writes preserve prior snapshot',
    () async {
      final h = MissionHarness();
      addTearDown(h.dispose);
      await h.login();
      final m = mission();
      await h.repository.book(m);
      var draft = h.repository
          .restore(m)!
          .copy(answer: MissionAnswer.nonObservable, notes: 'Bozza offline');
      await h.repository.save(draft);
      final old = jsonEncode(h.repository.restore(m)!.toJson());
      h.backend.onWrite = (_, __) async => false;
      await expectLater(
        h.repository.save(draft.copy(notes: 'Non confermata')),
        throwsA(isA<LocalDataWriteException>()),
      );
      expect(jsonEncode(h.repository.restore(m)!.toJson()), old);
      h.backend.onWrite = null;
      final tooLarge = draft.copy(
        photos: [
          MissionPhoto(
            id: 'synthetic',
            bytes: Uint8List(MissionDraftStore.maxPhotoBytes + 1),
          ),
        ],
      );
      await expectLater(h.repository.save(tooLarge), throwsStateError);
      expect(jsonEncode(h.repository.restore(m)!.toJson()), old);
      expect(
        h.repository.drafts.read([...draft.scope]..[6] = 'other-window'),
        isNull,
      );
    },
  );
  test(
    'three drafts quota reports full without replacing previous drafts',
    () async {
      final h = MissionHarness();
      addTearDown(h.dispose);
      await h.login();
      final m = mission();
      await h.repository.book(m);
      final draft = h.repository.restore(m)!;
      for (var i = 2; i <= 3; i++) {
        await h.repository.save(
          MissionDraft(
            scope: [...draft.scope]..[6] = 'window-$i',
            bookingId: bookingId,
            bookingRevision: 1,
          ),
        );
      }
      await expectLater(
        h.repository.save(
          MissionDraft(
            scope: [...draft.scope]..[6] = 'window-4',
            bookingId: bookingId,
            bookingRevision: 1,
          ),
        ),
        throwsStateError,
      );
      expect(h.data.keysWithPrefix('mission-draft:').length, 3);
    },
  );
  test(
    'permission denied and absent geolocation preserve draft and allow nonObservable',
    () async {
      final h = MissionHarness();
      addTearDown(h.dispose);
      await h.login();
      final picker = SyntheticPicker()..denied = true;
      final c = MissionController(repository: h.repository, picker: picker);
      addTearDown(c.dispose);
      await c.open(missionId);
      await c.reserve();
      expect(await c.addPhoto(camera: true), isFalse);
      expect(c.error, contains('permesso negato'));
      expect(c.draft!.photos, isEmpty);
      expect(await c.saveAnswer(MissionAnswer.nonObservable), isTrue);
      expect(c.draft!.answer, MissionAnswer.nonObservable);
      expect(jsonEncode(c.draft!.toJson()), isNot(contains('latitude')));
    },
  );
  test(
    'late photo callback after logout cannot repopulate draft or stored proof',
    () async {
      final h = MissionHarness();
      addTearDown(h.dispose);
      await h.login();
      final picker = WaitingPicker();
      final c = MissionController(repository: h.repository, picker: picker);
      addTearDown(c.dispose);
      await c.open(missionId);
      await c.reserve();
      final scope = c.draft!.scope;
      final pending = c.addPhoto(camera: false);
      await Future<void>.delayed(Duration.zero);
      await h.account.logout();
      picker.gate.complete(syntheticPng());
      expect(await pending, isFalse);
      expect(c.draft, isNull);
      expect(h.repository.drafts.read(scope)!.photos, isEmpty);
    },
  );
  test(
    'Comune changes invalidate late catalog, booking and proof callbacks',
    () async {
      for (final stage in ['catalog', 'booking', 'photo']) {
        final gate = Completer<void>();
        final reached = Completer<void>();
        final h = MissionHarness((r) async {
          if ((stage == 'catalog' && r.url.path.endsWith('/missions')) ||
              (stage == 'booking' && r.url.path.endsWith('/bookings'))) {
            reached.complete();
            await gate.future;
          }
          return defaultReply(r);
        });
        await h.login();
        final changes = ChangeNotifier();
        final picker = WaitingPicker();
        final c = MissionController(
          repository: h.repository,
          picker: picker,
          municipalityChanges: changes,
        );
        if (stage != 'catalog') await c.open(missionId);
        if (stage == 'photo') await c.reserve();
        final pending = stage == 'catalog'
            ? c.browse()
            : stage == 'booking'
            ? c.reserve()
            : c.addPhoto(camera: false);
        if (stage != 'photo') await reached.future;
        h.municipalityId = 'bologna';
        changes.notifyListeners();
        h.municipalityId = 'tuglie';
        changes.notifyListeners();
        if (stage == 'photo')
          picker.gate.complete(syntheticPng());
        else
          gate.complete();
        expect(await pending, isFalse);
        expect(c.catalog, isEmpty);
        expect(c.mission, isNull);
        expect(c.draft, isNull);
        if (stage == 'booking')
          expect(h.data.keysWithPrefix('mission-draft:'), isEmpty);
        c.dispose();
        changes.dispose();
        h.dispose();
      }
    },
  );
  test(
    'Comune change during durable write restores prior disk and memory draft',
    () async {
      final h = MissionHarness();
      addTearDown(h.dispose);
      await h.login();
      final m = mission();
      await h.repository.book(m);
      final draft = h.repository.restore(m)!;
      final scope = draft.scope;
      final previousDisk = Map<String, String>.from(h.backend.values);
      final gate = Completer<void>(), reached = Completer<void>();
      var first = true;
      h.backend.onWrite = (_, __) async {
        if (first) {
          first = false;
          reached.complete();
          await gate.future;
        }
        return true;
      };
      final pending = h.repository.save(draft.copy(notes: 'stale'));
      final assertion = expectLater(
        pending,
        throwsA(isA<LocalDataResetException>()),
      );
      await reached.future;
      h.municipalityId = 'bologna';
      h.municipalityId = 'tuglie';
      gate.complete();
      await assertion;
      expect(h.repository.drafts.read(scope)!.notes, '');
      expect(h.backend.values, previousDisk);
    },
  );
  test(
    'public catalog works anonymously and deduplicates next server weekly window without mock',
    () async {
      final h = MissionHarness(
        (r) async => reply({
          'items': [missionJson(), missionJson(window: 'synthetic-week-2')],
        }),
      );
      addTearDown(h.dispose);
      expect((await h.repository.catalog()).length, 1);
      expect(h.account.hasCredentials, isFalse);
    },
  );
}
