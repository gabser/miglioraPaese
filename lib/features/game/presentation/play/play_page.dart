import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';
import 'package:fanta_comune/core/widgets/status_pill.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';

/// Pagina della sezione di gioco che mostra i problemi del turno corrente.
class PlayPage extends StatefulWidget {
  const PlayPage({super.key});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  late final Future<List<Problem>> _problemsFuture;

  @override
  void initState() {
    super.initState();
    final repo = context.read<GameRepository>();
    final prefs = context.read<AppPrefs>();
    final municipalityId = prefs.municipalityId ?? 'demo';
    _problemsFuture = repo.listProblems(municipalityId);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const IconLabel(icon: AppIcons.play, text: 'Gioca e fai previsioni'),
          const SizedBox(height: AppTokens.s12),
          PrimaryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Problemi da monitorare',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppTokens.s8),
                Text(
                  'Dati mock in-memory per collegare la UI in attesa del backend.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.s12),
                FutureBuilder<List<Problem>>(
                  future: _problemsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Errore nel caricamento dei problemi',
                        style: textTheme.bodyMedium,
                      );
                    }
                    final problems = snapshot.data ?? [];
                    if (problems.isEmpty) {
                      return Text(
                        'Nessun problema attivo per questo turno.',
                        style: textTheme.bodyMedium,
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < problems.length; i++) ...[
                          _ProblemTile(problem: problems[i]),
                          if (i != problems.length - 1)
                            const Divider(height: AppTokens.s12),
                        ],
                      ],
                    );
                  },
                ),
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

class _ProblemTile extends StatelessWidget {
  const _ProblemTile({required this.problem});

  final Problem problem;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final zone = problem.zoneName == null ? '' : ' · ${problem.zoneName}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(AppIcons.forProblemKey(problem.key)),
      title: Text(
        problem.title,
        style: textTheme.titleMedium,
      ),
      subtitle: Text(
        '${AppIcons.labelForProblemKey(problem.key)}$zone',
        style: textTheme.bodySmall,
      ),
      trailing: StatusPill(status: problem.status),
    );
  }
}
