import 'dart:math';

import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/promotion_rule.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

class CivicLoopStore {
  CivicLoopStore({required this.currentUserId});

  static const promotionThreshold = 1;

  final String currentUserId;
  final Map<String, List<SuggestedProblem>> _cacheByMunicipality = {};
  final Map<String, Map<String, VoteChoice>> _votesByProblem = {};
  int _counter = 100;

  List<SuggestedProblem> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) {
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

  SuggestedProblem submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
  }) {
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
      promotionRule: _promotionRuleFor(
        municipalityId: municipalityId,
        category: category,
      ),
    );
    items.insert(0, problem);
    _votesByProblem[problem.id] = {};
    return problem;
  }

  SuggestedProblem voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) {
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

    final status = _promotedStatus(
      current: current.status,
      votesUp: votesUp,
      votesDown: votesDown,
    );
    final updated = current.copyWith(
      votesUp: votesUp,
      votesDown: votesDown,
      myVote: nextVote,
      status: status,
    );
    items[index] = updated;
    return updated;
  }

  List<SuggestedProblem> confirmedThemes(String municipalityId) {
    final items = _cacheByMunicipality.putIfAbsent(
      municipalityId,
      () => _seedProblems(municipalityId),
    );
    final confirmed = items
        .where((item) => item.status == SuggestedProblemStatus.approved)
        .toList();
    confirmed.sort((a, b) => b.score.compareTo(a.score));
    return List<SuggestedProblem>.unmodifiable(confirmed);
  }

  List<Problem> promotedProblems(String municipalityId) {
    return confirmedThemes(
      municipalityId,
    ).take(3).map(_toTurnProblem).toList(growable: false);
  }

  Problem? problemByCardId(String problemId) {
    for (final items in _cacheByMunicipality.values) {
      for (final item in items) {
        if (_cardIdFor(item.id) == problemId &&
            item.status == SuggestedProblemStatus.approved) {
          return _toTurnProblem(item);
        }
      }
    }
    return null;
  }

  bool hasPromotedCards(String municipalityId) {
    return promotedProblems(municipalityId).isNotEmpty;
  }

  int proposedCount(String municipalityId) {
    return _cacheByMunicipality
        .putIfAbsent(municipalityId, () => _seedProblems(municipalityId))
        .length;
  }

  String? topThemeTitle(String municipalityId) {
    final promoted = confirmedThemes(municipalityId);
    if (promoted.isEmpty) return null;
    return promoted.first.title;
  }

  SuggestedProblemStatus _promotedStatus({
    required SuggestedProblemStatus current,
    required int votesUp,
    required int votesDown,
  }) {
    if (current == SuggestedProblemStatus.rejected) {
      return current;
    }
    return votesUp - votesDown >= promotionThreshold
        ? SuggestedProblemStatus.approved
        : SuggestedProblemStatus.pending;
  }

  PromotionRule _promotionRuleFor({
    required String municipalityId,
    required ProblemKey category,
  }) {
    final municipalityName = MunicipalityCatalog.displayNameFromId(
      municipalityId,
    );
    final categoryName = switch (category) {
      ProblemKey.lighting => 'illuminazione',
      ProblemKey.potholes => 'strade',
      ProblemKey.waste => 'rifiuti',
      ProblemKey.cleanliness => 'pulizia',
      ProblemKey.green => 'verde',
      ProblemKey.signage => 'segnaletica',
      ProblemKey.transport => 'trasporti',
      ProblemKey.parking => 'parcheggi',
      ProblemKey.decor => 'decoro',
      ProblemKey.noise => 'rumore',
      ProblemKey.safety => 'sicurezza',
      ProblemKey.construction => 'cantieri',
      ProblemKey.queues => 'servizi',
    };

    return PromotionRule(
      threshold: promotionThreshold,
      scopeLabel: '$municipalityName · $categoryName',
      reason:
          'Regola demo configurabile: in questo Comune basta 1 approvazione netta per testare il passaggio in lista.',
    );
  }

  Problem _toTurnProblem(SuggestedProblem suggestion) {
    final random = Random(suggestion.id.hashCode);
    final status = switch (random.nextInt(3)) {
      0 => ProblemStatus.improving,
      1 => ProblemStatus.stable,
      _ => ProblemStatus.worsening,
    };
    final trend = switch (status) {
      ProblemStatus.improving => 8 + random.nextInt(10),
      ProblemStatus.stable => random.nextInt(7) - 3,
      ProblemStatus.worsening => -6 - random.nextInt(12),
    };
    return Problem(
      id: _cardIdFor(suggestion.id),
      key: suggestion.category,
      title: suggestion.title,
      zoneName: 'Tema scelto dai cittadini',
      status: status,
      trendPercent: trend,
      updatedAt: DateTime.now().subtract(
        Duration(hours: 1 + random.nextInt(8)),
      ),
    );
  }

  List<SuggestedProblem> _seedProblems(String municipalityId) {
    if (!MunicipalityCatalog.isActiveMunicipality(municipalityId)) {
      return <SuggestedProblem>[];
    }

    final random = Random(municipalityId.hashCode);
    final baseDate = DateTime(2024, 1, 6);
    final seeds = <(String, String, ProblemKey)>[
      (
        'Buche ovunque',
        'Strade con crateri ovunque, serve una missione.',
        ProblemKey.potholes,
      ),
      (
        'Illuminazione a intermittenza',
        'Lampioni che fanno luce a giorni alterni.',
        ProblemKey.lighting,
      ),
      (
        'Rifiuti fuori posto',
        'Cassonetti pieni e sacchi in giro.',
        ProblemKey.waste,
      ),
      (
        'Bus fantasma',
        'Passano quando vogliono, o forse no.',
        ProblemKey.transport,
      ),
      (
        'Parcheggi impossibili',
        'Giri infiniti per un posto libero.',
        ProblemKey.parking,
      ),
      ('Decoro ballerino', 'Centro curato, periferie meno.', ProblemKey.decor),
      (
        'Rumore notturno',
        'Tra motorini e locali, si dorme poco.',
        ProblemKey.noise,
      ),
      (
        'Verde in pausa',
        'Aree verdi trascurate o poco curate.',
        ProblemKey.green,
      ),
      (
        'Sicurezza stradale',
        'Attraversamenti che sembrano missioni.',
        ProblemKey.safety,
      ),
      (
        'Cantieri eterni',
        'Lavori che non finiscono mai.',
        ProblemKey.construction,
      ),
      ('Code in ufficio', 'Tempi lunghi agli sportelli.', ProblemKey.queues),
      (
        'Segnaletica confusa',
        'Cartelli poco chiari o mancanti.',
        ProblemKey.signage,
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
        promotionRule: _promotionRuleFor(
          municipalityId: municipalityId,
          category: category,
        ),
      );
    });
  }

  String _cardIdFor(String suggestionId) => 'proposal_$suggestionId';

  String _normalizeTitle(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
