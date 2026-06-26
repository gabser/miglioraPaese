import 'dart:math';

import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

class MockNextProblemsRepository implements NextProblemsRepository {
  MockNextProblemsRepository({required this.currentUserId});

  final String currentUserId;
  final Map<String, List<SuggestedProblem>> _cacheByMunicipality = {};
  final Map<String, Map<String, VoteChoice>> _votesByProblem = {};
  int _counter = 100;

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) async {
    final items = _cacheByMunicipality.putIfAbsent(
      municipalityId,
      () => _seedProblems(municipalityId),
    );

    Iterable<SuggestedProblem> filtered = items;
    if (status != null) {
      filtered = filtered.where((item) => item.status == status);
    }
    final normalizedQuery = query?.trim().toLowerCase();
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      filtered = filtered.where(
        (item) =>
            item.title.toLowerCase().contains(normalizedQuery) ||
            item.shortDescription.toLowerCase().contains(normalizedQuery),
      );
    }
    return filtered
        .map(
          (item) => item.copyWith(
            myVote: _votesByProblem[item.id]?[currentUserId] ?? VoteChoice.none,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
  }) async {
    final items = _cacheByMunicipality.putIfAbsent(
      municipalityId,
      () => _seedProblems(municipalityId),
    );
    final normalizedTitle = _normalizeTitle(title);
    final hasDuplicate = items.any(
      (item) => _normalizeTitle(item.title) == normalizedTitle,
    );
    if (hasDuplicate) {
      throw Exception('duplicate_title');
    }
    final problem = SuggestedProblem(
      id: 'custom_${_counter++}',
      title: title,
      shortDescription: description,
      category: category,
      createdAt: DateTime.now(),
      status: SuggestedProblemStatus.pending,
      votesUp: 0,
      votesDown: 0,
      myVote: VoteChoice.none,
      submittedByDisplayName: 'Tu',
    );
    items.insert(0, problem);
    _votesByProblem[problem.id] = {};
    return problem;
  }

  @override
  Future<SuggestedProblem> voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) async {
    final items = _cacheByMunicipality.putIfAbsent(
      municipalityId,
      () => _seedProblems(municipalityId),
    );
    final index = items.indexWhere((item) => item.id == problemId);
    if (index == -1) {
      throw StateError('Suggested problem not found.');
    }
    final current = items[index];
    final votesForProblem = _votesByProblem.putIfAbsent(problemId, () => {});
    final previousVote = votesForProblem[currentUserId] ?? VoteChoice.none;
    var votesUp = current.votesUp;
    var votesDown = current.votesDown;

    if (previousVote == VoteChoice.up) {
      votesUp = max(0, votesUp - 1);
    } else if (previousVote == VoteChoice.down) {
      votesDown = max(0, votesDown - 1);
    }

    final nextVote = previousVote == vote ? VoteChoice.none : vote;
    if (nextVote == VoteChoice.up) {
      votesUp += 1;
    } else if (nextVote == VoteChoice.down) {
      votesDown += 1;
    }

    if (nextVote == VoteChoice.none) {
      votesForProblem.remove(currentUserId);
    } else {
      votesForProblem[currentUserId] = nextVote;
    }

    final updated = current.copyWith(
      votesUp: votesUp,
      votesDown: votesDown,
      myVote: nextVote,
    );
    items[index] = updated;
    return updated;
  }

  List<SuggestedProblem> _seedProblems(String municipalityId) {
    final random = Random(municipalityId.hashCode);
    final baseDate = DateTime(2024, 1, 6);
    final seeds = <(String, String, ProblemKey)>[
      (
        'Buche ovunque',
        'Strade con crateri ovunque, serve una missione.',
        ProblemKey.potholes
      ),
      (
        'Illuminazione a intermittenza',
        'Lampioni che fanno luce a giorni alterni.',
        ProblemKey.lighting
      ),
      (
        'Rifiuti fuori posto',
        'Cassonetti pieni e sacchi in giro.',
        ProblemKey.waste
      ),
      (
        'Bus fantasma',
        'Passano quando vogliono, o forse no.',
        ProblemKey.transport
      ),
      (
        'Parcheggi impossibili',
        'Giri infiniti per un posto libero.',
        ProblemKey.parking
      ),
      ('Decoro ballerino', 'Centro curato, periferie meno.', ProblemKey.decor),
      (
        'Rumore notturno',
        'Tra motorini e locali, si dorme poco.',
        ProblemKey.noise
      ),
      (
        'Verde in pausa',
        'Aree verdi trascurate o poco curate.',
        ProblemKey.green
      ),
      (
        'Sicurezza stradale',
        'Attraversamenti che sembrano missioni.',
        ProblemKey.safety
      ),
      (
        'Cantieri eterni',
        'Lavori che non finiscono mai.',
        ProblemKey.construction
      ),
      ('Code in ufficio', 'Tempi lunghi agli sportelli.', ProblemKey.queues),
      (
        'Segnaletica confusa',
        'Cartelli poco chiari o mancanti.',
        ProblemKey.signage
      ),
    ];

    return List.generate(seeds.length, (index) {
      final (title, description, category) = seeds[index];
      final votesUp = 6 + random.nextInt(42);
      final votesDown = random.nextInt(18);
      final status = index % 4 == 0
          ? SuggestedProblemStatus.approved
          : SuggestedProblemStatus.pending;
      return SuggestedProblem(
        id: 'seed_$index',
        title: title,
        shortDescription: description,
        category: category,
        createdAt: baseDate.add(Duration(days: index * 3)),
        status: status,
        votesUp: votesUp,
        votesDown: votesDown,
        myVote: VoteChoice.none,
        submittedByDisplayName: 'Cittadino ${index + 1}',
      );
    });
  }

  String _normalizeTitle(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
