import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/presentation/widgets/trend_sparkline.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';

/// Pagina profilo che riassume preferenze e andamento reputazione.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<ReputationScore>? _history;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = context.read<GameRepository>();
      final municipalityId = context.read<AppPrefs>().municipalityId ?? 'demo';
      final history = await repository.getReputationHistory(municipalityId: municipalityId);
      if (!mounted) return;
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const IconLabel(icon: AppIcons.profile, text: 'Profilo'),
          const SizedBox(height: AppTokens.s12),
          _ReputationHistoryCard(
            history: _history,
            isLoading: _isLoading,
            error: _error,
            onRetry: _loadHistory,
          ),
          const SizedBox(height: AppTokens.s12),
          PrimaryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Identità e preferenze',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppTokens.s8),
                Text(
                  'Gestirai badge, impostazioni e cronologia delle tue scelte civiche.',
                  style: textTheme.bodyMedium,
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
          if (_error != null) ...[
            const SizedBox(height: AppTokens.s8),
            Text(
              _error!,
              style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReputationHistoryCard extends StatelessWidget {
  const _ReputationHistoryCard({
    required this.history,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final List<ReputationScore>? history;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  String _trendText(
    List<double> values, {
    required String positive,
    required String negative,
    required String flat,
  }) {
    if (values.length < 2) return 'Trend in formazione';
    final delta = values.last - values.first;
    if (delta.abs() < 3) return flat;
    return delta > 0 ? positive : negative;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final points = history?.map((e) => e.totalPoints.toDouble()).toList(growable: false) ?? const <double>[];
    final accuracy = history?.map((e) => (e.accuracy * 100).clamp(0, 100)).toList(growable: false) ?? const <double>[];
    final lastEntry = history != null && history!.isNotEmpty ? history!.last : null;
    final dimmed = (lastEntry?.predictionsCount ?? 0) < 6;

    return PrimaryCard(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Il tuo andamento',
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            'Uno sguardo leggero a punti e accuratezza negli ultimi turni.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTokens.s12),
          if (isLoading)
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppTokens.s8),
                Text(
                  'Carichiamo il tuo storico...',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            )
          else if (error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    error!,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Riprova'),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MiniTrendTile(
                    title: 'Punti totali',
                    color: colorScheme.primary,
                    values: points,
                    caption: _trendText(
                      points,
                      positive: 'Punti in crescita costante.',
                      negative: 'Punti in leggera flessione.',
                      flat: 'Punti stabili negli ultimi turni.',
                    ),
                    dimmed: dimmed,
                  ),
                ),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: _MiniTrendTile(
                    title: 'Accuratezza',
                    color: colorScheme.tertiary,
                    values: accuracy,
                    caption: _trendText(
                      accuracy,
                      positive: 'Precisione in crescita.',
                      negative: 'Precisione in lieve calo.',
                      flat: 'Precisione stabile e coerente.',
                    ),
                    dimmed: dimmed,
                  ),
                ),
              ],
            ),
            if (dimmed) ...[
              const SizedBox(height: AppTokens.s8),
              Text(
                'Trend in formazione: attendi altri esiti per un quadro più affidabile.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MiniTrendTile extends StatelessWidget {
  const _MiniTrendTile({
    required this.title,
    required this.color,
    required this.values,
    required this.caption,
    required this.dimmed,
  });

  final String title;
  final Color color;
  final List<double> values;
  final String caption;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppTokens.s8),
        TrendSparkline(
          values: values,
          color: color,
          dimmed: dimmed,
        ),
        const SizedBox(height: AppTokens.s8),
        Text(
          caption,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
