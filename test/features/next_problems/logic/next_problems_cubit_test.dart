import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/promotion_rule.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import 'package:fanta_comune/features/next_problems/logic/next_problems_cubit.dart';

void main() {
  late AppPrefs prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'municipality_id': 'comune:Bologna',
      'user_id': 'user:test',
    });
    prefs = await AppPrefs.init();
  });

  test('can clear a selected status filter', () async {
    final requestedStatuses = <SuggestedProblemStatus?>[];
    final repository = _FakeNextProblemsRepository(
      onList: ({required municipalityId, query, status}) async {
        requestedStatuses.add(status);
        return [];
      },
    );
    final cubit = NextProblemsCubit(repository: repository, prefs: prefs);

    cubit.setFilterStatus(SuggestedProblemStatus.pending);
    expect(cubit.state.filterStatus, SuggestedProblemStatus.pending);
    await _flushEvents();

    cubit.setFilterStatus(null);
    expect(cubit.state.filterStatus, isNull);
    await _flushEvents();

    expect(requestedStatuses, [SuggestedProblemStatus.pending, null]);
    await cubit.close();
  });

  test('ignores stale search responses and keeps the latest query', () async {
    final requests = <String?, Completer<List<SuggestedProblem>>>{};
    final repository = _FakeNextProblemsRepository(
      onList: ({required municipalityId, query, status}) {
        return requests
            .putIfAbsent(query, Completer<List<SuggestedProblem>>.new)
            .future;
      },
    );
    final cubit = NextProblemsCubit(
      repository: repository,
      prefs: prefs,
      searchDebounce: Duration.zero,
    );

    cubit.setQuery('vecchia');
    await _flushEvents();
    expect(requests, contains('vecchia'));

    cubit.setQuery('nuova');
    await _flushEvents();
    expect(requests, contains('nuova'));

    requests['nuova']!.complete([_problem(id: 'new', title: 'Nuova')]);
    await _flushEvents();
    expect(cubit.state.items.single.id, 'new');

    requests['vecchia']!.complete([_problem(id: 'old', title: 'Vecchia')]);
    await _flushEvents();
    expect(cubit.state.query, 'nuova');
    expect(cubit.state.items.single.id, 'new');
    await cubit.close();
  });

  test('clears voting state and exposes a human network error', () async {
    final problem = _problem();
    final repository = _FakeNextProblemsRepository(
      onList: ({required municipalityId, query, status}) async => [problem],
      onVote:
          ({required municipalityId, required problemId, required vote}) async {
            throw const ApiException(
              kind: ApiExceptionKind.network,
              code: 'network_error',
              message: 'socket failed',
            );
          },
    );
    final cubit = NextProblemsCubit(repository: repository, prefs: prefs);
    await cubit.load();

    await cubit.vote(problem.id, VoteChoice.up);

    expect(cubit.state.votingProblemIds, isEmpty);
    expect(cubit.state.items.single, same(problem));
    expect(cubit.state.error, contains('Controlla la connessione'));
    await cubit.close();
  });

  test('uses typed duplicate code for submission feedback', () async {
    final repository = _FakeNextProblemsRepository(
      onSubmit:
          ({
            required municipalityId,
            required title,
            required description,
            required category,
          }) async {
            throw const ApiException(
              kind: ApiExceptionKind.response,
              code: 'duplicate_title',
              message: 'Already exists.',
              statusCode: 409,
            );
          },
    );
    final cubit = NextProblemsCubit(repository: repository, prefs: prefs);

    final result = await cubit.submit(
      title: 'Lampioni spenti',
      description: 'Via Roma resta buia.',
      category: ProblemKey.lighting,
    );

    expect(result, 'duplicate_title');
    expect(cubit.state.submitting, isFalse);
    expect(cubit.state.error, contains('Esiste gia\''));
    await cubit.close();
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

SuggestedProblem _problem({
  String id = 'suggested-1',
  String title = 'Illuminazione al parco',
}) {
  return SuggestedProblem(
    id: id,
    title: title,
    shortDescription: 'Percorsi poco leggibili la sera.',
    category: ProblemKey.lighting,
    createdAt: DateTime.utc(2026, 7, 4),
    status: SuggestedProblemStatus.pending,
    votesUp: 0,
    votesDown: 0,
    myVote: VoteChoice.none,
    submittedByDisplayName: 'Tu',
    promotionRule: const PromotionRule(
      threshold: 1,
      scopeLabel: 'Bologna · illuminazione',
      reason: 'Una approvazione netta promuove il tema.',
    ),
  );
}

typedef _ListHandler =
    Future<List<SuggestedProblem>> Function({
      required String municipalityId,
      String? query,
      SuggestedProblemStatus? status,
    });

typedef _SubmitHandler =
    Future<SuggestedProblem> Function({
      required String municipalityId,
      required String title,
      required String description,
      required ProblemKey category,
    });

typedef _VoteHandler =
    Future<SuggestedProblem> Function({
      required String municipalityId,
      required String problemId,
      required VoteChoice vote,
    });

class _FakeNextProblemsRepository implements NextProblemsRepository {
  _FakeNextProblemsRepository({this.onList, this.onSubmit, this.onVote});

  final _ListHandler? onList;
  final _SubmitHandler? onSubmit;
  final _VoteHandler? onVote;

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) {
    return onList?.call(
          municipalityId: municipalityId,
          query: query,
          status: status,
        ) ??
        Future.value(const []);
  }

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
  }) {
    final handler = onSubmit;
    if (handler == null) {
      return Future.error(StateError('Missing submit handler.'));
    }
    return handler(
      municipalityId: municipalityId,
      title: title,
      description: description,
      category: category,
    );
  }

  @override
  Future<SuggestedProblem> voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) {
    final handler = onVote;
    if (handler == null) {
      return Future.error(StateError('Missing vote handler.'));
    }
    return handler(
      municipalityId: municipalityId,
      problemId: problemId,
      vote: vote,
    );
  }
}
