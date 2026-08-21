import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/suggested_problem_mapper.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

class ApiNextProblemsRepository implements NextProblemsRepository {
  ApiNextProblemsRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) async {
    final payload = await _client.getJson(
      _collectionPath(municipalityId),
      queryParameters: {'query': query?.trim(), 'status': status?.name},
    );
    return SuggestedProblemMapper.listFromResponse(payload);
  }

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
  }) async {
    final payload = await _client.postJson(
      _collectionPath(municipalityId),
      body: {
        'title': title,
        'description': description,
        'category': category.name,
      },
    );
    return SuggestedProblemMapper.fromResponse(payload);
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
    final payload = await _client.postJson(
      [..._collectionPath(municipalityId), problemId, 'votes'],
      body: {'vote': vote.name},
    );
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
