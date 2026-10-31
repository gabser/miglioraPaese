import 'package:flutter/material.dart';

import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Cartello d'ingresso al Comune, ispirato alla segnaletica stradale italiana.
class MunicipalitySign extends StatelessWidget {
  const MunicipalitySign({
    required this.name,
    this.compact = false,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final String name;
  final bool compact;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: AppTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.s8),
              side: const BorderSide(color: AppTokens.ink, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.s4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTokens.ink),
                    borderRadius: BorderRadius.circular(AppTokens.s4),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTokens.s16,
                      vertical: compact ? AppTokens.s12 : AppTokens.s20,
                    ),
                    child: Text(
                      name.toUpperCase(),
                      semanticsLabel: semanticLabel ?? 'Comune: $name',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTokens.ink,
                        fontSize: compact ? 20 : 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
