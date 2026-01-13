import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/game_banner.dart';
import 'package:fanta_comune/core/widgets/pinned_note.dart';
import 'package:fanta_comune/core/widgets/card_illustration_slot.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';

/// Pagina placeholder della Home con contenuti introduttivi.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final headerGap = isCompact ? AppTokens.s12 : AppTokens.s16;

    return Padding(
      padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameBanner(
            title: VenialCopy.homeBannerTitle.replaceAll('{app}', VenialCopy.appTitle),
            subtitle: VenialCopy.homeBannerSubtitle,
            shimmer: false,
            stickerLabel: VenialCopy.homeBannerSticker,
            cta: TextButton.icon(
              onPressed: () => context.go('/play'),
              icon: const Icon(AppIcons.play),
              label: const Text(VenialCopy.homeBannerCta),
            ),
            image: Align(
              alignment: Alignment.centerRight,
              child: CardIllustrationSlot(
                fallbackIcon: AppIcons.board,
                height: 90,
                compact: true,
              ),
            ),
          ),
          SizedBox(height: headerGap),
          IconLabel(
            icon: AppIcons.home,
            text: VenialCopy.homeWelcomeTitle.replaceAll('{app}', VenialCopy.appTitle),
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          Wrap(
            spacing: AppTokens.s12,
            runSpacing: AppTokens.s12,
            children: [
              SizedBox(
                width: isCompact ? double.infinity : 320,
                child: PinnedNote(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardIllustrationSlot(
                        fallbackIcon: AppIcons.info,
                        height: 60,
                        compact: true,
                      ),
                      const SizedBox(height: AppTokens.s12),
                      Text(
                        VenialCopy.homeCardTitle,
                        style: TypographyX.titleMedium(context)?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppTokens.s4),
                      Text(
                        VenialCopy.homeCardBody,
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppTokens.s12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => context.go('/how-it-works'),
                          icon: const Icon(AppIcons.info),
                          label: const Text(VenialCopy.ctaHowItWorks),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: isCompact ? double.infinity : 320,
                child: PinnedNote(
                  angle: 0.02,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardIllustrationSlot(
                        fallbackIcon: AppIcons.play,
                        height: 60,
                        compact: true,
                      ),
                      const SizedBox(height: AppTokens.s12),
                      Text(
                        VenialCopy.homePlayCardTitle,
                        style: TypographyX.titleMedium(context)?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppTokens.s4),
                      Text(
                        VenialCopy.homePlayCardBody,
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppTokens.s12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => context.go('/play'),
                          icon: const Icon(AppIcons.play),
                          label: const Text(VenialCopy.homePlayCardCta),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
