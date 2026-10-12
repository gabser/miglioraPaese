import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

class FcPanel extends StatelessWidget {
  const FcPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.s16),
    this.onTap,
    this.tint,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppTokens.radius);
    final panel = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: radius,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(elevated ? 0.1 : 0.045),
            blurRadius: elevated ? 24 : 14,
            offset: Offset(0, elevated ? 14 : 8),
          ),
        ],
      ),
      child: tint == null
          ? Padding(padding: padding, child: child)
          : ClipRRect(
              borderRadius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [tint!.withOpacity(0.12), scheme.surface],
                  ),
                ),
                child: Padding(padding: padding, child: child),
              ),
            ),
    );

    if (onTap == null) return panel;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: radius, child: panel),
    );
  }
}

class FcSectionHeader extends StatelessWidget {
  const FcSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: textTheme.titleLarge),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppTokens.s4),
          Text(
            subtitle!,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (action != null) ...[
                const SizedBox(height: AppTokens.s8),
                action!,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            if (action != null) ...[
              const SizedBox(width: AppTokens.s12),
              action!,
            ],
          ],
        );
      },
    );
  }
}

class FcStatusChip extends StatelessWidget {
  const FcStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final foreground = AppTokens.foregroundFor(color);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s12,
        vertical: AppTokens.s8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: AppTokens.s8),
          ],
          Flexible(
            child: Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FcMetricCard extends StatelessWidget {
  const FcMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return FcPanel(
      padding: const EdgeInsets.all(AppTokens.s12),
      tint: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FcPredictionBar extends StatelessWidget {
  const FcPredictionBar({
    super.key,
    required this.improve,
    required this.stable,
    required this.worsen,
    this.height = 9,
  });

  final double improve;
  final double stable;
  final double worsen;
  final double height;

  @override
  Widget build(BuildContext context) {
    double safe(double value) => value.isFinite && value > 0 ? value : 0;
    final values = [safe(improve), safe(stable), safe(worsen)];
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final colors = [AppTokens.success, AppTokens.warning, AppTokens.danger];
    final label = total == 0
        ? 'Nessuna previsione disponibile'
        : 'Previsioni: migliora ${(values[0] / total * 100).round()}%, '
              'stabile ${(values[1] / total * 100).round()}%, '
              'peggiora ${(values[2] / total * 100).round()}%';

    return Semantics(
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: height,
          child: total == 0
              ? const ColoredBox(color: AppTokens.line)
              : Row(
                  children: [
                    for (var index = 0; index < values.length; index++)
                      if (values[index] > 0)
                        _Segment(
                          value: values[index] / total,
                          color: colors[index],
                        ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final flex = (value * 1000).round().clamp(1, 1000).toInt();
    return Expanded(
      flex: flex,
      child: ColoredBox(color: color),
    );
  }
}

class FcPageShell extends StatelessWidget {
  const FcPageShell({
    super.key,
    required this.child,
    this.maxWidth = AppTokens.maxContentWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final resolvedPadding =
        padding ?? EdgeInsets.all(width < 600 ? AppTokens.s12 : AppTokens.s20);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: resolvedPadding, child: child),
      ),
    );
  }
}

/// Material locale e identità di storage distinta dalla posizione dello scroll.
class FcDisclosure extends StatelessWidget {
  const FcDisclosure({
    super.key,
    required this.storageId,
    required this.title,
    required this.children,
    this.controller,
  });

  final ExpansibleController? controller;
  final String storageId;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ExpansionTile(
      key: PageStorageKey<String>(storageId),
      controller: controller,
      title: Text(title),
      // Nested scrollables must not read ExpansionTile's boolean storage value.
      children: [
        for (var index = 0; index < children.length; index++)
          KeyedSubtree(
            key: PageStorageKey<String>('$storageId:child:$index'),
            child: children[index],
          ),
      ],
    ),
  );
}
