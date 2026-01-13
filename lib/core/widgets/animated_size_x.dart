import 'package:equatable/equatable.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:flutter/material.dart';

// class Prediction extends Equatable {
//   final String turnId;
//   final String problemId;
//   final PredictionChoice choice;
//   final DateTime createdAt;
//   final List<MotivationKey> motivations; // max 2, gestito a livello cubit/repo

//   const Prediction({
//     required this.turnId,
//     required this.problemId,
//     required this.choice,
//     required this.createdAt,
//     this.motivations = const [],
//   });

//   Prediction copyWith({
//     PredictionChoice? choice,
//     DateTime? createdAt,
//     List<MotivationKey>? motivations,
//   }) {
//     return Prediction(
//       turnId: turnId,
//       problemId: problemId,
//       choice: choice ?? this.choice,
//       createdAt: createdAt ?? this.createdAt,
//       motivations: motivations ?? this.motivations,
//     );
//   }

//   @override
//   List<Object?> get props => [turnId, problemId, choice, createdAt, motivations];
// }

/// AnimatedSize con configurazione coerente per transizioni di layout morbide.
///
/// NOTE:
/// - AnimatedSize NON accetta vsync.
/// - Non serve StatefulWidget né SingleTickerProviderStateMixin.
class AnimatedSizeX extends StatelessWidget {
  const AnimatedSizeX({
    super.key,
    required this.child,
    this.duration,
    this.curve,
    this.alignment = Alignment.topCenter,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final Duration? duration;
  final Curve? curve;
  final Alignment alignment;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration ?? AppMotion.normal,
      curve: curve ?? AppMotion.standard,
      alignment: alignment,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}
