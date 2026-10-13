import 'dart:math';
import 'dart:convert';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/data/suggested_problem_mapper.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';

import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/promotion_rule.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

class CivicLoopStore {
  CivicLoopStore({
    required String currentUserId,
    LocalDataStore? localData,
    String Function()? storageKey,
    String Function()? userId,
  }) : _currentUserId = currentUserId,
       _localData = localData,
       _storageKey = storageKey ?? (() => 'civic_loop_mock_v1'),
       _userId = userId {
    _seenEpoch = epoch;
    _localData?.addListener(_onLocalData);
  }

  static const promotionThreshold = 1;

  final String _currentUserId;
  final String Function()? _userId;
  String get currentUserId => _userId?.call() ?? _currentUserId;
  final LocalDataStore? _localData;
  final String Function() _storageKey;
  int _seenEpoch = 0;
  int _loadedRevision = -1;
  int _memoryEpoch = 0;
  final List<VoidCallback> _resetListeners = [];
  void addResetListener(VoidCallback listener) => _resetListeners.add(listener);
  void removeResetListener(VoidCallback listener) =>
      _resetListeners.remove(listener);
  int get epoch => _localData?.epoch ?? _memoryEpoch;
  bool get resetting => _localData?.resetting ?? false;
  final Map<String, List<SuggestedProblem>> _cacheByMunicipality = {};
  final Map<String, Map<String, VoteChoice>> _votesByProblem = {};
  final Map<String, Map<String, Object?>> _submissions = {};
  void _onLocalData() {
    if (_seenEpoch == epoch) return;
    _seenEpoch = epoch;
    _cacheByMunicipality.clear();
    _votesByProblem.clear();
    _submissions.clear();
    _loadedRevision = -1;
    for (final listener in List<VoidCallback>.of(_resetListeners)) {
      listener();
    }
  }

  void resetMemory() {
    _memoryEpoch++;
    _onLocalData();
  }

  void _load() {
    final storage = _localData;
    if (storage == null || _loadedRevision == storage.revision) return;
    final value = storage.read(_storageKey());
    _restore(value);
    _loadedRevision = storage.revision;
  }

  Future<SuggestedProblem> _mutate(
    SuggestedProblem Function(CivicLoopStore) change,
  ) async {
    final storage = _localData;
    if (storage == null) return change(this);
    final capturedEpoch = epoch;
    final result = await storage.mutate(_storageKey(), (value) {
      final candidate = CivicLoopStore(currentUserId: currentUserId);
      try {
        candidate._restore(value);
        final result = change(candidate);
        return LocalDataMutation(candidate._snapshot(), result);
      } finally {
        candidate.dispose();
      }
    }, expectedEpoch: capturedEpoch);
    _loadedRevision = -1;
    _load();
    return result;
  }

  List<SuggestedProblem> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) {
    _load();
    municipalityId = ProposalScope.canonicalMunicipality(municipalityId);
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
            item.shortDescription.toLowerCase().contains(normalizedQuery) ||
            (item.location?.displayLabel.toLowerCase().contains(
                  normalizedQuery,
                ) ??
                false) ||
            (item.location?.reference?.toLowerCase().contains(
                  normalizedQuery,
                ) ??
                false),
      );
    }

    return filtered
        .map(
          (item) => item.copyWith(
            myVote:
                _votesByProblem[_voteKey(
                  municipalityId,
                  item.id,
                )]?[currentUserId] ??
                VoteChoice.none,
          ),
        )
        .toList(growable: false);
  }

  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
  }) => _mutate(
    (candidate) => candidate._submitSuggestedProblem(
      municipalityId: municipalityId,
      title: title,
      description: description,
      category: category,
      location: location,
    ),
  );

  String _submissionKey(ProposalSubmissionIntent intent) => jsonEncode([
    intent.submissionScope,
    intent.scope.municipalityId,
    intent.idempotencyKey,
  ]);

  Future<SuggestedProblem> submitIntent(ProposalSubmissionIntent intent) {
    if (_localData != null && intent.scope.namespace != _localData.namespace) {
      return Future.error(const LocalDataResetException());
    }
    return _mutate((candidate) {
      final key = _submissionKey(intent);
      final prior = candidate._submissions[key];
      final payload = jsonEncode(intent.payload);
      if (prior != null) {
        if (prior['payload'] != payload) {
          throw const ApiException(
            kind: ApiExceptionKind.response,
            statusCode: 409,
            code: 'idempotency_key_reused',
            message: 'La chiave appartiene a un altro invio.',
          );
        }
        return SuggestedProblemMapper.fromResponse(prior['receipt']);
      }
      final problem = candidate._submitSuggestedProblem(
        municipalityId: intent.scope.municipalityId,
        title: intent.title,
        description: intent.description,
        category: intent.category,
        location: intent.location,
      );
      candidate._submissions[key] = {
        'payload': payload,
        'receipt': SuggestedProblemMapper.toJson(problem),
      };
      return problem;
    });
  }

  SuggestedProblem lookupIntent(ProposalSubmissionIntent intent) {
    if (_localData != null && intent.scope.namespace != _localData.namespace) {
      throw const LocalDataResetException();
    }
    _load();
    final prior = _submissions[_submissionKey(intent)];
    if (prior == null) {
      throw const ApiException(
        kind: ApiExceptionKind.response,
        statusCode: 404,
        code: 'submission_not_found',
        message: 'Invio non trovato.',
      );
    }
    return SuggestedProblemMapper.fromResponse(prior['receipt']);
  }

  SuggestedProblem getOwnSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required String submissionScope,
  }) {
    _load();
    final municipality = ProposalScope.canonicalMunicipality(municipalityId);
    final owned = _submissions.entries.any((entry) {
      final key = jsonDecode(entry.key) as List;
      final receipt = SuggestedProblemMapper.fromResponse(
        entry.value['receipt'],
      );
      return key[0] == submissionScope &&
          key[1] == municipality &&
          receipt.id == problemId;
    });
    if (owned) {
      for (final item in listNextProblems(municipalityId: municipality)) {
        if (item.id == problemId) return item;
      }
    }
    throw const ApiException(
      kind: ApiExceptionKind.response,
      statusCode: 404,
      code: 'suggested_problem_not_found',
      message: 'Proposta non trovata.',
    );
  }

  SuggestedProblem _submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
  }) {
    municipalityId = ProposalScope.canonicalMunicipality(municipalityId);
    final items = _cacheByMunicipality.putIfAbsent(
      municipalityId,
      () => _seedProblems(municipalityId),
    );
    final problem = SuggestedProblem(
      id: 'custom_${newLocalId()}',
      title: ProposalLimits.text(title, ProposalLimits.title),
      shortDescription: ProposalLimits.text(
        description,
        ProposalLimits.description,
      ),
      location: location,
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
    _votesByProblem[_voteKey(municipalityId, problem.id)] = {};
    return problem;
  }

  Future<SuggestedProblem> voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) => _mutate(
    (candidate) => candidate._voteSuggestedProblem(
      municipalityId: municipalityId,
      problemId: problemId,
      vote: vote,
    ),
  );

  SuggestedProblem _voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) {
    municipalityId = ProposalScope.canonicalMunicipality(municipalityId);
    final items = _cacheByMunicipality.putIfAbsent(
      municipalityId,
      () => _seedProblems(municipalityId),
    );
    final index = items.indexWhere((item) => item.id == problemId);
    if (index == -1) {
      throw StateError('Suggested problem not found.');
    }

    final current = items[index];
    final votesForProblem = _votesByProblem.putIfAbsent(
      _voteKey(municipalityId, problemId),
      () => {},
    );
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
    _load();
    municipalityId = ProposalScope.canonicalMunicipality(municipalityId);
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
    _load();
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
    _load();
    municipalityId = ProposalScope.canonicalMunicipality(municipalityId);
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
          'Nella demo di questo Comune basta 1 voto netto a favore: voti a favore meno voti contrari. Raggiunta la soglia, la proposta entra nella lista del gioco delle previsioni.',
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
      zoneName: suggestion.location?.displayLabel ?? 'Luogo non indicato',
      status: status,
      trendPercent: trend,
      updatedAt: suggestion.createdAt,
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
        'Ci sono buche lungo diverse strade del centro.',
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
        'I bus arrivano spesso in ritardo rispetto agli orari.',
        ProblemKey.transport,
      ),
      (
        'Parcheggi impossibili',
        'Giri infiniti per un posto libero.',
        ProblemKey.parking,
      ),
      ('Spazi poco curati', 'Centro curato, periferie meno.', ProblemKey.decor),
      (
        'Rumore notturno',
        'Tra motorini e locali, si dorme poco.',
        ProblemKey.noise,
      ),
      (
        'Aree verdi trascurate',
        'Aree verdi trascurate o poco curate.',
        ProblemKey.green,
      ),
      (
        'Sicurezza stradale',
        'Attraversare vicino alle scuole è difficile.',
        ProblemKey.safety,
      ),
      (
        'Cantieri ancora aperti',
        'I lavori sono in corso da molto tempo.',
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
        id: 'seed_${base64Url.encode(utf8.encode(municipalityId)).replaceAll('=', '')}_$index',
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

  String _voteKey(String municipalityId, String id) =>
      jsonEncode([municipalityId, id]);

  Map<String, Object?> _snapshot() => {
    'version': 2,
    'submissions': _submissions,
    'municipalities': _cacheByMunicipality.map(
      (key, items) => MapEntry(
        key,
        items
            .map(
              (item) => {
                'id': item.id,
                'title': item.title,
                'shortDescription': item.shortDescription,
                'location': item.location?.toJson(),
                'category': item.category.name,
                'createdAt': item.createdAt.toUtc().toIso8601String(),
                'status': item.status.name,
                'votesUp': item.votesUp,
                'votesDown': item.votesDown,
                'myVote': 'none',
                'submittedByDisplayName': item.submittedByDisplayName,
                'promotionRule': {
                  'threshold': item.promotionRule.threshold,
                  'scopeLabel': item.promotionRule.scopeLabel,
                  'reason': item.promotionRule.reason,
                },
              },
            )
            .toList(),
      ),
    ),
    'votes': _votesByProblem.map(
      (key, values) =>
          MapEntry(key, values.map((user, vote) => MapEntry(user, vote.name))),
    ),
  };

  void _restore(Object? value) {
    final municipalities = <String, List<SuggestedProblem>>{};
    final votes = <String, Map<String, VoteChoice>>{};
    final submissions = <String, Map<String, Object?>>{};
    if (value != null) {
      try {
        if (value is! Map<String, dynamic> ||
            !((value['version'] == 1 && value.length == 3) ||
                (value['version'] == 2 &&
                    value.length == 4 &&
                    value['submissions'] is Map<String, dynamic>)) ||
            value['municipalities'] is! Map<String, dynamic> ||
            value['votes'] is! Map<String, dynamic>) {
          throw const LocalDataCorruptException();
        }
        for (final entry
            in (value['municipalities'] as Map<String, dynamic>).entries) {
          if (ProposalScope.canonicalMunicipality(entry.key) != entry.key ||
              entry.value is! List)
            throw const LocalDataCorruptException();
          final items = (entry.value as List)
              .map(SuggestedProblemMapper.fromResponse)
              .toList();
          if (items.map((item) => item.id).toSet().length != items.length ||
              items.any(
                (item) =>
                    item.votesUp < 0 ||
                    item.votesDown < 0 ||
                    item.promotionRule.threshold <= 0,
              ))
            throw const LocalDataCorruptException();
          municipalities[entry.key] = items;
        }
        for (final entry in (value['votes'] as Map<String, dynamic>).entries) {
          final scope = jsonDecode(entry.key);
          if (scope is! List ||
              scope.length != 2 ||
              scope.any((part) => part is! String) ||
              entry.value is! Map<String, dynamic> ||
              !(municipalities[scope[0]]?.any((item) => item.id == scope[1]) ??
                  false))
            throw const LocalDataCorruptException();
          votes[entry.key] = (entry.value as Map<String, dynamic>).map((
            user,
            raw,
          ) {
            final vote = VoteChoice.values.byName(raw as String);
            if (user.isEmpty || vote == VoteChoice.none)
              throw const LocalDataCorruptException();
            return MapEntry(user, vote);
          });
        }
        if (value['version'] == 2) {
          for (final entry
              in (value['submissions'] as Map<String, dynamic>).entries) {
            final key = jsonDecode(entry.key);
            final record = entry.value;
            if (key is! List ||
                key.length != 3 ||
                key.any((part) => part is! String || part.isEmpty) ||
                record is! Map<String, dynamic> ||
                record.length != 2 ||
                record['payload'] is! String) {
              throw const LocalDataCorruptException();
            }
            final receipt = SuggestedProblemMapper.fromResponse(
              record['receipt'],
            );
            if (!(municipalities[key[1]]?.any(
                  (problem) => problem.id == receipt.id,
                ) ??
                false)) {
              throw const LocalDataCorruptException();
            }
            submissions[entry.key] = Map<String, Object?>.from(record);
          }
        }
      } catch (_) {
        throw const LocalDataCorruptException();
      }
    }
    _cacheByMunicipality
      ..clear()
      ..addAll(municipalities);
    _votesByProblem
      ..clear()
      ..addAll(votes);
    _submissions
      ..clear()
      ..addAll(submissions);
  }

  void dispose() {
    _localData?.removeListener(_onLocalData);
    _resetListeners.clear();
  }
}
