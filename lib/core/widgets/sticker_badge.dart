import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';

/// Badge inclinato per enfatizzare contenuti in stile boardgame.
class StickerBadge extends StatefulWidget {
  const StickerBadge({
    super.key,
    required this.label,
    this.animate = false,
    this.backgroundColor,
    this.foregroundColor,
    this.enablePress = false,
  });

  final String label;
  final bool animate;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool enablePress;

  @override
  State<StickerBadge> createState() => _StickerBadgeState();
}

class _StickerBadgeState extends State<StickerBadge> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _wobble;
  late Animation<double> _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _configureAnimation();
  }

  @override
  void didUpdateWidget(covariant StickerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      _configureAnimation();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = widget.backgroundColor ?? VintagePaper.paperWarm(colorScheme);
    final foreground = widget.foregroundColor ?? VintagePaper.inkStamp(colorScheme);
    final scale = _pressed ? 0.98 : (_pulse.value);

    final badge = Transform.rotate(
      angle: _wobble.value,
      child: AnimatedScale(
        duration: AppMotion.fast,
        scale: scale,
        curve: AppMotion.emphasize,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s12,
            vertical: AppTokens.s8 / 2,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppTokens.radius),
            border: Border.all(color: VintagePaper.inkStamp(colorScheme), width: 2),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
          ),
        ),
      ),
    );

    if (!widget.enablePress) {
      return badge;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        borderRadius: BorderRadius.circular(AppTokens.radius),
        focusColor: VintagePaper.inkSoft(colorScheme).withOpacity(0.1),
        hoverColor: VintagePaper.inkSoft(colorScheme).withOpacity(0.08),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(child: badge),
        ),
      ),
    );
  }

  void _configureAnimation() {
    _controller?.dispose();
    if (!widget.animate) {
      _controller = null;
      _wobble = const AlwaysStoppedAnimation(0);
      _pulse = const AlwaysStoppedAnimation(1);
      return;
    }

    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    )..repeat(reverse: true);
    _wobble = Tween<double>(
      begin: -0.021,
      end: 0.021,
    ).animate(
      CurvedAnimation(parent: _controller!, curve: AppMotion.emphasize),
    );
    _pulse = Tween<double>(begin: 1, end: 1.02).animate(
      CurvedAnimation(parent: _controller!, curve: AppMotion.emphasize),
    );
  }
}
