import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart'
    hide FantasyCard;
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart'
    as model;
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import 'package:fanta_comune/features/fantasy/presentation/widgets/fantasy_widgets.dart';

class FantasyWelcomePage extends StatelessWidget {
  const FantasyWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<FantasyManager>();
    if (!manager.hasData) return const FantasyLoadingPage();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final intro = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTokens.navy,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'FC',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Fanta Comune',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Costruisci la tua squadra di priorità locali.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTokens.navy,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Schiera, prevedi, scopri come cambia il Comune.',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => context.go('/squad'),
                            icon: const Icon(Icons.groups_outlined),
                            label: const Text('Crea la tua rosa'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/squad'),
                            icon: const Icon(Icons.play_arrow_outlined),
                            label: const Text('Prova una formazione demo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Dati demo locali: nessuna informazione rappresenta una condizione reale certificata.',
                      ),
                    ],
                  );
                  final preview = Transform.rotate(
                    angle: wide ? -0.025 : 0,
                    child: FantasyCard(
                      card: manager.cards.first,
                      isCaptain: true,
                      prediction: CivicTrend.improves,
                    ),
                  );
                  if (!wide) {
                    return Column(
                      children: [intro, const SizedBox(height: 28), preview],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 6, child: intro),
                      const SizedBox(width: 52),
                      Expanded(flex: 4, child: preview),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FantasyShellPage extends StatelessWidget {
  const FantasyShellPage({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= AppTokens.desktopBreakpoint;
    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _FantasySidebar(
                current: navigationShell.currentIndex,
                onSelect: _select,
              ),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
        destinations: _destinations
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FantasySidebar extends StatelessWidget {
  const _FantasySidebar({required this.current, required this.onSelect});
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPrefs>();
    final municipality = MunicipalityCatalog.displayNameFromId(
      prefs.municipalityId ?? 'demo',
    );
    return Material(
      color: Colors.white,
      child: Container(
        width: 252,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppTokens.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTokens.navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'FC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fanta Comune',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(municipality, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ..._destinations.indexed.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  selected: current == item.$1,
                  selectedTileColor: AppTokens.blueSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    current == item.$1 ? item.$2.selectedIcon : item.$2.icon,
                  ),
                  title: Text(item.$2.label),
                  onTap: () => onSelect(item.$1),
                ),
              ),
            ),
            const Spacer(),
            const Card(
              color: AppTokens.navy,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Stagione demo\nDati mock locali e verificabilità sempre visibile.',
                  style: TextStyle(color: Colors.white, height: 1.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _destinations = [
  _Destination(Icons.groups_outlined, Icons.groups, 'Squadra'),
  _Destination(Icons.event_note_outlined, Icons.event_note, 'Giornata'),
  _Destination(Icons.storefront_outlined, Icons.storefront, 'Mercato'),
  _Destination(Icons.emoji_events_outlined, Icons.emoji_events, 'Leghe'),
  _Destination(Icons.person_outline, Icons.person, 'Profilo'),
];

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class SquadPage extends StatelessWidget {
  const SquadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<FantasyManager>();
    if (!manager.hasData) return const FantasyLoadingPage();
    final issue = manager.lineupIssue;
    return FantasyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(
            eyebrow:
                '${manager.season.name} · Giornata ${manager.season.currentMatchday}/${manager.season.totalMatchdays}',
            title: 'La mia squadra',
            subtitle:
                'Otto priorità locali e cinque titolari. Senza formazione valida e confermata al blocco non ricevi punti. Dopo ogni cambio, conferma di nuovo.',
            trailing: CreditPill(
              credits: manager.budgetRemaining,
              label: 'crediti rimasti',
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: issue == null
                ? AppTokens.successSoft
                : AppTokens.warningSoft,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    issue == null
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      manager.isLocked
                          ? 'Giornata bloccata: formazione e previsioni non sono più modificabili.'
                          : issue ??
                                (manager.confirmed
                                    ? 'Formazione confermata. Puoi modificarla fino al blocco.'
                                    : 'Formazione completa e pronta per la conferma.'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SquadBoard(
            locked: manager.isLocked || manager.busy,
            starters: manager.starterCards,
            reserves: manager.benchCards,
            captainId: manager.captainId,
            onCaptain: manager.setCaptain,
            onSwap: (starterId, reserveId) =>
                manager.swapCards(starterId: starterId, reserveId: reserveId),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: issue == null && !manager.isLocked && !manager.busy
                ? () async {
                    final confirmed = await manager.confirmLineup();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          confirmed
                              ? 'Formazione confermata per la giornata.'
                              : manager.persistenceError ??
                                    'Giornata bloccata: conferma non consentita.',
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              manager.confirmed
                  ? 'Formazione confermata'
                  : 'Conferma formazione',
            ),
          ),
        ],
      ),
    );
  }
}

class MatchdayPage extends StatelessWidget {
  const MatchdayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<FantasyManager>();
    if (!manager.hasData) return const FantasyLoadingPage();
    return FantasyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(
            eyebrow: 'Giornata ${manager.matchday.number}',
            title: 'Fai le tue previsioni',
            subtitle:
                'Le risposte degli altri manager restano nascoste fino al blocco.',
          ),
          const SizedBox(height: 16),
          MatchdayProgress(
            now: manager.now,
            locked: manager.isLocked || manager.busy,
            completed: manager.predictionsCompleted,
            total: manager.starterIds.length,
            locksAt: manager.matchday.locksAt,
          ),
          const SizedBox(height: 16),
          ...manager.starterCards.map(
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FantasyCard(
                card: card,
                compact: true,
                isCaptain: card.id == manager.captainId,
                prediction: manager.predictions[card.id],
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Come cambierà nella finestra indicata?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CivicTrend.values
                          .map(
                            (trend) => ChoiceChip(
                              label: Text(trend.label),
                              selected: manager.predictions[card.id] == trend,
                              onSelected: manager.isLocked || manager.busy
                                  ? null
                                  : (_) =>
                                        manager.setPrediction(card.id, trend),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Aggiungi una motivazione facoltativa'),
                      children: [
                        if (manager.isRemote)
                          _RemoteMotivation(
                            manager: manager,
                            cardId: card.id,
                            key: ValueKey(
                              'remote-${manager.matchday.id}-${card.id}',
                            ),
                          )
                        else
                          TextFormField(
                            key: ValueKey(
                              'motivation-${manager.matchday.id}-${card.id}',
                            ),
                            initialValue: manager.motivations[card.id] ?? '',
                            enabled: !manager.isLocked && !manager.loading,
                            onChanged: (text) =>
                                manager.setMotivation(card.id, text),
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText:
                                  'Quale segnale ti ha portato a questa previsione?',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MatchdaySummary(manager: manager),
          const SizedBox(height: 16),
          Text(
            'Reveal e fonti · demo',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          ...manager.outcomes.map(
            (outcome) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ScoreReveal(
                card: manager.cardById(outcome.cardId),
                outcome: outcome,
                score: manager.scoreFor(outcome),
                prediction: manager.predictionFor(outcome),
                personal: manager.hasPersonalResult(outcome),
                reflection: manager.reflectionFor(outcome),
                onReflection: manager.busy
                    ? null
                    : (answer) => manager.submitReflection(outcome, answer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});
  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  String? _outgoingId;
  FantasyRole? _filter;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<FantasyManager>();
    if (!manager.hasData) return const FantasyLoadingPage();
    if (!manager.squadIds.contains(_outgoingId)) {
      _outgoingId = manager.squadIds.first;
    }
    final candidates = manager.marketCards
        .where((card) => _filter == null || card.role == _filter)
        .toList();
    return FantasyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(
            eyebrow:
                '${manager.transfersRemaining} trasferimenti gratuiti rimasti',
            title: 'Mercato',
            subtitle:
                'Due trasferimenti gratuiti per giornata, poi −4 punti ciascuno. Il mercato chiude al blocco. Le carte sono condivise fra manager.',
            trailing: CreditPill(
              credits: manager.budgetRemaining,
              label: 'crediti',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(_outgoingId),
            isExpanded: true,
            initialValue: _outgoingId,
            decoration: const InputDecoration(
              labelText: 'Carta da confrontare o cedere',
            ),
            items: manager.squadCards
                .map(
                  (card) => DropdownMenuItem(
                    value: card.id,
                    child: Text(
                      '${card.title} · ${card.price} cr',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: manager.isLocked
                ? null
                : (value) => setState(() => _outgoingId = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Tutti'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              ...FantasyRole.values.map(
                (role) => FilterChip(
                  label: Text(role.label),
                  selected: _filter == role,
                  onSelected: (_) => setState(() => _filter = role),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 920
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: candidates
                    .map(
                      (card) => SizedBox(
                        width: width,
                        child: FantasyCard(
                          card: card,
                          footer: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Popolarità ${card.popularity}%'),
                              if (manager.purchaseIssue(card)
                                  case final String issue)
                                Text(issue),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: manager.purchaseIssue(card) != null
                                    ? null
                                    : () => _compare(context, manager, card),
                                icon: const Icon(Icons.compare_arrows),
                                label: const Text('Confronta e acquista'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 32),
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proposte della comunità',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Una proposta moderata e approvata può entrare nel mercato successivo.',
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/next-problems'),
                    child: const Text('Apri proposte'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _compare(
    BuildContext context,
    FantasyManager manager,
    model.FantasyCard incoming,
  ) async {
    final outgoing = manager.cardById(_outgoingId!);
    final quote = await manager.quoteTransfer(outgoing.id, incoming.id);
    if (!context.mounted) return;
    if (manager.isRemote && quote == null) return;
    final penalty = quote?.penalty ?? manager.nextTransferPenalty;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer<FantasyManager>(
        builder: (_, current, _) => MarketComparison(
          outgoing: outgoing,
          incoming: incoming,
          penalty: penalty,
          outgoingPrice: quote?.outgoingPrice,
          incomingPrice: quote?.incomingPrice,
          onConfirm: current.busy
              ? null
              : () async {
                  final error = await manager.transfer(
                    outgoingId: outgoing.id,
                    incomingId: incoming.id,
                    expectedPenalty: penalty,
                    quote: quote,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!mounted || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'Trasferimento completato.'),
                    ),
                  );
                  if (error == null) setState(() => _outgoingId = incoming.id);
                },
        ),
      ),
    );
  }
}

class _MatchdaySummary extends StatelessWidget {
  const _MatchdaySummary({required this.manager});
  final FantasyManager manager;

  @override
  Widget build(BuildContext context) {
    final result = manager.scoreForMatchday(manager.matchday.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Totale personale giornata ${manager.matchday.number}: ${result.total} punti',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Punti congelati ${result.frozenPoints} · bonus riflessione ${result.reflectionBonus} · penalità trasferimenti −${result.transferPenalty}',
            ),
            if (!manager.isLocked)
              const Text(
                'Il totale sarà calcolato dalla formazione confermata al blocco e dagli esiti verificati al termine dell’osservazione.',
              ),
            if (manager.isLocked && !result.eligible)
              const Text(
                'Formazione non valida o non confermata al blocco: nessun punto personale.',
              ),
            Text(
              manager.isRemote
                  ? 'Dati sintetici dal server · ${manager.summaryStatus(manager.matchday.id) == 'final' ? 'Definitivo' : 'Provvisorio'}. Punteggio cooperativo non disponibile.'
                  : 'Dati demo locali. Il punteggio cooperativo è separato.',
            ),
          ],
        ),
      ),
    );
  }
}

class LeaguesPage extends StatefulWidget {
  const LeaguesPage({super.key});
  @override
  State<LeaguesPage> createState() => _LeaguesPageState();
}

class _LeaguesPageState extends State<LeaguesPage> {
  bool _municipal = false;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<FantasyManager>();
    if (!manager.hasData) return const FantasyLoadingPage();
    if (manager.isRemote)
      return const FantasyPage(
        child: Text('Leghe remote non ancora disponibili.'),
      );
    final league = manager.leagues[_municipal ? 1 : 0];
    return FantasyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PageHeader(
            eyebrow: 'Competizione rispettosa',
            title: 'Leghe',
            subtitle:
                'Le formazioni avversarie diventano visibili soltanto dopo il lock.',
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Lega privata'),
                icon: Icon(Icons.lock_outline),
              ),
              ButtonSegment(
                value: true,
                label: Text('Comune'),
                icon: Icon(Icons.location_city_outlined),
              ),
            ],
            selected: {_municipal},
            onSelectionChanged: (value) =>
                setState(() => _municipal = value.first),
          ),
          const SizedBox(height: 16),
          Text(league.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          LeagueTable(league: league),
          const SizedBox(height: 16),
          if (manager.communityScore case final int score)
            CommunityScore(value: score)
          else
            const Text('Punteggio cooperativo non disponibile.'),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTokens.blue,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ],
  );
}

class _RemoteMotivation extends StatefulWidget {
  const _RemoteMotivation({
    required this.manager,
    required this.cardId,
    super.key,
  });
  final FantasyManager manager;
  final String cardId;
  @override
  State<_RemoteMotivation> createState() => _RemoteMotivationState();
}

class _RemoteMotivationState extends State<_RemoteMotivation> {
  late final TextEditingController controller = TextEditingController(
    text: widget.manager.motivations[widget.cardId] ?? '',
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        controller: controller,
        enabled: !widget.manager.isLocked && !widget.manager.busy,
        maxLength: 1000,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Motivazione facoltativa'),
      ),
      TextButton(
        onPressed: widget.manager.isLocked || widget.manager.busy
            ? null
            : () =>
                  widget.manager.setMotivation(widget.cardId, controller.text),
        child: const Text('Salva motivazione'),
      ),
    ],
  );
}
