import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
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

    final outcome = await cubit.vote(problem.id, VoteChoice.up);

    expect(cubit.state.votingProblemIds, isEmpty);
    expect(cubit.state.items.single, same(problem));
    expect(outcome, VoteOutcome.failed);
    expect(cubit.state.error, isNull);
    expect(cubit.state.voteError, contains('Controlla la connessione'));
    await cubit.close();
  });

  test(
    'duplicate taps are ignored and successful vote uses returned server state',
    () async {
      final response = Completer<SuggestedProblem>();
      var calls = 0;
      final problem = _problem();
      final cubit = NextProblemsCubit(
        prefs: prefs,
        repository: _FakeNextProblemsRepository(
          onList: ({required municipalityId, query, status}) async => [problem],
          onVote:
              ({required municipalityId, required problemId, required vote}) {
                calls++;
                return response.future;
              },
        ),
      );
      await cubit.load();
      final first = cubit.vote(problem.id, VoteChoice.up);
      expect(await cubit.vote(problem.id, VoteChoice.up), VoteOutcome.ignored);
      expect(calls, 1);
      response.complete(
        problem.copyWith(
          votesUp: 1,
          myVote: VoteChoice.up,
          status: SuggestedProblemStatus.approved,
        ),
      );
      expect(await first, VoteOutcome.succeeded);
      expect(cubit.state.items.single.status, SuggestedProblemStatus.approved);
      expect(cubit.state.items.single.votesUp, 1);
      expect(cubit.state.votingProblemIds, isEmpty);
      await cubit.close();
    },
  );

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

  test(
    'load, vote and submit freeze the explicit municipality, not later prefs',
    () async {
      final calls = <String>[];
      final repository = _FakeNextProblemsRepository(
        onList: ({required municipalityId, query, status}) async {
          calls.add(municipalityId);
          return [_problem()];
        },
        onVote:
            ({
              required municipalityId,
              required problemId,
              required vote,
            }) async {
              calls.add(municipalityId);
              return _problem().copyWith(votesUp: 1, myVote: VoteChoice.up);
            },
        onSubmit:
            ({
              required municipalityId,
              required title,
              required description,
              required category,
            }) async {
              calls.add(municipalityId);
              return _problem();
            },
      );
      final cubit = NextProblemsCubit(
        repository: repository,
        prefs: prefs,
        municipalityId: 'comune:Castel Bolognese',
      );
      await prefs.setMunicipalityId('comune:Pincara');
      await cubit.load();
      await cubit.vote('suggested-1', VoteChoice.up);
      await cubit.submit(
        title: 'Titolo',
        description: 'Descrizione',
        category: ProblemKey.green,
      );
      expect(calls, [
        'castel-bolognese',
        'castel-bolognese',
        'castel-bolognese',
      ]);
      expect(cubit.state.municipalityId, 'castel-bolognese');
      expect(prefs.municipalityId, 'comune:Pincara');
      await cubit.close();
    },
  );

  test(
    'a preference change alone does not alter the captured initial context',
    () async {
      final calls = <String>[];
      final cubit = NextProblemsCubit(
        prefs: prefs,
        repository: _FakeNextProblemsRepository(
          onList: ({required municipalityId, query, status}) async {
            calls.add(municipalityId);
            return [];
          },
        ),
      );
      await prefs.setMunicipalityId('comune:Pincara');
      await cubit.load();
      expect(calls, ['bologna']);
      await cubit.close();
    },
  );

  test('late load errors from an abandoned municipality are ignored', () async {
    final old = Completer<List<SuggestedProblem>>();
    final latest = Completer<List<SuggestedProblem>>();
    final cubit = NextProblemsCubit(
      prefs: prefs,
      repository: _FakeNextProblemsRepository(
        onList: ({required municipalityId, query, status}) =>
            municipalityId == 'bologna' ? old.future : latest.future,
      ),
    );
    final first = cubit.load();
    cubit.setQuery('old query');
    final second = cubit.setMunicipality('castel-bolognese');
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.query, isEmpty);
    latest.complete([_problem(id: 'new', title: 'Castel Bolognese')]);
    await second;
    old.completeError(
      const ApiException(
        kind: ApiExceptionKind.network,
        code: 'network_error',
        message: 'Old request failed',
      ),
    );
    await first;
    expect(cubit.state.items.single.id, 'new');
    expect(cubit.state.error, isNull);
    expect(cubit.state.municipalityId, 'castel-bolognese');
    await cubit.close();
  });

  for (final oldFails in [false, true]) {
    test(
      'late vote (${oldFails ? 'error' : 'success'}) cannot overwrite the same ID in another municipality',
      () async {
        final oldVote = Completer<SuggestedProblem>();
        final newVote = Completer<SuggestedProblem>();
        final cubit = NextProblemsCubit(
          prefs: prefs,
          repository: _FakeNextProblemsRepository(
            onList: ({required municipalityId, query, status}) async => [
              _problem(title: municipalityId),
            ],
            onVote:
                ({
                  required municipalityId,
                  required problemId,
                  required vote,
                }) => municipalityId == 'bologna'
                ? oldVote.future
                : newVote.future,
          ),
        );
        await cubit.load();
        final first = cubit.vote('suggested-1', VoteChoice.up);
        await cubit.setMunicipality('castel-bolognese');
        final second = cubit.vote('suggested-1', VoteChoice.up);
        if (oldFails) {
          oldVote.completeError(StateError('Old vote failed'));
        } else {
          oldVote.complete(_problem(title: 'bologna').copyWith(votesUp: 99));
        }
        expect(await first, VoteOutcome.ignored);
        expect(cubit.state.items.single.title, 'castel-bolognese');
        expect(cubit.state.items.single.votesUp, 0);
        expect(cubit.state.voteError, isNull);
        expect(cubit.state.votingProblemIds, {'suggested-1'});
        newVote.complete(
          _problem(title: 'castel-bolognese').copyWith(votesUp: 1),
        );
        expect(await second, VoteOutcome.succeeded);
        expect(cubit.state.items.single.votesUp, 1);
        await cubit.close();
      },
    );
  }

  test(
    'missing/invalid context makes no repository calls or demo fallback',
    () async {
      var listCalls = 0;
      final cubit = NextProblemsCubit(
        prefs: prefs,
        municipalityId: 'invalid',
        repository: _FakeNextProblemsRepository(
          onList: ({required municipalityId, query, status}) async {
            listCalls++;
            return [];
          },
        ),
      );
      await cubit.load();
      expect(
        await cubit.vote('suggested-1', VoteChoice.up),
        VoteOutcome.ignored,
      );
      expect(
        await cubit.submit(
          title: 'Titolo',
          description: 'Descrizione',
          category: ProblemKey.green,
        ),
        'municipality_required',
      );
      expect(listCalls, 0);
      expect(cubit.state.municipalityId, isNull);
      expect(cubit.state.error, contains('Scegli un Comune'));
      await cubit.close();
    },
  );

  test(
    'reset invalidates a late load without starting a replacement request',
    () async {
      final response = Completer<List<SuggestedProblem>>();
      var calls = 0;
      final cubit = NextProblemsCubit(
        prefs: prefs,
        repository: _FakeNextProblemsRepository(
          onList: ({required municipalityId, query, status}) {
            calls++;
            return response.future;
          },
        ),
      );
      final pending = cubit.load();
      await prefs.clearAll();
      response.complete([_problem()]);
      await pending;
      expect(calls, 1);
      expect(cubit.state.municipalityId, isNull);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.isLoading, false);
      await cubit.close();
    },
  );
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
  @override
  Future<SuggestedProblem> getSuggestedProblem({
    required String municipalityId,
    required String problemId,
  }) => Future.error(StateError('Detail is not part of this test fixture.'));

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
    ProposalLocation? location,
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
