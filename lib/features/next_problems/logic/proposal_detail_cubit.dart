import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';

enum ProposalDetailStatus {
  loading,
  loaded,
  missing,
  unavailable,
  scopeLost,
  reset,
}

class ProposalDetailState {
  const ProposalDetailState(this.status, {this.problem, this.message});
  final ProposalDetailStatus status;
  final SuggestedProblem? problem;
  final String? message;
}

class ProposalDetailCubit extends Cubit<ProposalDetailState> {
  ProposalDetailCubit({
    required this.repository,
    required this.scope,
    required this.problemId,
    required this.data,
    required this.receipts,
  }) : _epoch = data.epoch,
       super(const ProposalDetailState(ProposalDetailStatus.loading)) {
    data.addListener(_onData);
  }
  final NextProblemsRepository repository;
  final ProposalScope scope;
  final String problemId;
  final LocalDataStore data;
  final ProposalSubmissionCoordinator receipts;
  final int _epoch;
  int _request = 0;

  bool _current(int request) =>
      !isClosed &&
      request == _request &&
      data.epoch == _epoch &&
      scope.namespace == data.namespace &&
      !data.resetting;

  void _onData() {
    if (!isClosed && (data.epoch != _epoch || data.resetting)) {
      _request++;
      emit(
        const ProposalDetailState(
          ProposalDetailStatus.reset,
          message:
              'I dati locali sono stati azzerati. Riapri le proposte per continuare.',
        ),
      );
    }
  }

  Future<void> load() async {
    final request = ++_request;
    if (!_current(request)) return;
    if (!ProposalRouteContext.validProblemId(problemId)) {
      emit(
        const ProposalDetailState(
          ProposalDetailStatus.missing,
          message: 'Proposta non disponibile.',
        ),
      );
      return;
    }
    emit(const ProposalDetailState(ProposalDetailStatus.loading));
    try {
      final saved = receipts.savedReceipt(scope, problemId: problemId);
      if (saved.status == SubmissionStatus.storageFailed) {
        throw const LocalDataCorruptException();
      }
      final own = saved.intent;
      final source = repository;
      final problem = own != null && source is OwnProposalDetails
          ? await (source as OwnProposalDetails).getOwnSuggestedProblem(
              municipalityId: scope.municipalityId,
              problemId: problemId,
              submissionScope: own.submissionScope,
            )
          : await source.getSuggestedProblem(
              municipalityId: scope.municipalityId,
              problemId: problemId,
            );
      if (!_current(request)) return;
      if (problem.id != problemId ||
          (own == null && problem.status == SuggestedProblemStatus.rejected)) {
        throw ApiException.invalidPayload('Dettaglio discordante.');
      }
      emit(ProposalDetailState(ProposalDetailStatus.loaded, problem: problem));
    } catch (error) {
      if (!_current(request)) return;
      final missing = error is ApiException && error.statusCode == 404;
      final lost =
          error is ApiException &&
          (error.statusCode == 401 ||
              const [
                'proposal_scope_changed',
                'proposal_scope_missing',
              ].contains(error.code));
      emit(
        ProposalDetailState(
          missing
              ? ProposalDetailStatus.missing
              : lost
              ? ProposalDetailStatus.scopeLost
              : ProposalDetailStatus.unavailable,
          message: missing
              ? 'Proposta non disponibile per questo Comune.'
              : lost
              ? 'Non è possibile verificare la sessione originale della tua proposta. La ricevuta locale rimane disponibile.'
              : error is LocalDataCorruptException
              ? 'Lo storico locale non è leggibile. Non inviare una nuova proposta per recuperarlo.'
              : 'Il dettaglio aggiornato non è disponibile. Riprova quando la connessione è disponibile.',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _request++;
    data.removeListener(_onData);
    return super.close();
  }
}
