import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/leaderboard/domain/leaderboard_entry.dart';

/// Pagina con classifica locale mock per mostrare punti e reputazione.
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final repository = context.read<GameRepository>();
    final municipalityId = context.read<AppPrefs>().municipalityId ?? 'demo';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const IconLabel(
            icon: AppIcons.leaderboard,
            text: 'Classifica locale',
          ),
          const SizedBox(height: AppTokens.s12),
          FcPanel(
            padding: const EdgeInsets.all(AppTokens.s16),
            tint: AppTokens.blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top 10 Fanta Comune', style: textTheme.titleLarge),
                const SizedBox(height: AppTokens.s8),
                Text(
                  'Punteggi e reputazione locale: scopri dove ti posizioni rispetto agli altri cittadini.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.s12),
                FutureBuilder<List<LeaderboardEntry>>(
                  future: repository.getLeaderboard(
                    municipalityId: municipalityId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppTokens.s24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.s16,
                        ),
                        child: Text(
                          'Impossibile caricare la classifica: ${snapshot.error}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      );
                    }

                    final entries = snapshot.data ?? [];
                    if (entries.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.s16,
                        ),
                        child: Text(
                          'Nessuna classifica disponibile per ora.',
                          style: textTheme.bodyMedium,
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final isMe = entry.userId == repository.currentUserId;
                        final rankColor = switch (entry.rank) {
                          1 => colorScheme.primary,
                          2 => colorScheme.tertiary,
                          3 => colorScheme.secondary,
                          _ => colorScheme.onSurfaceVariant,
                        };

                        return Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.s8,
                              vertical: AppTokens.s8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radius,
                              ),
                            ),
                            tileColor: isMe
                                ? colorScheme.primaryContainer.withOpacity(0.5)
                                : null,
                            leading: CircleAvatar(
                              backgroundColor: rankColor.withOpacity(0.12),
                              foregroundColor: rankColor,
                              child: Text(entry.rank.toString()),
                            ),
                            title: Text(
                              isMe
                                  ? '${entry.displayName} (Tu)'
                                  : entry.displayName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: isMe
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Affidabilità locale e contributi visibili solo qui',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Text(
                              '${entry.points} pt',
                              style: textTheme.titleMedium?.copyWith(
                                color: rankColor,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: AppTokens.s12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.go('/how-it-works'),
                    icon: const Icon(AppIcons.info),
                    label: const Text('Come funziona'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
