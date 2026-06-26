import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

class SuggestedProblem {
  const SuggestedProblem({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.category,
    required this.createdAt,
    required this.status,
    required this.votesUp,
    required this.votesDown,
    required this.myVote,
    required this.submittedByDisplayName,
  });

  final String id;
  final String title;
  final String shortDescription;
  final ProblemKey category;
  final DateTime createdAt;
  final SuggestedProblemStatus status;
  final int votesUp;
  final int votesDown;
  final VoteChoice myVote;
  final String submittedByDisplayName;

  int get score => votesUp - votesDown;

  SuggestedProblem copyWith({
    String? id,
    String? title,
    String? shortDescription,
    ProblemKey? category,
    DateTime? createdAt,
    SuggestedProblemStatus? status,
    int? votesUp,
    int? votesDown,
    VoteChoice? myVote,
    String? submittedByDisplayName,
  }) {
    return SuggestedProblem(
      id: id ?? this.id,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      votesUp: votesUp ?? this.votesUp,
      votesDown: votesDown ?? this.votesDown,
      myVote: myVote ?? this.myVote,
      submittedByDisplayName:
          submittedByDisplayName ?? this.submittedByDisplayName,
    );
  }
}
