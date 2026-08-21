import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// CTA primaria compatibile con la vecchia API dei bottoni "stamp".
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
          color: enabled ? scheme.primary : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: scheme.primary.withOpacity(_pressed ? 0.14 : 0.22),
                    blurRadius: _pressed ? 8 : 18,
                    offset: Offset(0, _pressed ? 4 : 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 18,
                color: enabled ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTokens.s8),
            ],
            Text(
              widget.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: enabled ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
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
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          focusColor: scheme.primary.withOpacity(0.12),
          hoverColor: scheme.primary.withOpacity(0.08),
          child: content,
        ),
      ),
    );
  }
}
