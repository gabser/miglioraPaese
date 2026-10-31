import 'dart:convert';
import 'dart:typed_data';

Map<String, dynamic> missionObject(Object? value) {
  if (value is! Map)
    throw const FormatException('Risposta missione non valida.');
  return Map<String, dynamic>.from(value);
}

String missionString(Map<String, dynamic> map, String key) {
  final v = map[key];
  if (v is! String || v.isEmpty)
    throw FormatException('Campo missione mancante: $key');
  return v;
}

int missionInt(Map<String, dynamic> map, String key) {
  final v = map[key];
  if (v is! int || v < 0)
    throw FormatException('Campo missione non valido: $key');
  return v;
}

DateTime missionDate(Map<String, dynamic> map, String key) {
  final v = missionString(map, key);
  if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(v))
    throw const FormatException('Timezone mancante.');
  return DateTime.parse(v).toUtc();
}

List<String> missionStrings(Object? raw) {
  if (raw is! List || raw.any((v) => v is! String))
    throw const FormatException('Istruzioni non valide.');
  return List<String>.unmodifiable(raw);
}

class MissionMeasurementDefinition {
  MissionMeasurementDefinition.fromJson(Object? raw) {
    final m = missionObject(raw);
    protocolId = missionString(m, 'protocolId');
    protocolVersion = missionInt(m, 'protocolVersion');
    indicator = missionString(m, 'indicator');
    unit = missionString(m, 'unit');
    minValue = _number(m['minValue']);
    maxValue = _number(m['maxValue']);
    if (m['integerOnly'] is! bool || minValue > maxValue || protocolVersion < 1)
      throw const FormatException('Limiti misura non validi.');
    integerOnly = m['integerOnly'] as bool;
  }
  static num _number(Object? v) {
    if (v is! num || !v.isFinite || v.abs() > 1e9)
      throw const FormatException('Misura non valida.');
    return v;
  }

  late final String protocolId, indicator, unit;
  late final int protocolVersion;
  late final num minValue, maxValue;
  late final bool integerOnly;
  String? validate(String? text) {
    final v = num.tryParse((text ?? '').trim().replaceAll(',', '.'));
    if (v == null || !v.isFinite) return 'Inserisci una misura in $unit.';
    if (v < minValue || v > maxValue)
      return 'Valore consentito: $minValue–$maxValue $unit.';
    if (integerOnly && v != v.roundToDouble())
      return 'Inserisci un numero intero.';
    return null;
  }

  bool requiresValue(MissionAnswer? answer) =>
      answer == MissionAnswer.noIssue || answer == MissionAnswer.visibleWaste;
}

class MissionMeasurement {
  MissionMeasurement.fromJson(Object? raw) {
    final m = missionObject(raw);
    value = MissionMeasurementDefinition._number(m['value']);
    unit = missionString(m, 'unit');
    indicator = missionString(m, 'indicator');
    protocolId = missionString(m, 'protocolId');
    protocolVersion = missionInt(m, 'protocolVersion');
    recordedAt = missionDate(m, 'recordedAt');
  }
  late final num value;
  late final String unit, indicator, protocolId;
  late final int protocolVersion;
  late final DateTime recordedAt;
}

class Mission {
  Mission.fromJson(Object? raw) {
    final m = missionObject(raw), p = missionObject(m['protocol']);
    snapshot = Map<String, dynamic>.unmodifiable(m);
    id = missionString(m, 'id');
    placeId = m['placeId'] == null ? null : missionString(m, 'placeId');
    municipalityId = missionString(m, 'municipalityId');
    zoneId = missionString(m, 'zoneId');
    title = missionString(m, 'title');
    final a = missionObject(m['area']);
    if (a['public'] != true) throw const FormatException('Area non pubblica.');
    area = '${missionString(a, 'label')} · ${missionString(a, 'boundary')}';
    measurementDefinition = p['measurementDefinition'] == null
        ? null
        : MissionMeasurementDefinition.fromJson(p['measurementDefinition']);
    protocolId = missionString(p, 'id');
    protocolVersion = missionInt(p, 'version');
    instructions = missionStrings(p['instructions']);
    photoPoints = (p['photoPoints'] as List)
        .map((v) => missionString(missionObject(v), 'label'))
        .toList();
    minPhotos = missionInt(p, 'minPhotos');
    windowId = missionString(m, 'windowId');
    startsAt = missionDate(m, 'startsAt');
    endsAt = missionDate(m, 'endsAt');
    durationMinutes = missionInt(m, 'durationMinutes');
    availableSlots = missionInt(m, 'availableSlots');
    rewardXp = missionInt(m, 'rewardXp');
    if (m['synthetic'] != true || rewardXp != 10 || minPhotos > 3)
      throw const FormatException('Profilo sintetico missione non valido.');
  }
  late final String? placeId;
  late final MissionMeasurementDefinition? measurementDefinition;
  late final Map<String, dynamic> snapshot;
  late final String id,
      municipalityId,
      zoneId,
      title,
      area,
      protocolId,
      windowId;
  late final List<String> instructions, photoPoints;
  late final int protocolVersion,
      minPhotos,
      durationMinutes,
      availableSlots,
      rewardXp;
  late final DateTime startsAt, endsAt;
}

class MissionBooking {
  MissionBooking.fromJson(Object? raw) {
    final m = missionObject(raw);
    id = missionString(m, 'id');
    missionId = missionString(m, 'missionId');
    windowId = missionString(m, 'windowId');
    protocolVersion = missionInt(m, 'protocolVersion');
    status = missionString(m, 'status');
    expiresAt = missionDate(m, 'expiresAt');
    revision = missionInt(m, 'revision');
    replicationRequestId = m['replicationRequestId'] as String?;
    if (!['active', 'released', 'expired', 'submitted'].contains(status))
      throw const FormatException('Stato prenotazione sconosciuto.');
  }
  late final String id, missionId, windowId, status;
  late final String? replicationRequestId;
  late final int protocolVersion;
  late final DateTime expiresAt;
  late final int revision;
}

enum MissionAnswer { noIssue, nonObservable, unsure, visibleWaste }

extension MissionAnswerLabel on MissionAnswer {
  String get label => switch (this) {
    MissionAnswer.noIssue => 'Nessuna criticità visibile',
    MissionAnswer.nonObservable => 'Non osservabile',
    MissionAnswer.unsure => 'Non so',
    MissionAnswer.visibleWaste => 'Rifiuti visibili',
  };
}

class MissionReceipt {
  MissionReceipt.fromJson(Object? raw) {
    final m = missionObject(raw);
    snapshot = Map<String, Object?>.unmodifiable(
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>,
    );
    protocolVersion = missionInt(m, 'protocolVersion');
    proofIds = missionStrings(m['proofIds']);
    if (m['proofs'] is! List)
      throw const FormatException('Prove ricevuta mancanti.');
    proofs = List<MissionProof>.unmodifiable(
      (m['proofs'] as List).map(MissionProof.fromJson),
    );
    if (proofIds.length > 3 ||
        proofIds.toSet().length != proofIds.length ||
        jsonEncode(proofIds) != jsonEncode(proofs.map((p) => p.id).toList())) {
      throw const FormatException('Prove ricevuta incoerenti.');
    }
    measurement = m['measurement'] == null
        ? null
        : MissionMeasurement.fromJson(m['measurement']);
    id = missionString(m, 'id');
    bookingId = missionString(m, 'bookingId');
    missionId = missionString(m, 'missionId');
    municipalityId = missionString(m, 'municipalityId');
    windowId = missionString(m, 'windowId');
    status = missionString(m, 'status');
    answer = MissionAnswer.values.byName(missionString(m, 'answer'));
    submittedAt = missionDate(m, 'submittedAt');
    xpAwarded = missionInt(m, 'xpAwarded');
    if (status != 'pendingReview' || xpAwarded != 0)
      throw const FormatException(
        'Ricevuta non compatibile con la revisione umana.',
      );
  }
  late final MissionMeasurement? measurement;
  late final String id, bookingId, missionId, municipalityId, windowId, status;
  late final MissionAnswer answer;
  late final DateTime submittedAt;
  late final int xpAwarded, protocolVersion;
  late final List<String> proofIds;
  late final List<MissionProof> proofs;
  late final Map<String, Object?> snapshot;
}

class MissionProof {
  MissionProof.fromJson(Object? raw) {
    final m = missionObject(raw);
    id = missionString(m, 'id');
    sha256 = missionString(m, 'sha256');
    sizeBytes = missionInt(m, 'sizeBytes');
    width = missionInt(m, 'width');
    height = missionInt(m, 'height');
    if (m['mimeType'] != 'image/png' ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        sizeBytes == 0 ||
        sizeBytes > 2 * 1024 * 1024 ||
        width == 0 ||
        height == 0) {
      throw const FormatException('Metadata prova non validi.');
    }
  }
  late final String id, sha256;
  late final int sizeBytes, width, height;
}

class MissionPhoto {
  MissionPhoto({required this.id, required Uint8List bytes, this.uploadId})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String id;
  final Uint8List bytes;
  final String? uploadId;
  MissionPhoto withUpload(String value) =>
      MissionPhoto(id: id, bytes: bytes, uploadId: value);
  Map<String, Object?> toJson() => {
    'id': id,
    'png': base64Encode(bytes),
    'uploadId': uploadId,
  };
  factory MissionPhoto.fromJson(Object? raw) {
    final m = missionObject(raw);
    return MissionPhoto(
      id: missionString(m, 'id'),
      bytes: base64Decode(missionString(m, 'png')),
      uploadId: m['uploadId'] as String?,
    );
  }
}

class MissionDraft {
  MissionDraft({
    required this.scope,
    required this.bookingId,
    required this.bookingRevision,
    this.answer,
    this.notes = '',
    this.measurementValue,
    this.photos = const [],
    this.submitBody,
    this.receipt,
    this.missionSnapshot,
    this.rejectionCode,
  });
  final List<String> scope;
  final Map<String, Object?>? missionSnapshot;
  final String? rejectionCode;
  final String bookingId;
  final int bookingRevision;
  final MissionAnswer? answer;
  final String notes;
  final num? measurementValue;
  final List<MissionPhoto> photos;
  final Map<String, Object?>? submitBody;
  final Map<String, Object?>? receipt;
  MissionDraft copy({
    MissionAnswer? answer,
    String? notes,
    num? measurementValue,
    bool clearMeasurement = false,
    List<MissionPhoto>? photos,
    Map<String, Object?>? submitBody,
    Map<String, Object?>? receipt,
    String? rejectionCode,
  }) => MissionDraft(
    scope: scope,
    bookingId: bookingId,
    bookingRevision: bookingRevision,
    answer: answer ?? this.answer,
    notes: notes ?? this.notes,
    measurementValue: clearMeasurement
        ? null
        : measurementValue ?? this.measurementValue,
    photos: photos ?? this.photos,
    submitBody: submitBody ?? this.submitBody,
    receipt: receipt ?? this.receipt,
    missionSnapshot: missionSnapshot,
    rejectionCode: rejectionCode ?? this.rejectionCode,
  );
  Map<String, Object?> toJson() => {
    'version': 1,
    'rejectionCode': rejectionCode,
    'missionSnapshot': missionSnapshot,
    'scope': scope,
    'bookingId': bookingId,
    'bookingRevision': bookingRevision,
    'answer': answer?.name,
    'notes': notes,
    if (measurementValue != null) 'measurementValue': measurementValue,
    'photos': photos.map((v) => v.toJson()).toList(),
    'submitBody': submitBody,
    'receipt': receipt,
  };
  factory MissionDraft.fromJson(Object? raw) {
    final m = missionObject(raw);
    if (m['version'] != 1 || m['scope'] is! List || m['photos'] is! List)
      throw const FormatException('Bozza non valida.');
    return MissionDraft(
      rejectionCode: m['rejectionCode'] as String?,
      scope: missionStrings(m['scope']),
      bookingId: missionString(m, 'bookingId'),
      bookingRevision: missionInt(m, 'bookingRevision'),
      answer: m['answer'] == null
          ? null
          : MissionAnswer.values.byName(m['answer'] as String),
      notes: m['notes'] as String,
      measurementValue: m['measurementValue'] == null
          ? null
          : MissionMeasurementDefinition._number(m['measurementValue']),
      photos: (m['photos'] as List).map(MissionPhoto.fromJson).toList(),
      submitBody: m['submitBody'] == null
          ? null
          : missionObject(m['submitBody']).cast<String, Object?>(),
      receipt: m['receipt'] == null
          ? null
          : missionObject(m['receipt']).cast<String, Object?>(),
      missionSnapshot: m['missionSnapshot'] == null
          ? null
          : missionObject(m['missionSnapshot']).cast<String, Object?>(),
    );
  }
}
