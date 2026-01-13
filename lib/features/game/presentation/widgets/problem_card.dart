import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_size_x.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/card_illustration_slot.dart';
import 'package:fanta_comune/core/widgets/segmented_choice.dart';
import 'package:fanta_comune/core/widgets/status_pill.dart';
import 'package:fanta_comune/core/widgets/stamp_badge.dart';
import 'package:fanta_comune/core/widgets/wax_seal_highlight.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/critical_insight.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/insight_history.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/reflection_question.dart';
import 'package:fanta_comune/features/game/presentation/widgets/insight_card.dart';
import 'package:fanta_comune/features/game/presentation/widgets/motivation_chips.dart';

/// Card premium per mostrare un problema con stato e azione di previsione.
class ProblemCard extends StatefulWidget {
  /// Crea una card tappabile e accessibile per il problema indicato.
  const ProblemCard({
    required this.problem,
    required this.selectedChoice,
    required this.selectedMotivations,
    required this.selectedConfidence,
    required this.reflectionQuestion,
    required this.selectedReflectionAnswer,
    required this.criticalInsights,
    required this.isCriticalInsightsLoading,
    required this.onSelectChoice,
    required this.onSelectMotivations,
    required this.onSelectConfidence,
    required this.onSelectReflectionAnswer,
    required this.onLoadCriticalInsights,
    this.onTap,
    this.onRefresh,
    this.result,
    this.insight,
    this.history,
    this.isHistoryLoading = false,
    this.onLoadHistory,
    super.key,
  });

  /// Problema da visualizzare.
  final Problem problem;

  /// Scelta corrente dell'utente su questo problema.
  final PredictionChoice? selectedChoice;

  /// Motivazioni attualmente selezionate.
  final List<MotivationKey> selectedMotivations;

  /// Livello di convinzione selezionato dall'utente.
  final HypothesisConfidence? selectedConfidence;

  /// Domanda di riflessione opzionale per il problema.
  final ReflectionQuestion? reflectionQuestion;

  /// Opzione selezionata per la domanda di riflessione.
  final int? selectedReflectionAnswer;

  /// Insight critici aggregati post-risoluzione.
  final List<CriticalInsight> criticalInsights;

  /// Indica se gli insight critici sono in caricamento.
  final bool isCriticalInsightsLoading;

  /// Callback al cambio di previsione.
  final ValueChanged<PredictionChoice> onSelectChoice;

  /// Callback al cambio motivazioni.
  final ValueChanged<List<MotivationKey>> onSelectMotivations;

  /// Callback al cambio livello di convinzione.
  final ValueChanged<HypothesisConfidence> onSelectConfidence;

  /// Callback al cambio risposta di riflessione.
  final ValueChanged<int> onSelectReflectionAnswer;

  /// Callback per caricare gli insight critici.
  final VoidCallback onLoadCriticalInsights;

  /// Callback opzionale al tap della card.
  final VoidCallback? onTap;

  /// Callback opzionale per aggiornare i dati del problema.
  final VoidCallback? onRefresh;

  /// Esito della previsione dopo la risoluzione del turno.
  final PredictionResult? result;

  /// Insight aggregato di riferimento, mostrato solo dopo il responso.
  final AggregatedInsight? insight;

  /// Storico sintetico degli insight per il problema, opzionale.
  final InsightHistory? history;

  /// Indica se il caricamento dello storico è in corso.
  final bool isHistoryLoading;

  /// Callback per avviare il recupero dello storico su richiesta.
  final VoidCallback? onLoadHistory;

  @override
  State<ProblemCard> createState() => _ProblemCardState();
}

class _ProblemCardState extends State<ProblemCard> {
  bool _isPressed = false;
  bool _isHovered = false;
  bool _justRevealed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() {
      _isPressed = value;
    });
  }

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() {
      _isHovered = value;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      _triggerRevealPulse();
    }
  }

  @override
  void didUpdateWidget(covariant ProblemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result == null && widget.result != null) {
      _triggerRevealPulse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final trend = widget.problem.trendPercent;
    final isPositive = trend >= 0;
    final trendPrefix = isPositive ? '↑' : '↓';
    final trendColor = isPositive ? colorScheme.primary : colorScheme.error;
    final trendText = '$trendPrefix${trend.abs()}%';
    final updatedHours = DateTime.now().difference(widget.problem.updatedAt).inHours;
    final statusColor = switch (widget.problem.status) {
      ProblemStatus.improving => colorScheme.primary,
      ProblemStatus.stable => colorScheme.tertiary,
      ProblemStatus.worsening => colorScheme.error,
    };
    final statusIcon = switch (widget.problem.status) {
      ProblemStatus.improving => Icons.trending_up,
      ProblemStatus.stable => Icons.drag_handle,
      ProblemStatus.worsening => Icons.trending_down,
    };
    final statusLabel = switch (widget.problem.status) {
      ProblemStatus.improving => VenialCopy.choiceImproveLabel.toLowerCase(),
      ProblemStatus.stable => VenialCopy.choiceStableLabel.toLowerCase(),
      ProblemStatus.worsening => VenialCopy.choiceWorsenLabel.toLowerCase(),
    };
    final hasResult = widget.result != null;
    final hasChoice = widget.selectedChoice != null;
    final tokenColor = _tokenColor(colorScheme, widget.selectedChoice);
    final showToken = hasChoice || hasResult;
    final isCompact = MediaQuery.of(context).size.width < 520;
    final sectionGap = isCompact ? AppTokens.s8 : AppTokens.s12;
    final borderColor = _justRevealed
        ? colorScheme.primary.withOpacity(0.8)
        : (hasResult ? colorScheme.primary.withOpacity(0.45) : colorScheme.outlineVariant);

    return Semantics(
      label: 'Problema ${widget.problem.title}, stato $statusLabel',
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            onHover: _setHovered,
            borderRadius: BorderRadius.circular(AppTokens.radius),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              decoration: BoxDecoration(
                color: VintagePaper.paperHigh(colorScheme),
                borderRadius: BorderRadius.circular(AppTokens.radius),
                border: Border.all(
                  color: borderColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(_isPressed ? 0.04 : (_isHovered ? 0.16 : 0.12)),
                    blurRadius: _isPressed ? 6 : (_isHovered ? 20 : 16),
                    offset: Offset(0, _isPressed ? 2 : (_isHovered ? 10 : 8)),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TilePatternPainter(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTokens.radius - 3),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -8,
                    top: -10,
                    child: _GlintOverlay(
                      isVisible: _isHovered || _isPressed,
                    ),
                  ),
                  if (showToken)
                    Positioned(
                      top: AppTokens.s12,
                      right: AppTokens.s12,
                      child: AnimatedScale(
                        duration: AppMotion.fast,
                        curve: Curves.easeOutBack,
                        scale: _justRevealed ? 1.12 : 1,
                        child: _TokenSpot(
                          color: tokenColor ?? VintagePaper.accentWax(colorScheme),
                          highlightColor: tokenColor ?? VintagePaper.accentWax(colorScheme),
                          hasResult: hasResult,
                        ),
                      ),
                    ),
                  if (hasResult)
                    Positioned(
                      bottom: AppTokens.s12,
                      right: AppTokens.s12,
                      child: AnimatedOpacity(
                        duration: AppMotion.fast,
                        opacity: _justRevealed ? 1 : 0.9,
                        child: AnimatedScale(
                          duration: AppMotion.fast,
                          curve: Curves.easeOutBack,
                          scale: _justRevealed ? 1.06 : 1,
                          child: StampBadge(
                            label: VenialCopy.stampResultLabel,
                            icon: Icons.check_circle_outline,
                            angle: 0.06,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppTokens.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isCompact) ...[
                          CardIllustrationSlot(
                            fallbackIcon: AppIcons.forProblemKey(widget.problem.key),
                            labelRibbon: widget.problem.zoneName ??
                                AppIcons.labelForProblemKey(widget.problem.key),
                            height: 90,
                            problemKey: widget.problem.key,
                          ),
                          SizedBox(height: sectionGap),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (isCompact) ...[
                              CardIllustrationSlot(
                                fallbackIcon: AppIcons.forProblemKey(widget.problem.key),
                                labelRibbon: widget.problem.zoneName ??
                                    AppIcons.labelForProblemKey(widget.problem.key),
                                height: 56,
                                compact: true,
                                problemKey: widget.problem.key,
                              ),
                              const SizedBox(width: AppTokens.s8),
                            ],
                            Container(
                              padding: const EdgeInsets.all(AppTokens.s12),
                              decoration: BoxDecoration(
                                color: trendColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(AppTokens.radius),
                              ),
                              child: Icon(
                                AppIcons.forProblemKey(widget.problem.key),
                                size: 28,
                                color: trendColor,
                              ),
                            ),
                            const SizedBox(width: AppTokens.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.problem.title,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (widget.problem.zoneName != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: AppTokens.s8),
                                      child: Text(
                                        widget.problem.zoneName!,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (widget.onRefresh != null)
                              IconButton(
                                tooltip: VenialCopy.problemRefreshTooltip,
                                onPressed: widget.onRefresh,
                                icon: const Icon(Icons.refresh),
                              ),
                            const SizedBox(width: AppTokens.s4),
                            Container(
                              padding: const EdgeInsets.all(AppTokens.s8),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(AppTokens.radius),
                              ),
                              child: Icon(
                                statusIcon,
                                size: 28,
                                color: statusColor,
                              ),
                          ),
                        ],
                      ),
                        SizedBox(height: sectionGap),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTokens.s12,
                                vertical: AppTokens.s8 / 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(AppTokens.radius),
                              ),
                              child: Text(
                                VenialCopy.boardTileLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTokens.s8),
                            Text(
                              '${VenialCopy.boardTileStatusLabel}: $statusLabel',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: sectionGap),
                        AnimatedSwitcherX(
                          duration: AppMotion.fast,
                          child: hasResult
                              ? _ResultBadge(result: widget.result!)
                              : _ChoiceSection(
                                  key: ValueKey('choice-${widget.problem.id}-primary'),
                                  selectedChoice: widget.selectedChoice,
                                  colorScheme: colorScheme,
                                  hasResult: false,
                                  onSelectChoice: widget.onSelectChoice,
                                ),
                        ),
                        if (hasResult) ...[
                          SizedBox(height: sectionGap),
                          AnimatedSwitcherX(
                            duration: AppMotion.normal,
                            switchInCurve: const Interval(0.2, 1, curve: AppMotion.standard),
                            child: widget.insight != null
                                ? InsightCard(
                                    key: ValueKey('insight-${widget.problem.id}-${widget.insight?.totalPredictions}'),
                                    insight: widget.insight!,
                                    userChoice: widget.selectedChoice,
                                    problemTitle: widget.problem.title,
                                    criticalInsights: widget.criticalInsights,
                                    isCriticalInsightsLoading: widget.isCriticalInsightsLoading,
                                    onLoadCriticalInsights: widget.onLoadCriticalInsights,
                                    history: widget.history,
                                    isHistoryLoading: widget.isHistoryLoading,
                                    onLoadHistory: widget.onLoadHistory,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                        if (!hasResult) ...[
                          SizedBox(height: sectionGap),
                          AnimatedSwitcherX(
                            duration: AppMotion.fast,
                            child: widget.selectedChoice != null
                                ? _ConfidenceSection(
                                    key: ValueKey('confidence-${widget.problem.id}-${widget.selectedChoice?.name}'),
                                    selectedConfidence: widget.selectedConfidence,
                                    onSelectConfidence: widget.onSelectConfidence,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                        if (!hasResult) ...[
                          SizedBox(height: sectionGap),
                          AnimatedSwitcherX(
                            duration: AppMotion.fast,
                            child: widget.selectedChoice != null
                                ? _MotivationSection(
                                    key: ValueKey('motivation-${widget.problem.id}-${widget.selectedChoice?.name}'),
                                    selectedMotivations: widget.selectedMotivations,
                                    onSelectMotivations: widget.onSelectMotivations,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                        if (!hasResult &&
                            widget.reflectionQuestion != null &&
                            widget.selectedChoice != null) ...[
                          SizedBox(height: sectionGap),
                          _ReflectionSection(
                            question: widget.reflectionQuestion!,
                            selectedOptionIndex: widget.selectedReflectionAnswer,
                            onSelectOption: widget.onSelectReflectionAnswer,
                          ),
                        ],
                        SizedBox(height: sectionGap),
                        AnimatedSwitcherX(
                          duration: AppMotion.fast,
                          child: hasResult
                              ? _ChoiceSection(
                                  key: ValueKey('choice-${widget.problem.id}-resolved'),
                                  selectedChoice: widget.selectedChoice,
                                  colorScheme: colorScheme,
                                  hasResult: true,
                                  onSelectChoice: widget.onSelectChoice,
                                )
                              : _StatusRow(
                                  status: widget.problem.status,
                                  trendText: trendText,
                                  trendColor: trendColor,
                                  updatedHours: updatedHours,
                                ),
                        ),
                        SizedBox(height: sectionGap),
                        AnimatedSwitcherX(
                          duration: AppMotion.fast,
                          child: hasResult
                              ? _StatusRow(
                                  status: widget.problem.status,
                                  trendText: trendText,
                                  trendColor: trendColor,
                                  updatedHours: updatedHours,
                                  subdued: true,
                                )
                              : _SelectionHint(selectedChoice: widget.selectedChoice),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? _tokenColor(ColorScheme colorScheme, PredictionChoice? choice) {
    if (choice == null) return null;
    return switch (choice) {
      PredictionChoice.improve => colorScheme.primary,
      PredictionChoice.stable => colorScheme.tertiary,
      PredictionChoice.worsen => colorScheme.error,
    };
  }

  void _triggerRevealPulse() {
    setState(() {
      _justRevealed = true;
    });
    Future.delayed(AppMotion.normal, () {
      if (!mounted) return;
      setState(() {
        _justRevealed = false;
      });
    });
  }
}

class _TokenSpot extends StatelessWidget {
  const _TokenSpot({
    required this.color,
    required this.highlightColor,
    required this.hasResult,
  });

  final Color color;
  final Color highlightColor;
  final bool hasResult;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        WaxSealHighlight(
          color: highlightColor,
          size: 34,
        ),
        AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: hasResult ? colorScheme.primaryContainer : color,
            shape: BoxShape.circle,
            border: Border.all(color: VintagePaper.inkStamp(colorScheme), width: 2),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            hasResult ? Icons.check_circle_outline : Icons.circle,
            size: 14,
            color: hasResult ? colorScheme.onPrimaryContainer : colorScheme.surface,
          ),
        ),
      ],
    );
  }
}

class _GlintOverlay extends StatelessWidget {
  const _GlintOverlay({required this.isVisible});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: isVisible ? 1 : 0,
      child: Transform.rotate(
        angle: -0.2,
        child: Container(
          width: 36,
          height: 12,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _TilePatternPainter extends CustomPainter {
  _TilePatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const spacing = 16.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x + 6, y + 6), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TilePatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.trendText,
    required this.trendColor,
    required this.updatedHours,
    this.subdued = false,
  });

  final ProblemStatus status;
  final String trendText;
  final Color trendColor;
  final int updatedHours;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        StatusPill(status: status),
        const SizedBox(width: AppTokens.s12),
        AnimatedSwitcherX(
          duration: AppMotion.fast,
          child: Text(
            trendText,
            key: ValueKey(trendText),
            style: textTheme.titleMedium?.copyWith(
              color: subdued ? colorScheme.onSurfaceVariant : trendColor,
              fontWeight: subdued ? FontWeight.w600 : textTheme.titleMedium?.fontWeight,
            ),
          ),
        ),
        const Spacer(),
        Text(
          VenialCopy.problemUpdatedTemplate.replaceAll('{hours}', '$updatedHours'),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MotivationSection extends StatelessWidget {
  const _MotivationSection({
    required this.selectedMotivations,
    required this.onSelectMotivations,
    super.key,
  });

  final List<MotivationKey> selectedMotivations;
  final ValueChanged<List<MotivationKey>> onSelectMotivations;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          VenialCopy.motivationPrompt,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        Text(
          VenialCopy.motivationHelper,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        MotivationChips(
          selected: selectedMotivations,
          onChanged: onSelectMotivations,
        ),
      ],
    );
  }
}

class _ConfidenceSection extends StatelessWidget {
  const _ConfidenceSection({
    required this.selectedConfidence,
    required this.onSelectConfidence,
    super.key,
  });

  final HypothesisConfidence? selectedConfidence;
  final ValueChanged<HypothesisConfidence> onSelectConfidence;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          VenialCopy.confidenceTitle,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        Wrap(
          spacing: AppTokens.s8,
          runSpacing: AppTokens.s8,
          children: [
            _confidenceChip(
              context,
              confidence: HypothesisConfidence.gutFeeling,
              label: VenialCopy.confidenceGutFeeling,
            ),
            _confidenceChip(
              context,
              confidence: HypothesisConfidence.considered,
              label: VenialCopy.confidenceConsidered,
            ),
            _confidenceChip(
              context,
              confidence: HypothesisConfidence.convinced,
              label: VenialCopy.confidenceConvinced,
            ),
          ],
        ),
      ],
    );
  }

  Widget _confidenceChip(
    BuildContext context, {
    required HypothesisConfidence confidence,
    required String label,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selectedConfidence == confidence,
      onSelected: (_) => onSelectConfidence(confidence),
    );
  }
}

class _ReflectionSection extends StatefulWidget {
  const _ReflectionSection({
    required this.question,
    required this.selectedOptionIndex,
    required this.onSelectOption,
  });

  final ReflectionQuestion question;
  final int? selectedOptionIndex;
  final ValueChanged<int> onSelectOption;

  @override
  State<_ReflectionSection> createState() => _ReflectionSectionState();
}

class _ReflectionSectionState extends State<_ReflectionSection> {
  bool _isExpanded = false;

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.s8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    VenialCopy.reflectionTitle,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        AnimatedSizeX(
          duration: AppMotion.fast,
          child: _isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.question.prompt,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTokens.s8),
                    Wrap(
                      spacing: AppTokens.s8,
                      runSpacing: AppTokens.s8,
                      children: List.generate(widget.question.options.length, (index) {
                        final option = widget.question.options[index];
                        final isSelected = widget.selectedOptionIndex == index;
                        return ChoiceChip(
                          label: Text(option),
                          selected: isSelected,
                          onSelected: (_) => widget.onSelectOption(index),
                        );
                      }),
                    ),
                    const SizedBox(height: AppTokens.s8),
                    Text(
                      VenialCopy.reflectionNotATest,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      VenialCopy.reflectionNoRightAnswer,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      VenialCopy.reflectionGutOk,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.selectedOptionIndex != null &&
                        widget.question.followUpCopy.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.s8),
                      Text(
                        widget.question.followUpCopy,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.selectedChoice,
    required this.colorScheme,
    required this.hasResult,
    required this.onSelectChoice,
    super.key,
  });

  final PredictionChoice? selectedChoice;
  final ColorScheme colorScheme;
  final bool hasResult;
  final ValueChanged<PredictionChoice> onSelectChoice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: hasResult ? 0.7 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasResult) ...[
            Text(
              VenialCopy.predictionPrompt,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.s8),
          ],
          SegmentedChoice<PredictionChoice>(
            value: selectedChoice,
            options: const [
              PredictionChoice.improve,
              PredictionChoice.stable,
              PredictionChoice.worsen,
            ],
            labelBuilder: (choice) => switch (choice) {
              PredictionChoice.improve => VenialCopy.choiceImproveLabel,
              PredictionChoice.stable => VenialCopy.choiceStableLabel,
              PredictionChoice.worsen => VenialCopy.choiceWorsenLabel,
            },
            optionBuilder: (choice, isSelected) {
              final (icon, color) = switch (choice) {
                PredictionChoice.improve => (AppIcons.spark, colorScheme.primary),
                PredictionChoice.stable => (Icons.remove, colorScheme.tertiary),
                PredictionChoice.worsen => (AppIcons.trendingDown, colorScheme.error),
              };

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? color : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTokens.s8),
                  Text(
                    switch (choice) {
                      PredictionChoice.improve => VenialCopy.choiceImproveLabel,
                      PredictionChoice.stable => VenialCopy.choiceStableLabel,
                      PredictionChoice.worsen => VenialCopy.choiceWorsenLabel,
                    },
                  ),
                ],
              );
            },
            onChanged: onSelectChoice,
          ),
        ],
      ),
    );
  }
}

class _SelectionHint extends StatelessWidget {
  const _SelectionHint({required this.selectedChoice});

  final PredictionChoice? selectedChoice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        opacity: selectedChoice != null ? 1 : 0,
        child: selectedChoice != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.s12,
                  vertical: AppTokens.s8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                ),
                child: Text(
                  VenialCopy.selectionRecorded,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.result});

  final PredictionResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final (text, color, textColor) = switch (result) {
      PredictionResult.correct => (VenialCopy.resultCorrect, colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      PredictionResult.partial => (VenialCopy.resultPartial, colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
      PredictionResult.wrong => (VenialCopy.resultWrong, colorScheme.errorContainer, colorScheme.onErrorContainer),
      PredictionResult.pending => (VenialCopy.resultPending, colorScheme.surfaceContainerHigh, colorScheme.onSurfaceVariant),
    };

    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: const Interval(0.12, 1, curve: AppMotion.standard),
      switchOutCurve: AppMotion.standard,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.12, 1, curve: AppMotion.standard),
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(result),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s12,
          vertical: AppTokens.s8,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Text(
          text,
          style: textTheme.bodySmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
