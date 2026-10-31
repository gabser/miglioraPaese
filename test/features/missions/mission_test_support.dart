import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:fanta_comune/features/missions/data/mission_repository.dart';
import 'package:fanta_comune/features/missions/data/mission_photo_picker.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import '../../helpers/memory_local_backend.dart';

const accountId = '11111111-1111-1111-1111-111111111111',
    bookingId = '22222222-2222-2222-2222-222222222222';
const missionId = 'synthetic-cleanliness-tuglie';
Map<String, Object?> missionJson({String window = 'synthetic-week-1'}) => {
  'id': missionId,
  'municipalityId': 'tuglie',
  'zoneId': 'synthetic-centre',
  'title': 'Pulizia area pubblica — prova sintetica',
  'area': {
    'label': 'Area sintetica',
    'boundary': 'Quadrilatero A–B–C–D',
    'public': true,
  },
  'protocol': {
    'id': 'synthetic-protocol',
    'version': 1,
    'instructions': [
      'Osserva solo luoghi sintetici.',
      'Rinuncia se non puoi accedere.',
    ],
    'photoPoints': [
      {'id': 'a', 'label': 'Ingresso sintetico rivolto al centro'},
    ],
    'minPhotos': 1,
    'indicator': 'Rifiuti visibili',
    'threshold': 'Almeno uno',
  },
  'windowId': window,
  'startsAt': '2026-10-14T00:00:00Z',
  'endsAt': '2026-10-21T00:00:00Z',
  'durationMinutes': 15,
  'availableSlots': 2,
  'rewardXp': 10,
  'synthetic': true,
};
Map<String, Object?> bookingJson() => {
  'id': bookingId,
  'missionId': missionId,
  'windowId': 'synthetic-week-1',
  'protocolVersion': 1,
  'status': 'active',
  'expiresAt': '2026-10-14T10:30:00Z',
  'revision': 1,
};
Map<String, Object?> authJson() => {
  'token': 'A' * 43,
  'sessionId': accountId,
  'submissionScope': accountId,
  'expiresAt': '2027-01-01T00:00:00Z',
  'account': {
    'id': accountId,
    'pseudonym': 'Sentinella',
    'email': 'one@example.invalid',
    'emailVerified': true,
  },
};
http.Response reply(Object raw, [int code = 200]) => http.Response(
  jsonEncode(raw),
  code,
  headers: {'content-type': 'application/json'},
);
Future<http.Response> defaultReply(http.Request r) async {
  if (r.url.path.endsWith('/auth/verify') || r.url.path.endsWith('/auth/me'))
    return reply(authJson());
  if (r.url.path.endsWith('/auth/logout')) return reply({'revoked': true});
  if (r.url.path.endsWith('/missions'))
    return reply({
      'items': [missionJson()],
    });
  if (r.url.path.endsWith('/booking')) return reply({'booking': null});
  if (r.url.path.endsWith('/bookings')) return reply(bookingJson());
  if (r.url.path.contains('/bookings/')) return reply(bookingJson());
  if (r.url.path.endsWith('/$missionId'))
    return reply({'mission': missionJson()});
  throw StateError('Unexpected test path ${r.url.path}');
}

class MissionHarness {
  MissionHarness([Future<http.Response> Function(http.Request)? handler]) {
    backend = MemoryLocalBackend();
    data = LocalDataStore(backend: backend);
    client = ApiClient(
      baseUrl: Uri.parse('https://synthetic.invalid'),
      client: MockClient(handler ?? defaultReply),
    );
    account = AccountSessionStore(
      client: client,
      data: data,
      environment: 'mission-test',
    );
    repository = MissionRepository(
      client: client,
      account: account,
      environment: 'mission-test',
      municipalityId: 'tuglie',
      municipality: () => municipalityId,
      municipalityChanges: municipalityChanges,
    );
  }
  final municipalityChanges = ChangeNotifier();
  String _municipalityId = 'tuglie';
  String get municipalityId => _municipalityId;
  set municipalityId(String next) {
    _municipalityId = next;
    municipalityChanges.notifyListeners();
  }

  late MemoryLocalBackend backend;
  late LocalDataStore data;
  late ApiClient client;
  late AccountSessionStore account;
  late MissionRepository repository;
  Future<void> login() =>
      account.verify(challengeId: accountId, code: '000000');
  void dispose() {
    repository.dispose();
    municipalityChanges.dispose();
    account.dispose();
    data.dispose();
  }
}

class SyntheticPicker implements MissionPhotoPicker {
  Uint8List? bytes = syntheticPng();
  bool denied = false;
  @override
  Future<Uint8List?> pick({required bool camera}) async =>
      denied ? null : bytes;
}

Uint8List syntheticPng({int width = 1, int height = 1, bool metadata = true}) {
  int crc(List<int> data) {
    var c = 0xffffffff;
    for (final b in data) {
      c ^= b;
      for (var i = 0; i < 8; i++) {
        c = (c >> 1) ^ ((c & 1) != 0 ? 0xedb88320 : 0);
      }
    }
    return (c ^ 0xffffffff) & 0xffffffff;
  }

  List<int> word(int n) => [
    (n >> 24) & 255,
    (n >> 16) & 255,
    (n >> 8) & 255,
    n & 255,
  ];
  List<int> chunk(String type, List<int> bytes) {
    final name = ascii.encode(type);
    return [
      ...word(bytes.length),
      ...name,
      ...bytes,
      ...word(crc([...name, ...bytes])),
    ];
  }

  final raw = <int>[];
  for (var y = 0; y < height; y++) {
    raw.add(0);
    for (var x = 0; x < width; x++) {
      raw.addAll([255, 0, 0, 255]);
    }
  }
  return Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk('IHDR', [...word(width), ...word(height), 8, 6, 0, 0, 0]),
    if (metadata)
      ...chunk('tEXt', ascii.encode('GPS\u0000private-synthetic-location')),
    ...chunk('IDAT', ZLibEncoder().convert(raw)),
    ...chunk('IEND', []),
  ]);
}

Mission mission() => Mission.fromJson(missionJson());
