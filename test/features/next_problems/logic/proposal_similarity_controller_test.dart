import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/suggested_problem_mapper.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_similarity_controller.dart';
import '../../../helpers/memory_local_backend.dart';

SuggestedProblem item(
  String id, {
  String title = 'Rami al parco',
  String category = 'green',
  String status = 'pending',
  ProposalLocation? location,
}) => SuggestedProblemMapper.fromResponse({
  'id': id,
  'title': title,
  'shortDescription': 'Serve un passaggio libero.',
  'category': category,
  'status': status,
  'location': location?.toJson(),
  'createdAt': '2026-10-10T10:00:00Z',
  'votesUp': 0,
  'votesDown': 0,
  'myVote': 'none',
  'submittedByDisplayName': 'Cittadino',
  'promotionRule': {'threshold': 1, 'scopeLabel': 'Comune', 'reason': 'Demo'},
});

class Source extends MockNextProblemsRepository {
  Source(this.fetch) : super(currentUserId: 'test');
  final Future<List<SuggestedProblem>> Function(String) fetch;
  final municipalities = <String>[];
  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) {
    municipalities.add(municipalityId);
    return fetch(municipalityId);
  }
}

void main() {
  final via = ProposalLocation.specific(label: 'Via Milano', civic: '12/A');
  test(
    'same title in different places remains advisory; category/rejected excluded and legacy location remains unknown',
    () {
      final candidates = ProposalSimilarityController.compare(
        [
          item('same-place', location: via),
          item(
            'other-place',
            location: ProposalLocation.specific(label: 'Via Roma'),
          ),
          item('legacy'),
          item('rejected', status: 'rejected', location: via),
          item('other-category', category: 'lighting', location: via),
        ],
        title: 'Rami al parco',
        category: ProblemKey.green,
        location: via,
      );
      expect(candidates.map((v) => v.id), [
        'same-place',
        'legacy',
        'other-place',
      ]);
      expect(candidates[1].location, isNull);
      expect(candidates[2].location!.label, 'Via Roma');
    },
  );
  test(
    'same place alone does not imply similarity and comparison ranks readable unique ids only',
    () {
      final values = [
        item('same', location: via),
        item('same', location: via),
        item('different', title: 'Panchina da riparare', location: via),
      ];
      final candidates = ProposalSimilarityController.compare(
        values,
        title: 'Rami al parco',
        category: ProblemKey.green,
        location: via,
      );
      expect(candidates.map((v) => v.id), ['same']);
    },
  );
  test(
    'late query cannot replace newer review or acknowledged decision; edits invalidate consent',
    () async {
      final first = Completer<List<SuggestedProblem>>();
      final second = Completer<List<SuggestedProblem>>();
      var index = 0;
      final data = LocalDataStore(backend: MemoryLocalBackend());
      final source = Source((_) => index++ == 0 ? first.future : second.future);
      final controller = ProposalSimilarityController(
        repository: source,
        scope: ProposalScope(
          municipalityId: 'bologna',
          environment: 'test',
          namespace: data.namespace,
        ),
        data: data,
      );
      final a = controller.review(
        title: 'Rami al parco',
        category: ProblemKey.green,
        location: via,
      );
      controller.invalidate();
      final b = controller.review(
        title: 'Panchina da riparare',
        category: ProblemKey.green,
        location: via,
      );
      second.complete([item('new', title: 'Panchina da riparare')]);
      await b;
      expect(controller.candidates.single.id, 'new');
      expect(controller.canProceed, isFalse);
      controller.acknowledge();
      expect(controller.canProceed, isTrue);
      first.complete([item('old')]);
      await a;
      expect(controller.candidates.single.id, 'new');
      expect(controller.canProceed, isTrue);
      controller.invalidate();
      expect(controller.canProceed, isFalse);
      expect(source.municipalities, ['bologna', 'bologna']);
      controller.dispose();
      data.dispose();
    },
  );
  test(
    'failed lookup allows explicit continuation, without asserting no similar issues exist',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      final controller = ProposalSimilarityController(
        repository: Source((_) async => throw StateError('offline')),
        scope: ProposalScope(
          municipalityId: 'bologna',
          environment: 'test',
          namespace: data.namespace,
        ),
        data: data,
      );
      await controller.review(
        title: 'Rami al parco',
        category: ProblemKey.green,
        location: via,
      );
      expect(controller.status, SimilarityStatus.unavailable);
      expect(controller.canProceed, isFalse);
      controller.acknowledge();
      expect(controller.canProceed, isTrue);
      controller.dispose();
      data.dispose();
    },
  );
  test(
    'reset and dispose invalidate pending comparison without late notification',
    () async {
      final pending = Completer<List<SuggestedProblem>>();
      final data = LocalDataStore(backend: MemoryLocalBackend());
      final controller = ProposalSimilarityController(
        repository: Source((_) => pending.future),
        scope: ProposalScope(
          municipalityId: 'bologna',
          environment: 'test',
          namespace: data.namespace,
        ),
        data: data,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      final work = controller.review(
        title: 'Rami al parco',
        category: ProblemKey.green,
        location: via,
      );
      expect(notifications, 1);
      await data.reset();
      controller.dispose();
      pending.complete([item('late')]);
      await work;
      expect(notifications, 1);
      expect(controller.candidates, isEmpty);
      data.dispose();
    },
  );
}
