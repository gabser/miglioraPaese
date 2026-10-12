import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_gateway.dart';
import 'package:fanta_comune/features/next_problems/data/suggested_problem_mapper.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

/// The browser owns the HttpOnly cookie. Only its opaque continuity marker
/// reaches Dart; it is never used as an identity or authorization credential.
class ApiNextProblemsRepository
    implements
        NextProblemsRepository,
        ProposalFormCapabilities,
        OwnProposalDetails,
        ProposalSubmissionGateway {
  ApiNextProblemsRepository({required ApiClient client, LocalDataStore? data})
    : _client = client,
      _data = data;
  final ApiClient _client;
  final LocalDataStore? _data;
  String? _municipality;
  int _generation = 0;
  bool _resetBlocked = false;
  String? _resetNamespace;

  void beginReset() {
    _resetBlocked = true;
    _resetNamespace = _data?.namespace;
    _generation++;
  }

  int _lease() {
    if (_resetBlocked && _data != null && _data.namespace != _resetNamespace) {
      _resetBlocked = false;
    }
    if (_resetBlocked || (_data?.resetting ?? false)) {
      throw const LocalDataResetException();
    }
    // A failed local reset or corrupted storage must also block operations.
    _data?.read('proposal-reset-barrier');
    return _generation;
  }

  void _check(int generation, int? epoch) {
    _lease();
    if (generation != _generation || epoch != _data?.epoch) {
      throw const LocalDataResetException();
    }
  }

  List<String> _collectionPath(String municipalityId) {
    final id = MunicipalityCatalog.apiIdFor(municipalityId);
    if (id == null)
      throw ApiException.configuration(
        code: 'unsupported_municipality',
        message: 'Il Comune selezionato non è ancora disponibile via API.',
      );
    return ['v1', 'municipalities', id, 'next-problems'];
  }

  String _scope(Object? payload) {
    if (payload is! Map<String, dynamic> ||
        payload['submissionScope'] is! String ||
        (payload['submissionScope'] as String).isEmpty) {
      throw ApiException.invalidPayload('Scope server non valido.');
    }
    return payload['submissionScope'] as String;
  }

  void _expected(Object? payload, String? expected) {
    if (expected != null && _scope(payload) != expected) {
      throw ApiException.configuration(
        code: 'proposal_scope_changed',
        message: 'La sessione attuale non appartiene a questo invio.',
      );
    }
  }

  @override
  Future<String> prepareSubmissionScope({
    String? expectedScope,
    String? municipalityId,
  }) async {
    final municipality = municipalityId ?? _municipality;
    if (municipality == null)
      throw ApiException.configuration(
        code: 'unsupported_municipality',
        message: 'Scegli il Comune prima di inviare.',
      );
    final generation = _lease(), epoch = _data?.epoch;
    final payload = await _client.getJson(_collectionPath(municipality));
    _check(generation, epoch);
    if (payload is! Map<String, dynamic> ||
        payload['capabilities'] is! Map ||
        (payload['capabilities'] as Map)['proposalSubmission'] != 1) {
      throw ApiException.configuration(
        code: 'proposal_capabilities_missing',
        message: 'Questo server non supporta ancora l’invio recuperabile.',
      );
    }
    _expected(payload, expectedScope);
    _municipality = municipality;
    return _scope(payload);
  }

  @override
  Future<void> prepareProposalForm() async {
    await prepareSubmissionScope();
  }

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) async {
    final generation = _lease(), epoch = _data?.epoch;
    final payload = await _client.getJson(
      _collectionPath(municipalityId),
      queryParameters: {'query': query?.trim(), 'status': status?.name},
    );
    _check(generation, epoch);
    _municipality = municipalityId;
    return SuggestedProblemMapper.listFromResponse(payload);
  }

  @override
  Future<SuggestedProblem> getSuggestedProblem({
    required String municipalityId,
    required String problemId,
  }) async {
    final generation = _lease(), epoch = _data?.epoch;
    final payload = await _client.getJson([
      ..._collectionPath(municipalityId),
      problemId,
    ]);
    _check(generation, epoch);
    final problem = SuggestedProblemMapper.fromResponse(payload);
    if (problem.id != problemId)
      throw ApiException.invalidPayload('Dettaglio di un’altra proposta.');
    return problem;
  }

  @override
  Future<SuggestedProblem> getOwnSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required String submissionScope,
  }) async {
    final generation = _lease(), epoch = _data?.epoch;
    await prepareSubmissionScope(
      municipalityId: municipalityId,
      expectedScope: submissionScope,
    );
    final payload = await _client.getJson(
      _collectionPath(municipalityId),
      queryParameters: {'own': 'true'},
    );
    _check(generation, epoch);
    _expected(payload, submissionScope);
    final own = SuggestedProblemMapper.listFromResponse(payload);
    for (final item in own) {
      if (item.id == problemId) return item;
    }
    throw const ApiException(
      kind: ApiExceptionKind.response,
      statusCode: 404,
      code: 'not_found',
      message: 'Proposta non trovata.',
    );
  }

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
  }) async {
    // Legacy interface remains compatible. Recoverable UI exclusively uses
    // submitIntent after persisting the command through its coordinator.
    final generation = _lease(), epoch = _data?.epoch;
    final payload = await _client.postJson(
      _collectionPath(municipalityId),
      body: {
        'title': title,
        'description': description,
        'category': category.name,
        if (location != null) 'location': location.toJson(),
      },
    );
    _check(generation, epoch);
    return SuggestedProblemMapper.fromResponse(payload);
  }

  @override
  Future<SuggestedProblem> submitIntent(ProposalSubmissionIntent intent) async {
    final generation = _lease(), epoch = _data?.epoch;
    await prepareSubmissionScope(
      municipalityId: intent.scope.municipalityId,
      expectedScope: intent.submissionScope,
    );
    final payload = await _client.postJson(
      _collectionPath(intent.scope.municipalityId),
      body: {
        ...intent.payload,
        'idempotencyKey': intent.idempotencyKey,
        'expectedSubmissionScope': intent.submissionScope,
      },
    );
    _check(generation, epoch);
    _expected(payload, intent.submissionScope);
    return SuggestedProblemMapper.fromResponse(payload);
  }

  @override
  Future<SuggestedProblem> lookupIntent(ProposalSubmissionIntent intent) async {
    final generation = _lease(), epoch = _data?.epoch;
    await prepareSubmissionScope(
      municipalityId: intent.scope.municipalityId,
      expectedScope: intent.submissionScope,
    );
    final collection = _collectionPath(intent.scope.municipalityId);
    final payload = await _client.getJson([
      ...collection.take(3),
      'next-problem-submissions',
      intent.idempotencyKey,
    ]);
    _check(generation, epoch);
    _expected(payload, intent.submissionScope);
    return SuggestedProblemMapper.fromResponse(
      (payload as Map<String, dynamic>)['receipt'],
    );
  }

  @override
  Future<SuggestedProblem> voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) async {
    if (vote == VoteChoice.none)
      throw ApiException.configuration(
        code: 'invalid_vote',
        message: 'Il backend accetta solo voti up o down.',
      );
    final generation = _lease(), epoch = _data?.epoch;
    final payload = await _client.postJson(
      [..._collectionPath(municipalityId), problemId, 'votes'],
      body: {'vote': vote.name},
    );
    _check(generation, epoch);
    return SuggestedProblemMapper.fromResponse(payload);
  }
}
