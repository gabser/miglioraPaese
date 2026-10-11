import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/leaderboard/domain/leaderboard_entry.dart';

/// Classifica locale con dati del repository di gioco mock.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  String? _municipality;
  Future<List<LeaderboardEntry>>? _entries;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final municipality = context.watch<AppPrefs>().municipalityId ?? 'demo';
    if (_municipality == municipality) return;
    _municipality = municipality;
    _reload();
  }

  void _reload() {
    _entries = context.read<GameRepository>().getLeaderboard(
      municipalityId: _municipality!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final currentUser = context.read<GameRepository>().currentUserId;
    return SingleChildScrollView(
      child: FcPageShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FcSectionHeader(
              title: 'Classifica locale',
              subtitle:
                  'Comune: ${MunicipalityCatalog.displayNameFromId(_municipality!)} · Gioco delle previsioni',
            ),
            const SizedBox(height: AppTokens.s16),
            FcPanel(
              tint: AppTokens.blue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Punti e reputazione', style: theme.titleLarge),
                  const SizedBox(height: AppTokens.s8),
                  const Text(
                    'Questi punteggi appartengono al gioco delle previsioni: non sono una valutazione ufficiale dei cittadini.',
                  ),
                  const SizedBox(height: AppTokens.s16),
                  FutureBuilder<List<LeaderboardEntry>>(
                    future: _entries,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'La classifica non è disponibile. Puoi riprovare.',
                            ),
                            TextButton(
                              key: const ValueKey('leaderboard-retry'),
                              onPressed: () => setState(_reload),
                              child: const Text('Riprova'),
                            ),
                          ],
                        );
                      }
                      final entries = snapshot.data ?? [];
                      if (entries.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Non ci sono ancora punteggi per questo Comune.',
                            ),
                            const SizedBox(height: AppTokens.s12),
                            const Text(
                              'Puoi iniziare proponendo un problema o consultando i temi già raccolti.',
                            ),
                            const SizedBox(height: AppTokens.s12),
                            FilledButton(
                              onPressed: () => context.go('/suggest-problem'),
                              child: const Text('Proponi un problema'),
                            ),
                            TextButton(
                              onPressed: () => context.go('/next-problems'),
                              child: const Text('Vedi le proposte'),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          for (final entry in entries) ...[
                            Container(
                              key: ValueKey('leaderboard-${entry.userId}'),
                              padding: const EdgeInsets.all(AppTokens.s12),
                              decoration: BoxDecoration(
                                color: entry.userId == currentUser
                                    ? scheme.primaryContainer
                                    : scheme.surface,
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusSmall,
                                ),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: scheme.primaryContainer,
                                    foregroundColor: AppTokens.blueForeground,
                                    child: Text('${entry.rank}'),
                                  ),
                                  const SizedBox(width: AppTokens.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.userId == currentUser
                                              ? '${entry.displayName} (Tu)'
                                              : entry.displayName,
                                          style: theme.titleMedium?.copyWith(
                                            fontWeight:
                                                entry.userId == currentUser
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: AppTokens.s4),
                                        Text(
                                          '${entry.points} pt',
                                          style: theme.bodyLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppTokens.s8),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppTokens.s12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/how-it-works'),
                      child: const Text('Come funziona'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
