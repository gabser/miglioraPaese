import 'package:flutter/material.dart';
import 'package:goodtime/core/theme/app_motion.dart';

/// AnimatedSize con configurazione coerente per transizioni di layout morbide.
class AnimatedSizeX extends StatefulWidget {
  /// Crea un AnimatedSize con durata e curva dai token di motion.
  const AnimatedSizeX({
    super.key,
    required this.child,
    this.duration = AppMotion.normal,
    this.curve = AppMotion.standard,
    this.alignment = Alignment.topCenter,
  });

  /// Contenuto che adatta la propria dimensione con animazione.
  final Widget child;

  /// Durata della variazione; di default usa [AppMotion.normal].
  final Duration duration;

  /// Curva di animazione; di default usa [AppMotion.standard].
  final Curve curve;

  /// Allineamento dell'animazione di ridimensionamento.
  final AlignmentGeometry alignment;

  @override
  State<AnimatedSizeX> createState() => _AnimatedSizeXState();
}

class _AnimatedSizeXState extends State<AnimatedSizeX> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: widget.duration,
      curve: widget.curve,
      alignment: widget.alignment,
      clipBehavior: Clip.none,
      vsync: this,
      child: widget.child,
    );
  }
}
