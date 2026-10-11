import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';

class ProposalSubmissionStore {
  ProposalSubmissionStore(this.data);
  final LocalDataStore data;
  String _key(ProposalScope scope) => 'submissions:${scope.key}';

  List<ProposalSubmissionIntent> _decode(Object? raw, ProposalScope scope) {
    if (raw == null) return const [];
    if (raw is! Map<String, dynamic> ||
        raw['version'] != 1 ||
        raw.length != 2 ||
        raw['items'] is! List) {
      throw const LocalDataCorruptException();
    }
    try {
      final items = (raw['items'] as List)
          .map(ProposalSubmissionIntent.fromJson)
          .toList();
      if (items.any((item) => item.scope != scope) ||
          items.map((item) => item.idempotencyKey).toSet().length !=
              items.length ||
          items.where((item) => item.unresolved).length > 1) {
        throw const LocalDataCorruptException();
      }
      return List.unmodifiable(items);
    } catch (_) {
      throw const LocalDataCorruptException();
    }
  }

  List<ProposalSubmissionIntent> history(ProposalScope scope) =>
      _decode(data.read(_key(scope)), scope);
  ProposalSubmissionIntent? pending(ProposalScope scope) {
    for (final item in history(scope).reversed) {
      if (item.unresolved) return item;
    }
    return null;
  }

  Future<void> create(ProposalSubmissionIntent intent, {required int epoch}) =>
      data.mutate(_key(intent.scope), (raw) {
        final items = _decode(raw, intent.scope);
        if (intent.scope.namespace != data.namespace ||
            intent.phase != SubmissionPhase.prepared ||
            items.any(
              (item) =>
                  item.unresolved ||
                  item.idempotencyKey == intent.idempotencyKey,
            )) {
          throw const LocalDataWriteException();
        }
        return LocalDataMutation({
          'version': 1,
          'items': [...items.map((item) => item.toJson()), intent.toJson()],
        }, null);
      }, expectedEpoch: epoch);

  Future<ProposalSubmissionIntent> save(
    ProposalSubmissionIntent intent, {
    required int epoch,
  }) => data.mutate(_key(intent.scope), (raw) {
    final items = _decode(raw, intent.scope).toList();
    final index = items.indexWhere(
      (item) => item.idempotencyKey == intent.idempotencyKey,
    );
    if (index < 0 || items[index].fingerprint != intent.fingerprint)
      throw const LocalDataWriteException();
    final prior = items[index];
    // A slower lookup/error cannot undo a committed receipt or an explicit abandonment.
    if (!prior.unresolved) return LocalDataMutation(raw, prior);
    items[index] = intent;
    return LocalDataMutation({
      'version': 1,
      'items': items.map((item) => item.toJson()).toList(),
    }, intent);
  }, expectedEpoch: epoch);
}
