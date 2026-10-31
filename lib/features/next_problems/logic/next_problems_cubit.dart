import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import 'package:fanta_comune/features/next_problems/logic/next_problems_state.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';

enum VoteOutcome { succeeded, failed, ignored }

class NextProblemsCubit extends Cubit<NextProblemsState> {
  NextProblemsCubit({
    required this.repository,
    required this.prefs,
    String? municipalityId,
    this.searchDebounce = const Duration(milliseconds: 300),
  }) : super(
         NextProblemsState(
           municipalityId: ProposalRouteContext.fromPreference(
             municipalityId ?? prefs.municipalityId,
           ).municipalityId,
         ),
       ) {
    _epoch = prefs.localData.epoch;
    prefs.localData.addListener(_onLocalDataChanged);
  }

  final NextProblemsRepository repository;
  final AppPrefs prefs;
  final Duration searchDebounce;
  Timer? _searchTimer;
  int _loadVersion = 0;
  int _scopeVersion = 0;
  late int _epoch;

  Future<void> setMunicipality(String? value) async {
    _searchTimer?.cancel();
    _scopeVersion++;
    _loadVersion++;
    emit(
      NextProblemsState(
        municipalityId: ProposalRouteContext.fromPreference(
          value,
        ).municipalityId,
      ),
    );
    await load();
  }

  void _onLocalDataChanged() {
    if (isClosed || _epoch == prefs.localData.epoch) return;
    _epoch = prefs.localData.epoch;
    unawaited(setMunicipality(null));
  }

  bool _isCurrentScope(int version, int epoch) =>
      !isClosed && version == _scopeVersion && epoch == prefs.localData.epoch;

  Future<void> load() async {
    final requestVersion = ++_loadVersion;
    final scopeVersion = _scopeVersion;
    final epoch = prefs.localData.epoch;
    final municipality = state.municipalityId;
    if (municipality == null) {
      emit(
        state.copyWith(
          isLoading: false,
          items: const [],
          error: 'Scegli un Comune prima di vedere le proposte.',
        ),
      );
      return;
    }
    final query = state.query.trim();
    final filterStatus = state.filterStatus;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final items = await repository.listNextProblems(
        municipalityId: municipality,
        query: query.isEmpty ? null : query,
        status: filterStatus,
      );
      if (!_isCurrentScope(scopeVersion, epoch) ||
          requestVersion != _loadVersion) {
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          items: _sorted(items, state.sortMode),
          error: null,
        ),
      );
    } catch (error) {
      if (!_isCurrentScope(scopeVersion, epoch) ||
          requestVersion != _loadVersion) {
        return;
      }
      emit(state.copyWith(isLoading: false, error: _userMessageFor(error)));
    }
  }

  Future<void> refresh() async {
    _searchTimer?.cancel();
    await load();
  }

  void setQuery(String value) {
    _searchTimer?.cancel();
    _loadVersion++;
    emit(state.copyWith(query: value, error: null));
    _searchTimer = Timer(searchDebounce, () {
      if (!isClosed) unawaited(load());
    });
  }

  void setFilterStatus(SuggestedProblemStatus? status) {
    _searchTimer?.cancel();
    _loadVersion++;
    emit(state.copyWith(filterStatus: status, error: null));
    unawaited(load());
  }

  Future<void> clearFilters() async {
    _searchTimer?.cancel();
    _loadVersion++;
    emit(state.copyWith(query: '', filterStatus: null, error: null));
    await load();
  }

  void setSortMode(NextProblemsSortMode mode) {
    emit(state.copyWith(sortMode: mode, items: _sorted(state.items, mode)));
  }

  Future<VoteOutcome> vote(String problemId, VoteChoice vote) async {
    final municipality = state.municipalityId;
    if (municipality == null ||
        !state.items.any((item) => item.id == problemId)) {
      return VoteOutcome.ignored;
    }
    final scopeVersion = _scopeVersion;
    final epoch = prefs.localData.epoch;
    if (state.votingProblemIds.contains(problemId)) return VoteOutcome.ignored;
    final updatedVoting = {...state.votingProblemIds, problemId};
    emit(state.copyWith(votingProblemIds: updatedVoting, voteError: null));
    try {
      final updated = await repository.voteSuggestedProblem(
        municipalityId: municipality,
        problemId: problemId,
        vote: vote,
      );
      if (!_isCurrentScope(scopeVersion, epoch)) return VoteOutcome.ignored;
      final nextItems = state.items
          .map((item) => item.id == updated.id ? updated : item)
          .toList(growable: false);
      emit(
        state.copyWith(
          items: _sorted(nextItems, state.sortMode),
          votingProblemIds: _withoutProblemId(problemId),
          error: null,
        ),
      );
      return VoteOutcome.succeeded;
    } catch (error) {
      if (!_isCurrentScope(scopeVersion, epoch)) return VoteOutcome.ignored;
      emit(
        state.copyWith(
          voteError:
              error is ApiException && error.kind == ApiExceptionKind.network
              ? 'Il voto non è stato registrato. Controlla la connessione e riprova.'
              : 'Il voto non è stato registrato. Puoi riprovare.',
          votingProblemIds: _withoutProblemId(problemId),
        ),
      );
      return VoteOutcome.failed;
    }
  }

  Future<void> prepareProposalForm() async {
    final source = repository;
    if (source is! ProposalFormCapabilities) {
      throw ApiException.configuration(
        code: 'proposal_capabilities_missing',
        message: 'Il repository non supporta il nuovo percorso proposte.',
      );
    }
    await (source as ProposalFormCapabilities).prepareProposalForm();
  }

  /// Legacy compatibility helper. The application form uses the app-scoped
  /// ProposalSubmissionCoordinator for persisted intent and recoverable writes.
  Future<String?> submit({
    required String title,
    required String description,
    required ProblemKey category,
    String? municipalityId,
    ProposalLocation? location,
  }) async {
    final municipality = ProposalRouteContext.fromPreference(
      municipalityId ?? state.municipalityId,
    ).municipalityId;
    if (municipality == null) return 'municipality_required';
    final scopeVersion = _scopeVersion;
    final epoch = prefs.localData.epoch;
    emit(state.copyWith(submitting: true, error: null));
    try {
      await repository.submitSuggestedProblem(
        municipalityId: municipality,
        title: title,
        description: description,
        category: category,
        location: location,
      );
      if (!_isCurrentScope(scopeVersion, epoch)) return 'scope_changed';
      emit(state.copyWith(submitting: false));
      return null;
    } catch (error) {
      if (!_isCurrentScope(scopeVersion, epoch)) return 'scope_changed';
      emit(state.copyWith(submitting: false, error: _userMessageFor(error)));
      if (_isDuplicateTitle(error)) {
        return 'duplicate_title';
      }
      return 'generic';
    }
  }

  Set<String> _withoutProblemId(String problemId) {
    return Set<String>.from(state.votingProblemIds)..remove(problemId);
  }

  bool _isDuplicateTitle(Object error) {
    return (error is ApiException && error.code == 'duplicate_title') ||
        error.toString().contains('duplicate_title');
  }

  String _userMessageFor(Object error) {
    if (error is ApiException) {
      if (error.code == 'unsupported_municipality' ||
          error.code == 'municipality_not_found') {
        return 'Questo Comune non e\' ancora disponibile online. '
            'Puoi sceglierne un altro dal profilo.';
      }
      if (error.code == 'duplicate_title') {
        return 'Esiste gia\' una proposta con questo titolo.';
      }
      if (error.kind == ApiExceptionKind.timeout) {
        return 'Il servizio sta impiegando troppo tempo. Riprova tra poco.';
      }
      if (error.kind == ApiExceptionKind.network) {
        return 'Non riusciamo a raggiungere il servizio. '
            'Controlla la connessione e riprova.';
      }
    }
    return 'Non siamo riusciti a caricare i temi. Riprova tra poco.';
  }

  @override
  Future<void> close() {
    prefs.localData.removeListener(_onLocalDataChanged);
    _searchTimer?.cancel();
    _loadVersion++;
    return super.close();
  }

  List<SuggestedProblem> _sorted(
    List<SuggestedProblem> items,
    NextProblemsSortMode mode,
  ) {
    final sorted = List<SuggestedProblem>.from(items);
    switch (mode) {
      case NextProblemsSortMode.hot:
        sorted.sort((a, b) => b.score.compareTo(a.score));
      case NextProblemsSortMode.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case NextProblemsSortMode.controversial:
        sorted.sort((a, b) {
          final aTotal = a.votesUp + a.votesDown;
          final bTotal = b.votesUp + b.votesDown;
          final aDiff = (a.votesUp - a.votesDown).abs();
          final bDiff = (b.votesUp - b.votesDown).abs();
          final aScore = aTotal - aDiff;
          final bScore = bTotal - bDiff;
          return bScore.compareTo(aScore);
        });
    }
    return sorted;
  }
}
