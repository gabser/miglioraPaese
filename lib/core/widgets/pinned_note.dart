import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';
import 'package:fanta_comune/core/widgets/paper_texture.dart';

/// Card di carta con pin e nastro, in stile nota appuntata.
class PinnedNote extends StatelessWidget {
  const PinnedNote({
    super.key,
    required this.child,
    this.tape = true,
    this.angle,
  });

  final Widget child;
  final bool tape;
  final double? angle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tilt = angle ?? VintagePaper.noteTiltSmall;

    return Transform.rotate(
      angle: tilt,
      child: Container(
        decoration: VintagePaper.surfaceDecoration(scheme, elevated: true),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PaperTexture(
                  color: VintagePaper.inkSoft(scheme).withOpacity(0.08),
                  variant: PaperTextureVariant.fiber,
                  intensity: 0.4,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: VintagePaper.doubleBorder(
                  scheme,
                  radius: AppTokens.radius - 3,
                  outer: VintagePaper.paperEdge(scheme).withOpacity(0.6),
                ),
              ),
            ),
            if (tape)
              Positioned(
                left: AppTokens.s12,
                top: AppTokens.s8,
                child: Transform.rotate(
                  angle: -0.1,
                  child: Container(
                    width: 48,
                    height: 12,
                    decoration: VintagePaper.tapeDecoration(scheme),
                  ),
                ),
              ),
            Positioned(
              right: AppTokens.s16,
              top: AppTokens.s8,
              child: Container(
                width: 12,
                height: 12,
                decoration: VintagePaper.pinDecoration(scheme),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTokens.s12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
