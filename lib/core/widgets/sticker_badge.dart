import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Badge pill moderno compatibile con la vecchia API degli sticker.
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

class _StickerBadgeState extends State<StickerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.normal);
    _pulse = Tween<double>(
      begin: 1,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.emphasize));
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StickerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate == widget.animate) return;
    if (widget.animate) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = widget.backgroundColor ?? colorScheme.primaryContainer;
    final foreground = widget.foregroundColor ?? colorScheme.primary;
    final scale = _pressed ? 0.98 : _pulse.value;

    final badge = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s12,
          vertical: AppTokens.s8,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: foreground.withOpacity(0.16)),
        ),
        child: Text(
          widget.label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
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
        borderRadius: BorderRadius.circular(999),
        focusColor: colorScheme.primary.withOpacity(0.1),
        hoverColor: colorScheme.primary.withOpacity(0.08),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(child: badge),
        ),
      ),
    );
  }
}
