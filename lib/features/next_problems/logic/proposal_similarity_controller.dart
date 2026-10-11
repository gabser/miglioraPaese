import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';

enum SimilarityStatus { idle, checking, ready, unavailable }

/// Advisory comparison of readable proposals. It does not prove equivalence,
/// claim exhaustive coverage, merge records or prevent distinct same-title issues.
class ProposalSimilarityController extends ChangeNotifier {
  ProposalSimilarityController({
    required this.repository,
    required this.scope,
    required this.data,
  });
  final NextProblemsRepository repository;
  final ProposalScope scope;
  final LocalDataStore data;
  SimilarityStatus status = SimilarityStatus.idle;
  List<SuggestedProblem> candidates = const [];
  bool acknowledged = false;
  int _request = 0;
  bool _disposed = false;
  bool get canProceed =>
      acknowledged || (status == SimilarityStatus.ready && candidates.isEmpty);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void invalidate() {
    _request++;
    status = SimilarityStatus.idle;
    candidates = const [];
    acknowledged = false;
    _notify();
  }

  void acknowledge() {
    acknowledged = true;
    _notify();
  }

  Future<void> review({
    required String title,
    required ProblemKey category,
    required ProposalLocation location,
  }) async {
    final request = ++_request;
    final epoch = data.epoch;
    status = SimilarityStatus.checking;
    candidates = const [];
    acknowledged = false;
    _notify();
    bool current() =>
        !_disposed &&
        request == _request &&
        data.epoch == epoch &&
        scope.namespace == data.namespace &&
        !data.resetting;
    try {
      final items = await repository.listNextProblems(
        municipalityId: scope.municipalityId,
      );
      if (!current()) return;
      candidates = compare(
        items,
        title: title,
        category: category,
        location: location,
      );
      status = SimilarityStatus.ready;
    } catch (_) {
      if (!current()) return;
      status = SimilarityStatus.unavailable;
    }
    _notify();
  }

  static String _normalize(String value) {
    var result = value.trim().toLowerCase();
    const accents = {
      'à': 'a',
      'è': 'e',
      'é': 'e',
      'ì': 'i',
      'ò': 'o',
      'ù': 'u',
    };
    accents.forEach((from, to) => result = result.replaceAll(from, to));
    return result.replaceAll(RegExp(r'[\s,.;:!?()/_-]+'), ' ').trim();
  }

  static Set<String> _tokens(String value) {
    const stop = {
      'il',
      'lo',
      'la',
      'gli',
      'le',
      'di',
      'del',
      'della',
      'delle',
      'dei',
      'un',
      'una',
      'nel',
      'nella',
      'al',
      'alla',
      'e',
      'da',
      'per',
    };
    return _normalize(
      value,
    ).split(' ').where((t) => t.runes.length > 1 && !stop.contains(t)).toSet();
  }

  static List<SuggestedProblem> compare(
    List<SuggestedProblem> items, {
    required String title,
    required ProblemKey category,
    required ProposalLocation location,
  }) {
    final words = _tokens(title);
    final scored = <({SuggestedProblem item, double score})>[];
    final seen = <String>{};
    for (final item in items) {
      if (item.status == SuggestedProblemStatus.rejected ||
          item.category != category ||
          !seen.add(item.id))
        continue;
      final other = _tokens(item.title);
      final union = words.union(other);
      final titleScore = _normalize(item.title) == _normalize(title)
          ? 1.0
          : union.isEmpty
          ? 0.0
          : words.intersection(other).length / union.length;
      final samePlace =
          item.location != null &&
          item.location!.kind == location.kind &&
          _normalize(item.location!.displayLabel) ==
              _normalize(location.displayLabel) &&
          _normalize(item.location!.reference ?? '') ==
              _normalize(location.reference ?? '');
      if (titleScore >= 0.4 || (samePlace && titleScore >= 0.2)) {
        scored.add((item: item, score: titleScore + (samePlace ? 0.2 : 0)));
      }
    }
    scored.sort((a, b) {
      final rank = b.score.compareTo(a.score);
      return rank != 0 ? rank : a.item.id.compareTo(b.item.id);
    });
    return List.unmodifiable(scored.take(3).map((v) => v.item));
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
