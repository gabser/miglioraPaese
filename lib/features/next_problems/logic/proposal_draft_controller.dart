import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_draft.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';

enum DraftSaveStatus { empty, restored, saving, saved, failed, reset }

class ProposalDraftController extends ChangeNotifier {
  ProposalDraftController({required this.store, required this.scope})
    : epoch = store.localData.epoch {
    try {
      draft = store.load(scope) ?? const ProposalDraft();
      _persistedRevision = draft.revision;
      status = draft.isEmpty ? DraftSaveStatus.empty : DraftSaveStatus.restored;
    } catch (_) {
      status = DraftSaveStatus.failed;
      _failedRevision = 0;
    }
    store.localData.addListener(_onLocalData);
  }
  final ProposalDraftStore store;
  final ProposalScope scope;
  final int epoch;
  ProposalDraft draft = const ProposalDraft();
  DraftSaveStatus status = DraftSaveStatus.empty;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  bool _reset = false;
  int _persistedRevision = 0;
  int _failedRevision = -1;

  void edit(ProposalDraft value) {
    if (_reset || _disposed) return;
    try {
      draft = value.withRevision(store.nextRevision(scope, draft.revision));
    } catch (_) {
      draft = value.withRevision(draft.revision + 1);
    }
    _save();
  }

  void retry() {
    if (_reset || _disposed) return;
    _save();
  }

  void _save() {
    final snapshot = draft;
    status = DraftSaveStatus.saving;
    notifyListeners();
    // No debounce timer: changes enqueue immediately and continue after dispose.
    _pending = store
        .save(scope, snapshot, epoch: epoch)
        .then<void>(
          (_) {
            _persistedRevision = snapshot.revision;
            if (_failedRevision == snapshot.revision) _failedRevision = -1;
            if (_disposed || _reset || draft.revision != snapshot.revision)
              return;
            status = snapshot.isEmpty
                ? DraftSaveStatus.empty
                : DraftSaveStatus.saved;
            notifyListeners();
          },
          onError: (Object _, StackTrace __) {
            _failedRevision = snapshot.revision;
            if (_disposed || _reset || draft.revision != snapshot.revision)
              return;
            status = DraftSaveStatus.failed;
            notifyListeners();
          },
        );
  }

  Future<bool> flush() async {
    while (true) {
      final pending = _pending;
      await pending;
      if (identical(pending, _pending)) break;
    }
    return !_reset &&
        _persistedRevision >= draft.revision &&
        _failedRevision != draft.revision;
  }

  Future<bool> deleteSentRevision(int revision) async {
    if (_reset) return false;
    await _pending;
    try {
      final deleted = await store.deleteIfRevision(
        scope,
        revision,
        epoch: epoch,
      );
      if (deleted && !_disposed && !_reset && draft.revision == revision) {
        draft = const ProposalDraft();
        status = DraftSaveStatus.empty;
        notifyListeners();
      }
      return deleted;
    } catch (_) {
      return false;
    }
  }

  void _onLocalData() {
    if (_disposed || store.localData.epoch == epoch) return;
    _reset = true;
    draft = const ProposalDraft();
    status = DraftSaveStatus.reset;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    store.localData.removeListener(_onLocalData);
    super.dispose();
  }
}
