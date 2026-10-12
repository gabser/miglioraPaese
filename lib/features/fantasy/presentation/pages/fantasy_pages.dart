import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/features/fantasy/presentation/pages/remote_leagues_page.dart';
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
                          Expanded(
                            child: Text(
                              'Fanta Comune',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
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
    final municipality = MunicipalityCatalog.displayNameFromId(
      context.watch<AppPrefs>().municipalityId ?? 'demo',
    );
    return Scaffold(
      appBar: AppBar(title: Text('Manager civico · $municipality')),
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
      child: SizedBox(
        width: 252,
        child: SingleChildScrollView(
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
                        current == item.$1
                            ? item.$2.selectedIcon
                            : item.$2.icon,
                      ),
                      title: Text(item.$2.label),
                      onTap: () => onSelect(item.$1),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  color: AppTokens.navy,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      context.watch<FantasyManager>().isRemote
                          ? 'Sessione API\nDati sintetici. Esiti e fonti sempre distinguibili.'
                          : 'Stagione demo\nDati mock locali e verificabilità sempre visibile.',
                      style: TextStyle(color: Colors.white, height: 1.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    final saved = manager.confirmed && manager.persistenceError == null;
    return FantasyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(
            eyebrow:
                '${manager.season.name} · Giornata ${manager.season.currentMatchday}/${manager.season.totalMatchdays}',
            title: 'La mia squadra',
            subtitle:
                'Schiera le priorità del Comune e metti alla prova le tue previsioni.',
            trailing: CreditPill(
              credits: manager.budgetRemaining,
              label: 'crediti rimasti',
            ),
          ),
          const SizedBox(height: 12),
          _MatchdaySchedule(day: manager.matchday),
          const SizedBox(height: 12),
          FcPanel(
            padding: const EdgeInsets.all(12),
            tint: manager.persistenceError != null
                ? AppTokens.warning
                : saved
                ? AppTokens.success
                : AppTokens.blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      Icon(
                        manager.persistenceError != null
                            ? Icons.error_outline
                            : manager.isLocked
                            ? Icons.lock_outline
                            : saved
                            ? Icons.check_circle
                            : Icons.groups_outlined,
                        color: manager.persistenceError != null
                            ? AppTokens.danger
                            : saved
                            ? AppTokens.success
                            : AppTokens.blueForeground,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          manager.persistenceError != null
                              ? 'Salvataggio non completato'
                              : manager.isLocked
                              ? 'Formazione bloccata'
                              : issue ??
                                    (saved
                                        ? 'Squadra salvata'
                                        : 'Formazione da confermare'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  manager.persistenceError != null
                      ? 'Usa Riprova salvataggio prima di continuare. Lo stato della giornata resta da verificare.'
                      : manager.isLocked
                      ? 'Le scelte sono congelate. Consulta Giornata per gli esiti e i punti.'
                      : saved
                      ? 'Parteciperai con questi titolari al blocco. Ogni modifica richiede una nuova conferma.'
                      : 'Usa Sostituisci per far entrare una riserva. Scegli il capitano: vale ×1,5 punti.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          issue == null &&
                              !manager.confirmed &&
                              !manager.isLocked &&
                              !manager.busy
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
                    OutlinedButton.icon(
                      onPressed: () => context.go('/matchday'),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        manager.isLocked
                            ? 'Consulta la giornata'
                            : 'Vai alle previsioni',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (manager.canRestartDemo) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: manager.busy ? null : () => manager.restartDemo(),
                  icon: const Icon(Icons.replay),
                  label: const Text('Nuova partita demo'),
                ),
                if (manager.hasPreviousDemo)
                  TextButton(
                    onPressed: manager.busy
                        ? null
                        : () => manager.restartDemo(restorePrevious: true),
                    child: const Text('Riprendi partita precedente'),
                  ),
              ],
            ),
            const Text(
              'Riparti con scelte aperte. La partita precedente resta recuperabile.',
            ),
          ],
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
            title: manager.persistenceError != null
                ? 'Giornata da verificare'
                : manager.isLocked
                ? 'Giornata bloccata'
                : 'Fai le tue previsioni',
            subtitle:
                'Le risposte degli altri manager restano nascoste fino al blocco.',
          ),
          const SizedBox(height: 12),
          _MatchdaySchedule(day: manager.matchday),
          const SizedBox(height: 12),
          FcPanel(
            tint: manager.isLocked ? AppTokens.warning : AppTokens.blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  manager.persistenceError != null
                      ? 'Stato della giornata da verificare'
                      : manager.isLocked
                      ? (manager.now.isBefore(
                              manager.matchday.observationEndsAt,
                            )
                            ? '3. Attendi gli esiti verificati'
                            : '3. Consulta esiti e punti')
                      : '2. Prevedi il cambiamento',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  manager.persistenceError != null
                      ? 'Gli ultimi dati non sono confermati. Usa Riprova salvataggio prima di continuare.'
                      : manager.isLocked
                      ? (manager.now.isBefore(
                              manager.matchday.observationEndsAt,
                            )
                            ? 'Le scelte sono congelate. La finestra di osservazione termina il ${_dateTime(manager.matchday.observationEndsAt)}: gli esiti disponibili e le fonti sono mostrati sotto.'
                            : 'L’osservazione è terminata. Consulta sotto gli esiti pubblicati e il dettaglio dei punti; per gli esiti mancanti attendi la pubblicazione della fonte.')
                      : 'Le previsioni sono facoltative e salvate quando le scegli. Per ottenere punti personali serve una formazione valida e confermata al blocco. Le motivazioni non aggiungono punti.',
                ),
                if (!manager.isLocked && !manager.confirmed)
                  TextButton(
                    onPressed: () => context.go('/squad'),
                    child: const Text('Conferma la formazione in Squadra'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MatchdayProgress(
            now: manager.now,
            locked:
                manager.snapshotFor(manager.matchday.id) != null ||
                manager.matchday.isLockedAt(manager.now),
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
            manager.isRemote ? 'Esiti e fonti' : 'Esiti e fonti · demo',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (manager.outcomes.isEmpty)
            const FcPanel(
              child: Text(
                'Nessun esito disponibile. Le previsioni restano salvate; consulta questa giornata dopo il termine dell’osservazione.',
              ),
            ),
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
          FcPanel(
            tint: manager.isLocked ? AppTokens.warning : AppTokens.blue,
            child: Text(
              manager.isLocked
                  ? 'Mercato chiuso per questa giornata. Puoi consultare le carte: i trasferimenti restano bloccati.'
                  : 'Scegli una carta della rosa da cedere, poi confronta la sostituta. Prima del trasferimento vedrai crediti e penalità; dopo il cambio riconferma la formazione.',
            ),
          ),
          const SizedBox(height: 16),
          if (candidates.isEmpty)
            const FcPanel(
              child: Text(
                'Nessuna carta per questo ruolo. Prova il filtro Tutti.',
              ),
            ),
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
                          'Consulta le proposte civiche del Comune. Invio e voti non assegnano carte Manager.',
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/next-problems'),
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
            const Text(
              'I punti delle carte derivano dall’esito osservato e dalle previsioni facoltative. Il capitano moltiplica i punti base per 1,5; le riflessioni confermate aggiungono il bonus previsto.',
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
    if (manager.isRemote) return const RemoteLeaguesPage();
    final league = manager.leagues[_municipal ? 1 : 0];
    return FantasyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PageHeader(
            eyebrow: 'Competizione rispettosa',
            title: 'Leghe',
            subtitle:
                'Confronta i punti fantasy nella lega privata o del Comune. Questi dati demo sono separati da reputazione e voti delle proposte.',
          ),
          const SizedBox(height: 16),
          const FcPanel(
            tint: AppTokens.blue,
            child: Text(
              'La classifica confronta i punti fantasy. Il punteggio cooperativo del Comune è un indicatore separato: non è la somma dei voti alle proposte.',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: const Text('Lega privata'),
                ),
                selected: !_municipal,
                avatar: const Icon(Icons.lock_outline),
                onSelected: (_) => setState(() => _municipal = false),
              ),
              ChoiceChip(
                label: const Text('Comune'),
                selected: _municipal,
                avatar: const Icon(Icons.location_city_outlined),
                onSelected: (_) => setState(() => _municipal = true),
              ),
            ],
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

class _MatchdaySchedule extends StatelessWidget {
  const _MatchdaySchedule({required this.day});
  final model.Matchday day;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.clamp(0.0, 680.0).toDouble();
      final columns = MediaQuery.textScalerOf(context).scale(12) > 18 ? 1 : 3;
      final itemWidth = (width - (columns - 1) * 8) / columns;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in [
                ('Inizio giornata', day.startsAt),
                ('Blocco delle scelte', day.locksAt),
                ('Fine osservazione', day.observationEndsAt),
              ])
                Container(
                  width: itemWidth,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateTime(item.$2).replaceFirst(' alle ', ' '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Orari del dispositivo',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
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
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppTokens.blueForeground,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (trailing != null) ...[const SizedBox(height: 12), trailing!],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            if (trailing != null) ...[const SizedBox(width: 24), trailing!],
          ],
        );
      },
    );
  }
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

String _dateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month} alle ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
