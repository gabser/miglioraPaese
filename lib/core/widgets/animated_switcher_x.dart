import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';

/// AnimatedSwitcher preconfigurato con transizione leggera (fade + slide).
class AnimatedSwitcherX extends StatelessWidget {
  /// Costruisce un AnimatedSwitcher che usa i token di motion condivisi.
  const AnimatedSwitcherX({
    super.key,
    required this.child,
    this.duration,
    this.switchInCurve,
    this.switchOutCurve,
  });

  /// Contenuto da animare in ingresso/uscita.
  final Widget child;

  /// Durata della transizione; di default usa [AppMotion.normal].
  final Duration? duration;

  /// Curva di ingresso; di default usa [AppMotion.standard].
  final Curve? switchInCurve;

  /// Curva di uscita; di default usa [AppMotion.standard].
  final Curve? switchOutCurve;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration ?? AppMotion.normal,
      switchInCurve: switchInCurve ?? AppMotion.standard,
      switchOutCurve: switchOutCurve ?? AppMotion.standard,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final slideAnimation = animation.drive(
          Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero),
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
      child: child,
    );
  }
}
