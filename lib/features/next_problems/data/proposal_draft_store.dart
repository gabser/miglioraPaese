import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_draft.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';

class ProposalDraftStore {
  ProposalDraftStore(this.localData);
  final LocalDataStore localData;
  String _key(ProposalScope scope) => 'draft:${scope.key}';

  int nextRevision(ProposalScope scope, int minimum) =>
      localData.reserveRevision(_key(scope), minimum);

  ProposalDraft? load(ProposalScope scope) {
    final value = localData.read(_key(scope));
    if (value == null) return null;
    try {
      return ProposalDraft.fromJson(value);
    } catch (_) {
      throw const LocalDataCorruptException();
    }
  }

  Future<ProposalDraft> save(
    ProposalScope scope,
    ProposalDraft draft, {
    required int epoch,
  }) => localData.mutate(_key(scope), (value) {
    final current = value == null ? null : ProposalDraft.fromJson(value);
    if (current != null && current.revision > draft.revision) {
      throw const LocalDataWriteException();
    }
    return LocalDataMutation(draft.toJson(), draft);
  }, expectedEpoch: epoch);

  Future<bool> deleteIfRevision(
    ProposalScope scope,
    int revision, {
    required int epoch,
  }) => localData.mutate(_key(scope), (value) {
    final current = value == null ? null : ProposalDraft.fromJson(value);
    final matches = current?.revision == revision;
    return LocalDataMutation(matches ? null : value, matches);
  }, expectedEpoch: epoch);
}
