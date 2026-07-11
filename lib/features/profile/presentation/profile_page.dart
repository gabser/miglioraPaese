import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/presentation/widgets/trend_sparkline.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/features/profile/domain/perspective_role.dart';

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
  PerspectiveRole? _suggestedRole;
  bool _isLensLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadLensSuggestion();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = context.read<GameRepository>();
      final municipalityId = context.read<AppPrefs>().municipalityId ?? 'demo';
      final history = await repository.getReputationHistory(
        municipalityId: municipalityId,
      );
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

  Future<void> _loadLensSuggestion() async {
    setState(() {
      _isLensLoading = true;
    });
    try {
      final repository = context.read<GameRepository>();
      final municipalityId = context.read<AppPrefs>().municipalityId ?? 'demo';
      final turn = await repository.getCurrentTurn(municipalityId);
      final predictions = await repository.getMyPredictions(turn.id);
      final confidences = <String, HypothesisConfidence>{};
      final motivations = <String, List<MotivationKey>>{};
      for (final entry in predictions.entries) {
        final value = entry.value;
        if (value.confidence != null) {
          confidences[entry.key] = value.confidence!;
        }
        motivations[entry.key] = value.motivations;
      }

      final suggested = suggestPerspectiveRole(
        confidences: confidences,
        motivations: motivations,
        reflectionAnswers: const {},
      );
      if (!mounted) return;
      setState(() {
        _suggestedRole = suggested;
        _isLensLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLensLoading = false;
      });
    }
  }

  void _showPerspectivePicker(AppPrefs prefs, PerspectiveRole? active) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.s16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(VenialCopy.lensPickerTitle, style: textTheme.titleLarge),
                  const SizedBox(height: AppTokens.s8),
                  Text(
                    VenialCopy.lensPickerSubtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s12),
                  ...PerspectiveRole.values.map(
                    (role) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTokens.s12),
                      child: FcPanel(
                        onTap: () async {
                          await prefs.setActivePerspective(role);
                          await prefs.incrementPerspectiveChangesCount();
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(VenialCopy.lensChangedSnack),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusSmall,
                                ),
                              ),
                              child: Icon(
                                role.icon,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppTokens.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    role.label,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: AppTokens.s4),
                                  Text(
                                    role.shortDescription,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (active == role)
                              const Icon(Icons.check_circle_outline),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final prefs = context.watch<AppPrefs>();
    final activePerspective = prefs.getActivePerspective();
    final changesCount = prefs.perspectiveChangesCount;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final municipalityName = MunicipalityCatalog.displayNameFromId(
      prefs.municipalityId ?? 'demo',
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const IconLabel(
            icon: AppIcons.profile,
            text: VenialCopy.profileTitle,
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          FcPanel(
            padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
            tint: AppTokens.blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comune', style: TypographyX.titleLarge(context)),
                const SizedBox(height: AppTokens.s8),
                Text(
                  municipalityName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppTokens.s4),
                Text(
                  'Cambia Comune per testare o seguire un altro territorio.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.s12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/change-municipality'),
                    icon: const Icon(AppIcons.home),
                    label: const Text('Cambia Comune'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          FcPanel(
            padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
            tint: AppTokens.success,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  VenialCopy.lensSectionTitle,
                  style: TypographyX.titleLarge(context),
                ),
                const SizedBox(height: AppTokens.s8),
                Text(
                  VenialCopy.lensSectionSubtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
                if (activePerspective != null)
                  Row(
                    children: [
                      FcStatusChip(
                        label: activePerspective.label,
                        color: AppTokens.blue,
                        icon: activePerspective.icon,
                      ),
                      const SizedBox(width: AppTokens.s8),
                      Expanded(
                        child: Text(
                          '${activePerspective.label} · ${activePerspective.shortDescription}',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    VenialCopy.lensSectionEmpty,
                    style: textTheme.bodyMedium,
                  ),
                const SizedBox(height: AppTokens.s8),
                if (_isLensLoading)
                  Text(
                    VenialCopy.lensSuggestionLoading,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else if (_suggestedRole != null)
                  Text(
                    VenialCopy.lensSuggestionTemplate.replaceAll(
                      '{role}',
                      _suggestedRole!.label,
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _showPerspectivePicker(prefs, activePerspective),
                    icon: const Icon(AppIcons.profile),
                    label: const Text(VenialCopy.lensChangeCta),
                  ),
                ),
                if (changesCount > 0) ...[
                  const SizedBox(height: AppTokens.s8),
                  Text(
                    VenialCopy.lensChangeCountTemplate.replaceAll(
                      '{count}',
                      '$changesCount',
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          _ReputationHistoryCard(
            history: _history,
            isLoading: _isLoading,
            error: _error,
            onRetry: _loadHistory,
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          FcPanel(
            padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  VenialCopy.profileIdentityTitle,
                  style: TypographyX.titleLarge(context),
                ),
                const SizedBox(height: AppTokens.s8),
                Text(
                  VenialCopy.profileIdentityBody,
                  style: textTheme.bodyMedium,
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
          if (_error != null) ...[
            const SizedBox(height: AppTokens.s8),
            Text(
              _error!,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
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
    List<num> values, {
    required String positive,
    required String negative,
    required String flat,
  }) {
    if (values.length < 2) return VenialCopy.trendLowDataLabel;
    final delta = values.last - values.first;
    if (delta.abs() < 3) return flat;
    return delta > 0 ? positive : negative;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final points =
        history?.map((e) => e.totalPoints.toDouble()).toList(growable: false) ??
        const <double>[];
    final accuracy =
        history
            ?.map((e) => (e.accuracy * 100).clamp(0, 100))
            .toList(growable: false) ??
        const <double>[];
    final lastEntry = history != null && history!.isNotEmpty
        ? history!.last
        : null;
    final dimmed = (lastEntry?.predictionsCount ?? 0) < 6;

    return FcPanel(
      padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
      tint: AppTokens.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            VenialCopy.reputationTitle,
            style: TypographyX.titleLarge(context),
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            VenialCopy.reputationHelper,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
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
                  VenialCopy.profileHistoryLoading,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          else if (error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    error!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text(VenialCopy.retryCta),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MiniTrendTile(
                    title: VenialCopy.profileTrendPointsTitle,
                    color: colorScheme.primary,
                    values: points,
                    caption: _trendText(
                      points,
                      positive: VenialCopy.profileTrendPointsUp,
                      negative: VenialCopy.profileTrendPointsDown,
                      flat: VenialCopy.profileTrendPointsFlat,
                    ),
                    dimmed: dimmed,
                  ),
                ),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: _MiniTrendTile(
                    title: VenialCopy.profileTrendAccuracyTitle,
                    color: colorScheme.tertiary,
                    values: accuracy,
                    caption: _trendText(
                      accuracy,
                      positive: VenialCopy.profileTrendAccuracyUp,
                      negative: VenialCopy.profileTrendAccuracyDown,
                      flat: VenialCopy.profileTrendAccuracyFlat,
                    ),
                    dimmed: dimmed,
                  ),
                ),
              ],
            ),
            if (dimmed) ...[
              const SizedBox(height: AppTokens.s8),
              Text(
                VenialCopy.trendLowDataHelper,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
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
  final List<num> values;
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
        TrendSparkline(values: values, color: color, dimmed: dimmed),
        const SizedBox(height: AppTokens.s8),
        Text(
          caption,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
