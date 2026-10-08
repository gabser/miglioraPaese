import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart'
    as model;

Color roleColor(model.FantasyRole role) => switch (role) {
  model.FantasyRole.mobility => const Color(0xFF2563EB),
  model.FantasyRole.environment => const Color(0xFF16835D),
  model.FantasyRole.servicesAndSafety => const Color(0xFF7C3AED),
};

IconData roleIcon(model.FantasyRole role) => switch (role) {
  model.FantasyRole.mobility => Icons.directions_bus_outlined,
  model.FantasyRole.environment => Icons.park_outlined,
  model.FantasyRole.servicesAndSafety => Icons.shield_outlined,
};

class FantasyPage extends StatelessWidget {
  const FantasyPage({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppTokens.s16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTokens.maxContentWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Consumer<FantasyManager>(
              builder: (context, manager, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (manager.recoveryMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(manager.recoveryMessage!),
                    ),
                  if (manager.persistenceError != null)
                    Card(
                      color: AppTokens.warningSoft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              manager.persistenceError!,
                              semanticsLabel: manager.persistenceError,
                            ),
                            TextButton(
                              onPressed: manager.retrySave,
                              child: const Text('Riprova salvataggio'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Demo locale · carte, fonti e classifiche simulate.'),
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({required this.role, this.compact = false, super.key});
  final model.FantasyRole role;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    return Semantics(
      label: 'Ruolo ${role.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(roleIcon(role), size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                role.label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreditPill extends StatelessWidget {
  const CreditPill({required this.credits, this.label = 'crediti', super.key});
  final int credits;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppTokens.warningSoft,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppTokens.warning.withValues(alpha: 0.45)),
    ),
    child: Text(
      '$credits $label',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: const Color(0xFF765000),
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class FormIndicator extends StatelessWidget {
  const FormIndicator({required this.form, super.key});
  final List<model.CivicTrend> form;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Forma civica: ${form.map((item) => item.label).join(', ')}',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Forma', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(width: 6),
        ...form.map(
          (trend) => Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Icon(
              switch (trend) {
                model.CivicTrend.improves => Icons.arrow_upward,
                model.CivicTrend.stable => Icons.remove,
                model.CivicTrend.worsens => Icons.arrow_downward,
              },
              size: 17,
              color: switch (trend) {
                model.CivicTrend.improves => AppTokens.success,
                model.CivicTrend.stable => AppTokens.warning,
                model.CivicTrend.worsens => AppTokens.danger,
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class SourceBadge extends StatelessWidget {
  const SourceBadge({required this.status, super.key});
  final model.FantasySourceStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      model.FantasySourceStatus.verified => (
        Icons.verified_outlined,
        AppTokens.success,
      ),
      model.FantasySourceStatus.pending => (
        Icons.schedule_outlined,
        AppTokens.warning,
      ),
      model.FantasySourceStatus.unavailable => (
        Icons.block_outlined,
        AppTokens.muted,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            status.label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class CaptainBadge extends StatelessWidget {
  const CaptainBadge({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Capitano, punteggio moltiplicato per 1,5',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTokens.navy,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'C · ×1,5',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class FantasyCard extends StatelessWidget {
  const FantasyCard({
    required this.card,
    this.compact = false,
    this.isCaptain = false,
    this.isReserve = false,
    this.prediction,
    this.footer,
    super.key,
  });
  final model.FantasyCard card;
  final bool compact;
  final bool isCaptain;
  final bool isReserve;
  final model.CivicTrend? prediction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(card.role);
    return Semantics(
      container: true,
      label:
          '${card.title}, ${card.zone}, ruolo ${card.role.label}, ${card.price} crediti',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UrbanScene(
              keyName: card.illustrationKey,
              role: card.role,
              height: compact ? 84 : 132,
            ),
            Padding(
              padding: const EdgeInsets.all(AppTokens.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RoleBadge(role: card.role, compact: true),
                      ),
                      const SizedBox(width: 8),
                      CreditPill(credits: card.price, label: 'cr'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    card.zone,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (compact)
                    Row(
                      children: [
                        Expanded(child: FormIndicator(form: card.form)),
                        if (isCaptain) const CaptainBadge(),
                      ],
                    )
                  else ...[
                    FormIndicator(form: card.form),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 17,
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Osservazione: ${card.observationWindow}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SourceBadge(status: card.sourceStatus),
                    Text(card.sourceLabel),
                    if (card.sourceUpdatedAt != null)
                      Text('Aggiornamento: ${_date(card.sourceUpdatedAt!)}'),
                    if (prediction != null) ...[
                      const SizedBox(height: 8),
                      Text('Previsione: ${prediction!.label}'),
                    ],
                  ],
                  if (isCaptain || isReserve) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isCaptain) const CaptainBadge(),
                        if (isReserve)
                          const Chip(
                            avatar: Icon(Icons.weekend_outlined, size: 18),
                            label: Text('Riserva'),
                          ),
                      ],
                    ),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    footer!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SquadBoard extends StatelessWidget {
  const SquadBoard({
    required this.starters,
    required this.reserves,
    required this.captainId,
    required this.onCaptain,
    required this.onSwap,
    this.locked = false,
    super.key,
  });
  final List<model.FantasyCard> starters;
  final List<model.FantasyCard> reserves;
  final String captainId;
  final bool locked;
  final ValueChanged<String> onCaptain;
  final void Function(String starterId, String reserveId) onSwap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Titolari · 5', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      _CardGrid(
        cards: starters,
        builder: (card) => FantasyCard(
          card: card,
          compact: true,
          isCaptain: card.id == captainId,
          footer: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: locked ? null : () => onCaptain(card.id),
                icon: const Icon(Icons.star_outline),
                label: const Text('Capitano'),
              ),
              PopupMenuButton<String>(
                enabled: !locked,
                tooltip: 'Metti in panchina',
                onSelected: (reserveId) => onSwap(card.id, reserveId),
                itemBuilder: (context) => reserves
                    .map(
                      (reserve) => PopupMenuItem(
                        value: reserve.id,
                        child: Text('Sostituisci con ${reserve.title}'),
                      ),
                    )
                    .toList(),
                child: const _ActionLabel(
                  icon: Icons.swap_horiz,
                  label: 'Sostituisci',
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text('Riserve · 3', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      _CardGrid(
        cards: reserves,
        maxColumns: 3,
        builder: (card) =>
            FantasyCard(card: card, compact: true, isReserve: true),
      ),
    ],
  );
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.cards,
    required this.builder,
    this.maxColumns = 3,
  });
  final List<model.FantasyCard> cards;
  final Widget Function(model.FantasyCard card) builder;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 980
          ? maxColumns
          : constraints.maxWidth >= 620
          ? maxColumns.clamp(1, 2)
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map((card) => SizedBox(width: width, child: builder(card)))
            .toList(),
      );
    },
  );
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon), const SizedBox(width: 8), Text(label)],
    ),
  );
}

class MarketComparison extends StatelessWidget {
  const MarketComparison({
    required this.outgoing,
    required this.incoming,
    required this.onConfirm,
    required this.penalty,
    super.key,
  });
  final model.FantasyCard outgoing;
  final model.FantasyCard incoming;
  final VoidCallback onConfirm;
  final int penalty;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confronta il trasferimento'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ComparisonRow(label: 'Esce', card: outgoing),
        const Divider(height: 24),
        _ComparisonRow(label: 'Entra', card: incoming),
        const SizedBox(height: 12),
        Text('Differenza: ${incoming.price - outgoing.price} crediti'),
        Text(
          penalty == 0
              ? 'Trasferimento gratuito'
              : 'Penalità: −$penalty punti nella giornata',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton(onPressed: onConfirm, child: const Text('Conferma')),
    ],
  );
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.label, required this.card});
  final String label;
  final model.FantasyCard card;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 52, child: Text(label)),
      Expanded(
        child: Text(
          card.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      CreditPill(credits: card.price, label: 'cr'),
    ],
  );
}

class MatchdayProgress extends StatelessWidget {
  const MatchdayProgress({
    required this.completed,
    required this.total,
    required this.locksAt,
    required this.now,
    required this.locked,
    super.key,
  });
  final int completed;
  final int total;
  final DateTime locksAt;
  final DateTime now;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final remaining = locksAt.difference(now);
    final time = locked
        ? 'Formazione bloccata'
        : '${remaining.inDays}g ${remaining.inHours.remainder(24)}h al blocco';
    return Card(
      color: AppTokens.navy,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  '$completed/$total previsioni inserite',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                Text(time, style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              minHeight: 8,
              color: const Color(0xFF67E8B6),
              backgroundColor: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreReveal extends StatelessWidget {
  const ScoreReveal({
    required this.card,
    required this.outcome,
    required this.score,
    required this.prediction,
    required this.personal,
    this.reflection,
    this.onReflection,
    super.key,
  });
  final model.FantasyCard card;
  final model.CardOutcome outcome;
  final model.ScoreBreakdown score;
  final model.CivicTrend? prediction;
  final bool personal;
  final model.ReflectionAnswer? reflection;
  final ValueChanged<model.ReflectionAnswer>? onReflection;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Previsione: ${prediction?.label ?? 'non inserita'}'),
          Text('Esito osservato: ${outcome.observed.label}'),
          const SizedBox(height: 8),
          Text(outcome.explanation),
          const SizedBox(height: 8),
          SourceBadge(status: outcome.sourceStatus),
          Text('${outcome.sourceLabel} · ${_date(outcome.sourceDate)}'),
          const Divider(height: 24),
          if (!personal)
            const Text(
              'Esempio demo o esito non valido per la tua formazione: nessun punto personale.',
            ),
          if (personal)
            Text(
              '${score.total} punti · punti congelati ${score.frozenTotal}, bonus riflessione ${score.reflectionBonus}${score.captainMultiplier > 1 ? ', capitano ×1,5' : ''}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          if (personal && reflection != null)
            Text('Riflessione confermata: ${reflection!.label}'),
          if (personal && reflection == null) ...[
            const SizedBox(height: 12),
            const Text(
              'Quale segnale ha spiegato meglio l’esito? La prima risposta confermata vale +1 punto base.',
            ),
            ...model.ReflectionAnswer.values.map(
              (answer) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: onReflection == null
                      ? null
                      : () => onReflection!(answer),
                  child: Text('Conferma: ${answer.label}'),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class LeagueTable extends StatelessWidget {
  const LeagueTable({required this.league, super.key});
  final model.FantasyLeague league;

  @override
  Widget build(BuildContext context) {
    if (!league.isVisible) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'La classifica sarà visibile al raggiungimento della soglia minima di partecipazione.',
          ),
        ),
      );
    }
    return Card(
      child: Column(
        children: league.entries
            .map(
              (entry) => Container(
                color: entry.isCurrentUser ? AppTokens.blueSoft : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        '#${entry.rank}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.displayName,
                        style: TextStyle(
                          fontWeight: entry.isCurrentUser
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    Text('${entry.points} pt'),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class CommunityScore extends StatelessWidget {
  const CommunityScore({required this.value, super.key});
  final int value;

  @override
  Widget build(BuildContext context) => Card(
    color: AppTokens.successSoft,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, size: 34, color: AppTokens.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Punteggio cooperativo del Comune',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Misura osservazioni verificate e partecipazione, separato dalla classifica.',
                ),
              ],
            ),
          ),
          Text(
            '$value/100',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

class _UrbanScene extends StatelessWidget {
  const _UrbanScene({
    required this.keyName,
    required this.role,
    required this.height,
  });
  final String keyName;
  final model.FantasyRole role;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    final icon = switch (keyName) {
      'road' => Icons.add_road,
      'bus' => Icons.directions_bus,
      'crosswalk' => Icons.directions_walk,
      'bike' => Icons.directions_bike,
      'park' => Icons.park,
      'waste' => Icons.delete_outline,
      'tree' => Icons.nature,
      'water' => Icons.water_drop_outlined,
      'light' => Icons.lightbulb_outline,
      'office' => Icons.apartment,
      'stop' => Icons.accessible,
      _ => Icons.local_library_outlined,
    };
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.28),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: height * 0.24,
                color: color.withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 10,
              child: Icon(
                Icons.location_city,
                size: height * 0.48,
                color: color.withValues(alpha: 0.3),
              ),
            ),
            Center(
              child: Icon(icon, size: height * 0.48, color: color),
            ),
            Positioned(
              right: 16,
              top: 12,
              child: Icon(
                Icons.wb_sunny_outlined,
                size: 24,
                color: color.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
