import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_gateway.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';

enum SubmissionStatus {
  idle,
  preparing,
  sending,
  checking,
  outcomeUnknown,
  succeeded,
  rejected,
  scopeLost,
  storageFailed,
  receiptUnsaved,
  cooldown,
  reset,
}

class SubmissionView {
  const SubmissionView(
    this.status, {
    this.intent,
    this.message,
    this.fieldErrors = const {},
  });
  final Map<String, String> fieldErrors;
  final SubmissionStatus status;
  final ProposalSubmissionIntent? intent;
  final String? message;
  bool get busy =>
      status == SubmissionStatus.preparing ||
      status == SubmissionStatus.sending ||
      status == SubmissionStatus.checking;
  bool get blocksNew =>
      busy ||
      intent?.unresolved == true ||
      status == SubmissionStatus.receiptUnsaved;
}

/// Owned by app dependencies. Routes observe operations rather than owning them.
class ProposalSubmissionCoordinator extends ChangeNotifier {
  ProposalSubmissionCoordinator({
    required this.store,
    required this.drafts,
    required this.gateway,
    required this.isMock,
    DateTime Function()? clock,
    String Function()? keyFactory,
  }) : _clock = clock ?? DateTime.now,
       _keyFactory = keyFactory ?? (() => 'proposal-${newLocalId()}'),
       _epoch = store.data.epoch {
    store.data.addListener(_onData);
  }
  Duration? mockCooldownRemaining(ProposalScope scope) {
    if (!isMock || !_valid(scope, store.data.epoch)) return null;
    try {
      final accepted =
          store
              .history(scope)
              .map((item) => item.acceptedAt)
              .whereType<DateTime>()
              .toList()
            ..sort();
      if (accepted.isEmpty) return null;
      final remaining = accepted.last
          .add(const Duration(minutes: 5))
          .difference(_clock());
      return remaining > Duration.zero ? remaining : null;
    } catch (_) {
      return null;
    } // Storage errors are surfaced by the submission state.
  }

  final ProposalSubmissionStore store;
  final ProposalDraftStore drafts;
  final ProposalSubmissionGateway gateway;
  final bool isMock;
  final DateTime Function() _clock;
  final String Function() _keyFactory;
  final Map<String, SubmissionView> _views = {};
  final Set<String> _busy = {};
  int _epoch;
  bool _disposed = false;

  /// Reads accepted snapshots independently of later attempts and list filters.
  /// No session bootstrap, lookup or POST is performed by receipt navigation.
  SubmissionView savedReceipt(ProposalScope scope, {String? problemId}) {
    if (scope.namespace != store.data.namespace || store.data.resetting) {
      return const SubmissionView(SubmissionStatus.reset);
    }
    try {
      for (final intent in store.history(scope).reversed) {
        if (intent.phase == SubmissionPhase.succeeded &&
            (problemId == null || intent.receipt!.id == problemId)) {
          return SubmissionView(SubmissionStatus.succeeded, intent: intent);
        }
      }
      return const SubmissionView(SubmissionStatus.idle);
    } catch (_) {
      return const SubmissionView(
        SubmissionStatus.storageFailed,
        message:
            'Le ricevute salvate su questo dispositivo non sono leggibili.',
      );
    }
  }

  SubmissionView current(ProposalScope scope) {
    if (scope.namespace != store.data.namespace || store.data.resetting) {
      return const SubmissionView(SubmissionStatus.reset);
    }
    final cached = _views[scope.key];
    if (cached != null) return cached;
    try {
      final history = store.history(scope);
      if (history.isEmpty) return const SubmissionView(SubmissionStatus.idle);
      final record = history.last;
      return _fromRecord(record);
    } catch (_) {
      return const SubmissionView(
        SubmissionStatus.storageFailed,
        message:
            'Lo storico locale non è leggibile. Non inviare di nuovo prima di averlo recuperato o azzerato.',
      );
    }
  }

  SubmissionView _fromRecord(ProposalSubmissionIntent record) => SubmissionView(
    switch (record.phase) {
      SubmissionPhase.prepared ||
      SubmissionPhase.outcomeUnknown => SubmissionStatus.outcomeUnknown,
      SubmissionPhase.succeeded => SubmissionStatus.succeeded,
      SubmissionPhase.rejected => SubmissionStatus.rejected,
      SubmissionPhase.scopeLost => SubmissionStatus.scopeLost,
      SubmissionPhase.abandoned => SubmissionStatus.idle,
    },
    intent: record,
    message: record.unresolved
        ? 'L’esito dell’invio è da verificare. La proposta potrebbe essere già stata ricevuta.'
        : null,
  );

  void _publish(ProposalScope scope, SubmissionView value) {
    _views[scope.key] = value;
    if (!_disposed) notifyListeners();
  }

  bool _valid(ProposalScope scope, int epoch) =>
      epoch == store.data.epoch &&
      scope.namespace == store.data.namespace &&
      !store.data.resetting;

  /// Checking an unresolved intent cannot create a replacement server session.
  Future<void> prepareForm(ProposalScope scope) async {
    final epoch = store.data.epoch;
    final pending = store.pending(scope);
    try {
      await gateway.prepareSubmissionScope(
        expectedScope: pending?.submissionScope,
        municipalityId: scope.municipalityId,
      );
      if (!_valid(scope, epoch)) throw const LocalDataResetException();
    } catch (error) {
      if (pending != null && _valid(scope, epoch) && _scopeLost(error)) {
        await _failure(pending, error, epoch, lookup: true);
      }
      rethrow;
    }
  }

  Future<SubmissionView> start({
    required ProposalScope scope,
    required int draftRevision,
    required String title,
    required String description,
    required ProblemKey category,
    required ProposalLocation location,
  }) async {
    if (_busy.contains(scope.key)) return current(scope);
    final epoch = store.data.epoch;
    if (!_valid(scope, epoch))
      return const SubmissionView(SubmissionStatus.reset);
    final view = current(scope);
    if (view.blocksNew) return view;
    _busy.add(scope.key);
    _publish(scope, const SubmissionView(SubmissionStatus.preparing));
    ProposalSubmissionIntent? intent;
    try {
      // Verify storage/history before even attempting a bootstrap request.
      final history = store.history(scope);
      final unresolved = history.where((item) => item.unresolved);
      if (unresolved.isNotEmpty) {
        final result = _fromRecord(unresolved.single);
        _publish(scope, result);
        return result;
      }
      if (isMock &&
          history.any(
            (item) =>
                item.acceptedAt != null &&
                _clock().difference(item.acceptedAt!) <
                    const Duration(minutes: 5),
          )) {
        final result = const SubmissionView(
          SubmissionStatus.cooldown,
          message:
              'In questo Comune puoi proporre di nuovo dopo cinque minuti.',
        );
        _publish(scope, result);
        return result;
      }
      final submissionScope = await gateway.prepareSubmissionScope(
        municipalityId: scope.municipalityId,
      );
      if (!_valid(scope, epoch))
        return const SubmissionView(SubmissionStatus.reset);
      intent = ProposalSubmissionIntent(
        scope: scope,
        idempotencyKey: _keyFactory(),
        submissionScope: submissionScope,
        draftRevision: draftRevision,
        createdAt: _clock(),
        title: title,
        description: description,
        category: category,
        location: location,
      );
      await store.create(intent, epoch: epoch);
      if (!_valid(scope, epoch))
        return const SubmissionView(SubmissionStatus.reset);
      return await _request(intent, epoch, lookup: false);
    } catch (error) {
      if (!_valid(scope, epoch))
        return const SubmissionView(SubmissionStatus.reset);
      // No POST occurred: an intent write failure must not promise a saved marker.
      final result = SubmissionView(
        SubmissionStatus.storageFailed,
        message: error is ApiException
            ? 'Il servizio non è disponibile. La bozza resta qui.'
            : 'Non riesco a salvare l’intento. Nessuna proposta è stata inviata.',
      );
      _publish(scope, result);
      return result;
    } finally {
      _busy.remove(scope.key);
    }
  }

  /// A refresh only restores state. This explicit action performs a GET lookup.
  Future<SubmissionView> reconcile(ProposalScope scope) =>
      _resume(scope, lookup: true);
  Future<SubmissionView> retry(ProposalScope scope) =>
      _resume(scope, lookup: false);

  Future<SubmissionView> _resume(
    ProposalScope scope, {
    required bool lookup,
  }) async {
    if (_busy.contains(scope.key)) return current(scope);
    final epoch = store.data.epoch;
    if (!_valid(scope, epoch))
      return const SubmissionView(SubmissionStatus.reset);
    final view = current(scope);
    final intent = view.intent;
    if (intent == null ||
        !intent.unresolved ||
        view.status == SubmissionStatus.receiptUnsaved ||
        (!lookup && intent.phase == SubmissionPhase.scopeLost))
      return view;
    _busy.add(scope.key);
    try {
      return await _request(intent, epoch, lookup: lookup);
    } finally {
      _busy.remove(scope.key);
    }
  }

  Future<SubmissionView> _request(
    ProposalSubmissionIntent intent,
    int epoch, {
    required bool lookup,
  }) async {
    _publish(
      intent.scope,
      SubmissionView(
        lookup ? SubmissionStatus.checking : SubmissionStatus.sending,
        intent: intent,
      ),
    );
    try {
      final problem = await (lookup
          ? gateway.lookupIntent(intent)
          : gateway.submitIntent(intent));
      if (!_valid(intent.scope, epoch))
        return const SubmissionView(SubmissionStatus.reset);
      if (!intent.matches(problem))
        throw ApiException.invalidPayload(
          'Risposta non corrispondente all’intento.',
        );
      return await _accept(intent, problem, epoch);
    } catch (error) {
      if (!_valid(intent.scope, epoch))
        return const SubmissionView(SubmissionStatus.reset);
      return _failure(intent, error, epoch, lookup: lookup);
    }
  }

  Future<SubmissionView> _accept(
    ProposalSubmissionIntent intent,
    SuggestedProblem problem,
    int epoch,
  ) async {
    final accepted = intent.withOutcome(
      SubmissionPhase.succeeded,
      receipt: problem,
      acceptedAt: intent.acceptedAt ?? _clock(),
    );
    try {
      final saved = await store.save(accepted, epoch: epoch);
      if (!_valid(intent.scope, epoch))
        return const SubmissionView(SubmissionStatus.reset);
      if (saved.phase != SubmissionPhase.succeeded) {
        final result = _fromRecord(saved);
        _publish(intent.scope, result);
        return result;
      }
      String? warning;
      try {
        await drafts.deleteIfRevision(
          intent.scope,
          intent.draftRevision,
          epoch: epoch,
        );
      } catch (_) {
        warning = 'Proposta ricevuta. La bozza locale non è stata rimossa.';
      }
      if (!_valid(intent.scope, epoch))
        return const SubmissionView(SubmissionStatus.reset);
      final result = SubmissionView(
        SubmissionStatus.succeeded,
        intent: saved,
        message: warning,
      );
      _publish(intent.scope, result);
      return result;
    } catch (_) {
      if (!_valid(intent.scope, epoch))
        return const SubmissionView(SubmissionStatus.reset);
      final result = SubmissionView(
        SubmissionStatus.receiptUnsaved,
        intent: accepted,
        message:
            'Il servizio ha ricevuto la proposta, ma la conferma non è salvata qui. Riprova il salvataggio, senza inviare di nuovo.',
      );
      _publish(intent.scope, result);
      return result;
    }
  }

  Future<SubmissionView> persistReceipt(ProposalScope scope) async {
    if (_busy.contains(scope.key)) return current(scope);
    final view = current(scope);
    if (view.status != SubmissionStatus.receiptUnsaved ||
        view.intent?.receipt == null)
      return view;
    _busy.add(scope.key);
    try {
      return await _accept(
        view.intent!,
        view.intent!.receipt!,
        store.data.epoch,
      );
    } finally {
      _busy.remove(scope.key);
    }
  }

  bool _scopeLost(Object error) =>
      error is LocalDataCorruptException ||
      error is ApiException &&
          (error.statusCode == 401 ||
              error.code == 'proposal_scope_missing' ||
              error.code == 'proposal_scope_changed' ||
              error.code == 'idempotency_conflict' ||
              error.code == 'submission_scope_changed');

  Future<SubmissionView> _failure(
    ProposalSubmissionIntent intent,
    Object error,
    int epoch, {
    required bool lookup,
  }) async {
    final lost = _scopeLost(error);
    final rejected =
        !lookup &&
        !lost &&
        error is ApiException &&
        error.kind == ApiExceptionKind.response &&
        error.statusCode != null &&
        error.statusCode! >= 400 &&
        error.statusCode! < 500;
    final record = intent.withOutcome(
      lost
          ? SubmissionPhase.scopeLost
          : rejected
          ? SubmissionPhase.rejected
          : SubmissionPhase.outcomeUnknown,
      errorCode: error is ApiException ? error.code : 'outcome_unknown',
    );
    var message = lost
        ? 'La sessione dell’invio non è più verificabile. Non inviare automaticamente una nuova proposta.'
        : rejected
        ? error.statusCode == 422
              ? 'Rivedi il testo: evita contatti personali, link e linguaggio offensivo. La bozza resta disponibile.'
              : error.statusCode == 429
              ? 'Hai raggiunto il limite di invii per questo Comune.${error.retryAfterSeconds == null ? '' : ' Riprova tra almeno ${error.retryAfterSeconds} secondi.'} La bozza resta disponibile.'
              : 'Il servizio ha rifiutato questo invio. La bozza resta disponibile.'
        : 'Esito non confermato: la proposta potrebbe essere già ricevuta. Verifica l’invio prima di riprovare.';
    ProposalSubmissionIntent saved = record;
    try {
      saved = await store.save(record, epoch: epoch);
    } catch (_) {
      message += ' Non riesco ad aggiornare lo storico locale.';
    }
    if (!_valid(intent.scope, epoch))
      return const SubmissionView(SubmissionStatus.reset);
    final status = saved.phase == SubmissionPhase.succeeded
        ? SubmissionStatus.succeeded
        : saved.phase == SubmissionPhase.abandoned
        ? SubmissionStatus.idle
        : lost
        ? SubmissionStatus.scopeLost
        : rejected
        ? SubmissionStatus.rejected
        : SubmissionStatus.outcomeUnknown;
    final result = SubmissionView(
      status,
      intent: saved,
      message: message,
      fieldErrors: rejected ? error.fieldErrors : const {},
    );
    _publish(intent.scope, result);
    return result;
  }

  /// Caller must obtain an explicit, informed user action before abandoning.
  Future<SubmissionView> abandon(ProposalScope scope) async {
    if (_busy.contains(scope.key)) return current(scope);
    final epoch = store.data.epoch;
    final view = current(scope);
    if (view.intent == null ||
        !view.intent!.unresolved ||
        view.status == SubmissionStatus.receiptUnsaved)
      return view;
    _busy.add(scope.key);
    try {
      final saved = await store.save(
        view.intent!.withOutcome(SubmissionPhase.abandoned),
        epoch: epoch,
      );
      String? warning;
      if (view.status == SubmissionStatus.scopeLost &&
          gateway is LostProposalScopeRecovery) {
        try {
          await (gateway as LostProposalScopeRecovery).abandonLostScope(
            view.intent!.submissionScope,
          );
        } catch (_) {
          warning =
              'Verifica abbandonata. Non riesco a recuperare la sessione: riprova la verifica del servizio prima di un nuovo invio.';
          // Abandonment remains recorded; no automatic POST or token replacement.
        }
      }
      if (!_valid(scope, epoch))
        return const SubmissionView(SubmissionStatus.reset);
      final restored = _fromRecord(saved);
      final result = SubmissionView(
        restored.status,
        intent: saved,
        message: warning,
      );
      _publish(scope, result);
      return result;
    } catch (_) {
      final result = SubmissionView(
        view.status,
        intent: view.intent,
        message:
            'Non riesco a salvare l’abbandono. L’invio resta da verificare.',
      );
      if (_valid(scope, epoch)) _publish(scope, result);
      return result;
    } finally {
      _busy.remove(scope.key);
    }
  }

  void _onData() {
    if (_epoch == store.data.epoch) return;
    _epoch = store.data.epoch;
    _views.clear();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    store.data.removeListener(_onData);
    super.dispose();
  }
}
