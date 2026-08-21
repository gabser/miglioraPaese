import 'package:equatable/equatable.dart';

class PromotionRule extends Equatable {
  const PromotionRule({
    required this.threshold,
    required this.scopeLabel,
    required this.reason,
  });

  final int threshold;
  final String scopeLabel;
  final String reason;

  @override
  List<Object?> get props => [threshold, scopeLabel, reason];
}
