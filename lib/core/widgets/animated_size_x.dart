import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:flutter/material.dart';

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
