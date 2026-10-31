import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_gateway.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';
import 'dart:math';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';

import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/suggested_problem_mapper.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

class ApiNextProblemsRepository
    implements
        NextProblemsRepository,
        ProposalFormCapabilities,
        OwnProposalDetails,
        ProposalSubmissionGateway,
        LostProposalScopeRecovery {
  ApiNextProblemsRepository({
    required ApiClient client,
    required String userId,
    String Function()? idempotencyKeyFactory,
    ProposalSessionStore? sessions,
  }) : _client = client,
       _userId = userId,
       _sessions = sessions,
       _idempotencyKeyFactory = idempotencyKeyFactory ?? _defaultIdempotencyKey;

  final ApiClient _client;
  final String _userId;
  final ProposalSessionStore? _sessions;
  final String Function() _idempotencyKeyFactory;

  @override
  Future<SuggestedProblem> getSuggestedProblem({
    required String municipalityId,
    required String problemId,
  }) async {
    if (problemId.isEmpty) {
      throw ApiException.configuration(
        code: 'invalid_problem_id',
        message: 'L’identificativo della proposta è mancante.',
      );
    }
    final path = [..._collectionPath(municipalityId), problemId];
    final lease = await _sessions?.existing();
    final payload = await _client.getJson(
      path,
      headers: lease?.headers ?? const {},
      queryParameters: {
        'userId': lease == null ? _userId : 'session:${lease.submissionScope}',
      },
    );
    if (lease != null) _sessions!.checkLease(lease);
    final problem = SuggestedProblemMapper.fromResponse(payload);
    if (problem.id != problemId ||
        problem.status == SuggestedProblemStatus.rejected) {
      throw ApiException.invalidPayload(
        'Il dettaglio non corrisponde alla proposta pubblica richiesta.',
      );
    }
    return problem;
  }

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) async {
    final path = _collectionPath(municipalityId);
    final lease = await _sessions?.existing();
    final payload = await _client.getJson(
      path,
      headers: lease?.headers ?? const {},
      queryParameters: {
        'query': query?.trim(),
        'status': status?.name,
        'userId': lease == null ? _userId : 'session:${lease.submissionScope}',
      },
    );
    if (lease != null) _sessions!.checkLease(lease);
    return SuggestedProblemMapper.listFromResponse(payload);
  }

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
  }) async {
    return _submit(
      municipalityId: municipalityId,
      title: title,
      description: description,
      category: category,
      location: location,
      idempotencyKey: _idempotencyKeyFactory(),
    );
  }

  @override
  Future<void> prepareProposalForm() async {
    await prepareSubmissionScope();
  }

  @override
  Future<String> prepareSubmissionScope({String? expectedScope}) async {
    final sessions = _sessions;
    if (sessions == null) {
      throw ApiException.configuration(
        code: 'proposal_session_unconfigured',
        message: 'Recupero degli invii non configurato.',
      );
    }
    return (await sessions.active(
      allowCreate: expectedScope == null,
      expectedScope: expectedScope,
    )).submissionScope;
  }

  @override
  Future<SuggestedProblem> submitIntent(ProposalSubmissionIntent intent) =>
      submitWithIdempotencyKey(
        municipalityId: intent.scope.municipalityId,
        title: intent.title,
        description: intent.description,
        category: intent.category,
        location: intent.location,
        idempotencyKey: intent.idempotencyKey,
        submissionScope: intent.submissionScope,
      );

  @override
  Future<SuggestedProblem> lookupIntent(ProposalSubmissionIntent intent) =>
      lookupSubmission(
        municipalityId: intent.scope.municipalityId,
        idempotencyKey: intent.idempotencyKey,
        submissionScope: intent.submissionScope,
      );

  @override
  Future<void> abandonLostScope(String expectedScope) async {
    await _sessions?.abandonLostScope(expectedScope);
  }

  Future<SuggestedProblem> submitWithIdempotencyKey({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
    required String idempotencyKey,
    required String submissionScope,
  }) => _submit(
    municipalityId: municipalityId,
    title: title,
    description: description,
    category: category,
    location: location,
    idempotencyKey: idempotencyKey,
    expectedScope: submissionScope,
  );

  Future<SuggestedProblem> _submit({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
    required String idempotencyKey,
    String? expectedScope,
  }) async {
    final path = _collectionPath(municipalityId);
    final body = <String, Object?>{
      'title': ProposalLimits.text(title, ProposalLimits.title),
      'description': ProposalLimits.text(
        description,
        ProposalLimits.description,
      ),
      'category': category.name,
      if (location != null) 'location': location.toJson(),
    };
    if (!RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9._:-]{7,159}$',
    ).hasMatch(idempotencyKey)) {
      throw ApiException.configuration(
        code: 'invalid_idempotency_key',
        message: 'Chiave di invio non valida.',
      );
    }
    if (expectedScope != null && _sessions == null) {
      throw ApiException.configuration(
        code: 'proposal_session_unconfigured',
        message: 'Recupero degli invii non configurato.',
      );
    }
    final lease = await _sessions?.active(
      allowCreate: expectedScope == null,
      expectedScope: expectedScope,
    );
    if (lease != null) _sessions!.checkLease(lease);
    final payload = await _client.postJson(
      path,
      headers: {'Idempotency-Key': idempotencyKey, ...?lease?.headers},
      body: {
        ...body,
        'userId': lease == null ? _userId : 'session:${lease.submissionScope}',
      },
    );
    if (lease != null) _sessions!.checkLease(lease);
    return SuggestedProblemMapper.fromResponse(payload);
  }

  Future<SuggestedProblem> lookupSubmission({
    required String municipalityId,
    required String idempotencyKey,
    required String submissionScope,
  }) async {
    final collection = _collectionPath(municipalityId);
    final sessions = _sessions;
    if (sessions == null) {
      throw ApiException.configuration(
        code: 'proposal_session_unconfigured',
        message: 'Recupero degli invii non configurato.',
      );
    }
    final lease = await sessions.active(expectedScope: submissionScope);
    final payload = await _client.getJson([
      ...collection.take(3),
      'submissions',
      idempotencyKey,
    ], headers: lease.headers);
    sessions.checkLease(lease);
    return SuggestedProblemMapper.fromResponse(payload);
  }

  @override
  Future<SuggestedProblem> getOwnSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required String submissionScope,
  }) async {
    final collection = _collectionPath(municipalityId);
    final sessions = _sessions;
    if (sessions == null) {
      throw ApiException.configuration(
        code: 'proposal_session_unconfigured',
        message: 'Recupero degli invii non configurato.',
      );
    }
    final lease = await sessions.active(expectedScope: submissionScope);
    final payload = await _client.getJson([
      ...collection,
      problemId,
      'own',
    ], headers: lease.headers);
    sessions.checkLease(lease);
    final problem = SuggestedProblemMapper.fromResponse(payload);
    if (problem.id != problemId) {
      throw ApiException.invalidPayload('Dettaglio di un’altra proposta.');
    }
    return problem;
  }

  @override
  Future<SuggestedProblem> voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) async {
    if (vote == VoteChoice.none) {
      throw ApiException.configuration(
        code: 'invalid_vote',
        message: 'Il backend accetta solo voti up o down.',
      );
    }
    final path = [..._collectionPath(municipalityId), problemId, 'votes'];
    final lease = await _sessions?.active(allowCreate: true);
    final payload = await _client.postJson(
      path,
      headers: {
        'Idempotency-Key': _idempotencyKeyFactory(),
        ...?lease?.headers,
      },
      body: {
        'vote': vote.name,
        'userId': lease == null ? _userId : 'session:${lease.submissionScope}',
      },
    );
    if (lease != null) _sessions!.checkLease(lease);
    return SuggestedProblemMapper.fromResponse(payload);
  }

  List<String> _collectionPath(String municipalityId) {
    final apiId = MunicipalityCatalog.apiIdFor(municipalityId);
    if (apiId == null) {
      throw ApiException.configuration(
        code: 'unsupported_municipality',
        message: 'Il Comune selezionato non e\' ancora disponibile via API.',
      );
    }
    return ['v1', 'municipalities', apiId, 'next-problems'];
  }
}

final Random _idempotencyRandom = Random.secure();

String _defaultIdempotencyKey() {
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final random = _idempotencyRandom.nextInt(0x7fffffff).toRadixString(36);
  return 'flutter-$timestamp-$random';
}
