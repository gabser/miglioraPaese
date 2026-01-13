import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';

/// Bottone principale con look da timbro cartaceo.
class StampActionButton extends StatefulWidget {
  const StampActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  State<StampActionButton> createState() => _StampActionButtonState();
}

class _StampActionButtonState extends State<StampActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    final ink = VintagePaper.inkStamp(scheme);

    final content = AnimatedScale(
      duration: AppMotion.fast,
      curve: AppMotion.emphasize,
      scale: _pressed ? 0.98 : 1,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16,
          vertical: AppTokens.s12,
        ),
        decoration: BoxDecoration(
          color: enabled ? VintagePaper.paperWarm(scheme) : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: ink, width: 2),
          boxShadow: _pressed ? VintagePaper.paperShadowSoft(scheme) : VintagePaper.paperShadowLifted(scheme),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 18, color: ink),
              const SizedBox(width: AppTokens.s8),
            ],
            Text(
              widget.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: InkWell(
          onTap: widget.onPressed,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          focusColor: VintagePaper.inkSoft(scheme).withOpacity(0.1),
          hoverColor: VintagePaper.inkSoft(scheme).withOpacity(0.08),
          child: content,
        ),
      ),
    );
  }
}
