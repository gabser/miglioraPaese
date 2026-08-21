import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Banner hero moderno per dashboard, turno e tabellone.
class GameBanner extends StatelessWidget {
  const GameBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cta,
    this.image,
    this.stickerLabel,
    this.shimmer = false,
  });

  final String title;
  final String subtitle;
  final Widget cta;
  final Widget? image;
  final String? stickerLabel;
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.of(context).size.width < 620;
    final height = isCompact ? 300.0 : 260.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTokens.navy, AppTokens.navyDark],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: isCompact ? -40 : 24,
              bottom: isCompact ? -42 : -28,
              child: Icon(
                Icons.location_city_outlined,
                size: isCompact ? 180 : 230,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Positioned(
              right: 22,
              top: 22,
              child: _SignalCluster(active: shimmer),
            ),
            if (image != null)
              Positioned(
                right: isCompact ? -20 : 28,
                bottom: 8,
                width: isCompact ? 132 : 190,
                height: isCompact ? 132 : 190,
                child: Opacity(opacity: 0.26, child: image!),
              ),
            Padding(
              padding: EdgeInsets.all(
                isCompact ? AppTokens.s16 : AppTokens.s24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stickerLabel != null) _BannerPill(label: stickerLabel!),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      title,
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.s8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.76),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? AppTokens.s12 : AppTokens.s16),
                  Align(alignment: Alignment.centerLeft, child: cta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerPill extends StatelessWidget {
  const _BannerPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s12,
          vertical: AppTokens.s8,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SignalCluster extends StatelessWidget {
  const _SignalCluster({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SignalDot(color: AppTokens.success, active: active),
        const SizedBox(width: AppTokens.s8),
        _SignalDot(color: AppTokens.warning, active: active),
        const SizedBox(width: AppTokens.s8),
        _SignalDot(color: AppTokens.danger, active: active),
      ],
    );
  }
}

class _SignalDot extends StatelessWidget {
  const _SignalDot({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: active ? 28 : 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(active ? 0.32 : 0.18),
            blurRadius: active ? 18 : 8,
          ),
        ],
      ),
    );
  }
}
