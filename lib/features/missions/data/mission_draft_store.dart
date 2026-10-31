import 'dart:convert';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import '../domain/mission_models.dart';

class MissionDraftStore {
  MissionDraftStore(this.data);
  final LocalDataStore data;
  static const maxPhotos = 3, maxPhotoBytes = 256 * 1024, maxDrafts = 3;
  String key(List<String> scope) => 'mission-draft:${jsonEncode(scope)}';
  MissionDraft? read(List<String> scope) {
    final raw = data.read(key(scope));
    if (raw == null) return null;
    final draft = MissionDraft.fromJson(raw);
    if (jsonEncode(draft.scope) != jsonEncode(scope))
      throw const LocalDataCorruptException();
    return draft;
  }

  Future<void> save(
    MissionDraft draft, {
    required int epoch,
    required void Function() check,
  }) => data.mutate<void>(
    key(draft.scope),
    (prior) {
      check();
      if (draft.photos.length > maxPhotos ||
          draft.photos.any((p) => p.bytes.length > maxPhotoBytes))
        throw StateError(
          'Limite locale: tre prove PNG, massimo 256 KB ciascuna. Nessun dato è stato sostituito.',
        );
      if (prior == null &&
          data.keysWithPrefix('mission-draft:').length >= maxDrafts)
        throw StateError(
          'Archivio locale pieno: conserva o rimuovi esplicitamente una delle tre bozze prima di proseguire.',
        );
      if (prior != null &&
          MissionDraft.fromJson(prior).submitBody != null &&
          jsonEncode(MissionDraft.fromJson(prior).submitBody) !=
              jsonEncode(draft.submitBody))
        throw StateError(
          'Invio da verificare: la bozza originale è conservata.',
        );
      return LocalDataMutation(draft.toJson(), null);
    },
    expectedEpoch: epoch,
    check: check,
  );
  Future<void> remove(
    List<String> scope, {
    required int epoch,
    required void Function() check,
  }) => data.mutate<void>(
    key(scope),
    (_) {
      check();
      return const LocalDataMutation(null, null);
    },
    expectedEpoch: epoch,
    check: check,
  );
}
