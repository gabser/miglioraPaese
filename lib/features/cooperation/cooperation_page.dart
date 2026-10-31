import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/features/review/data/review_repository.dart';
import 'package:fanta_comune/features/measurements/logic/measurement_controller.dart';
import 'cooperation_controller.dart';
import 'cooperation_repository.dart';
import 'cooperation_models.dart';

class CoverageCard extends StatelessWidget {
  const CoverageCard(this.progress, {super.key});
  final CooperationProgress progress;
  Widget _coverage(String label, CooperativeCoverage c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label),
      Text('${c.validated} / ${c.expected} unità luogo/finestra validate'),
      if (c.ratio != null)
        LinearProgressIndicator(
          value: c.ratio,
          semanticsLabel: label,
          semanticsValue: '${(c.ratio! * 100).round()}%',
        )
      else
        const Text('Obiettivo non disponibile per questo periodo.'),
    ],
  );
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            progress.title ?? 'Nessun obiettivo pubblicato',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Stagione ${progress.seasonId} · giornata ${progress.matchdayId}',
          ),
          _coverage(
            progress.leagueId == null
                ? 'Progresso del Comune'
                : 'Progresso della lega',
            progress.coverage,
          ),
          if (progress.municipal != null) ...[
            const SizedBox(height: 16),
            _coverage('Progresso del Comune', progress.municipal!),
          ],
          const SizedBox(height: 8),
          const Text(
            'Una finestra di un luogo conta una volta. Copertura condivisa, distinta da XP e punti fantasy. Nessuna classifica personale delle sentinelle.',
          ),
        ],
      ),
    ),
  );
}

class CooperationPage extends StatefulWidget {
  const CooperationPage({this.inbox = false, this.followed = false, super.key});
  final bool inbox, followed;
  @override
  State<CooperationPage> createState() => _CooperationPageState();
}

class _CooperationPageState extends State<CooperationPage> {
  final season = TextEditingController(), day = TextEditingController();
  bool initialized = false;
  void load() {
    final c = context.read<CooperationController>();
    if (widget.inbox)
      c.loadInbox();
    else if (widget.followed)
      c.loadPlaces();
    else
      c.loadProgress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  @override
  void didUpdateWidget(CooperationPage old) {
    super.didUpdateWidget(old);
    if (old.inbox != widget.inbox || old.followed != widget.followed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  @override
  void dispose() {
    season.dispose();
    day.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CooperationController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.inbox
              ? 'Inbox'
              : widget.followed
              ? 'Luoghi seguiti'
              : 'Cooperazione',
        ),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: c.busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          maxWidth: 960,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Comune: ${c.repository.municipalityId}'),
              if (c.busy) const LinearProgressIndicator(),
              if (c.error != null)
                Semantics(liveRegion: true, child: Text(c.error!)),
              if (widget.inbox) ...[
                Text(
                  '${c.unread} messaggi non letti',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'I tuoi aggiornamenti, anche su un altro dispositivo.',
                ),
                if (!c.busy && c.messages.isEmpty)
                  const Text('Nessun messaggio disponibile.'),
                for (final m in c.messages)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            m.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${m.createdAt.toLocal()} · ${m.readAt == null ? "Non letto" : "Letto"}',
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: c.busy
                                    ? null
                                    : () async {
                                        final route = await c.resolve(
                                          m,
                                          context.read<ReviewRepository>(),
                                          context.read<MeasurementController>(),
                                        );
                                        if (context.mounted && route != null)
                                          context.go(route);
                                      },
                                child: const Text('Consulta dettaglio'),
                              ),
                              if (m.readAt == null)
                                TextButton(
                                  onPressed: c.busy
                                      ? null
                                      : () => c.markRead(m),
                                  child: const Text('Segna come letto'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (c.cursor != null)
                  FilledButton.tonal(
                    onPressed: c.busy ? null : () => c.loadInbox(more: true),
                    child: const Text('Carica altri messaggi'),
                  ),
              ] else if (widget.followed) ...[
                const Text(
                  'Segui un luogo dal dettaglio di una missione o di un esito. Aprire una pagina non iscrive agli aggiornamenti.',
                ),
                if (!c.busy && c.places.isEmpty)
                  const Text('Non segui ancora alcun luogo.'),
                for (final p in c.places)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(p.name),
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () => c.setFollow(p.id, false),
                            child: const Text('Non seguire più'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                ExpansionTile(
                  title: const Text('Consulta un altro periodo'),
                  children: [
                    TextField(
                      controller: season,
                      decoration: const InputDecoration(
                        labelText: 'ID stagione pubblicata',
                      ),
                    ),
                    TextField(
                      controller: day,
                      decoration: const InputDecoration(
                        labelText: 'ID giornata pubblicata',
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: c.busy
                              ? null
                              : () {
                                  if (season.text.trim().isEmpty ||
                                      day.text.trim().isEmpty)
                                    return;
                                  c.repository.selectScope(
                                    season.text.trim(),
                                    day.text.trim(),
                                  );
                                  load();
                                },
                          child: const Text('Consulta periodo'),
                        ),
                        TextButton(
                          onPressed: c.busy
                              ? null
                              : () {
                                  c.repository.selectScope(null, null);
                                  load();
                                },
                          child: const Text('Periodo corrente'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (c.progress != null) CoverageCard(c.progress!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LeagueCooperationPanel extends StatefulWidget {
  const LeagueCooperationPanel({
    required this.leagueId,
    required this.seasonId,
    this.archived = false,
    super.key,
  });
  final String leagueId, seasonId;
  final bool archived;
  @override
  State<LeagueCooperationPanel> createState() => _LeagueCooperationPanelState();
}

class _LeagueCooperationPanelState extends State<LeagueCooperationPanel> {
  CooperationProgress? progress;
  String? error;
  int generation = 0;
  CooperationRepository? repository;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = context.read<CooperationRepository>();
    if (repository != r) {
      repository?.removeListener(changed);
      repository = r;
      r.addListener(changed);
    }
  }

  void changed() {
    generation++;
    if (mounted)
      setState(() {
        progress = null;
        error = null;
      });
  }

  Future<void> load() async {
    final g = ++generation;
    try {
      final p = await repository!.progress(
        leagueId: widget.leagueId,
        leagueSeasonId: widget.seasonId,
      );
      if (mounted && g == generation) setState(() => progress = p);
    } catch (_) {
      if (mounted && g == generation)
        setState(() => error = 'Progresso non disponibile. Riprova.');
    }
  }

  @override
  void dispose() {
    generation++;
    repository?.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Cooperazione'),
    onExpansionChanged: (open) {
      if (open && progress == null) load();
    },
    children: [
      if (widget.archived) const Text('Lega archiviata: progresso congelato.'),
      if (error != null) Text(error!),
      if (progress != null) CoverageCard(progress!),
      TextButton(onPressed: load, child: const Text('Aggiorna cooperazione')),
    ],
  );
}

class FollowPlaceButton extends StatefulWidget {
  const FollowPlaceButton(this.placeId, {super.key});
  final String placeId;
  @override
  State<FollowPlaceButton> createState() => _FollowPlaceButtonState();
}

class _FollowPlaceButtonState extends State<FollowPlaceButton> {
  bool? following;
  bool busy = false;
  String? error;
  int generation = 0;
  CooperationRepository? repository;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = context.read<CooperationRepository>();
    if (repository != r) {
      repository?.removeListener(changed);
      repository = r;
      r.addListener(changed);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  void changed() {
    generation++;
    if (mounted)
      setState(() {
        following = null;
        busy = false;
        error = null;
      });
  }

  @override
  void didUpdateWidget(FollowPlaceButton old) {
    super.didUpdateWidget(old);
    if (old.placeId != widget.placeId) {
      changed();
      load();
    }
  }

  Future<void> load() async {
    final g = ++generation;
    try {
      final p = await repository!.followed();
      if (mounted && g == generation)
        setState(() => following = p.any((p) => p.id == widget.placeId));
    } catch (_) {
      if (mounted && g == generation)
        setState(() => error = 'Accedi per seguire questo luogo.');
    }
  }

  Future<void> toggle() async {
    final g = ++generation;
    setState(() => busy = true);
    try {
      await repository!.follow(widget.placeId, !following!);
      if (mounted && g == generation) setState(() => following = !following!);
    } catch (_) {
      if (mounted && g == generation)
        setState(
          () => error = 'Preferenza non confermata. Aggiorna e riprova.',
        );
    } finally {
      if (mounted && g == generation) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    generation++;
    repository?.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (error != null) Text(error!),
      TextButton(
        onPressed: busy
            ? null
            : following == null
            ? load
            : toggle,
        child: Text(
          following == true
              ? 'Non seguire più il luogo'
              : following == false
              ? 'Segui aggiornamenti del luogo'
              : 'Verifica preferenza del luogo',
        ),
      ),
    ],
  );
}

class LeagueCooperationTabs extends StatefulWidget {
  const LeagueCooperationTabs({
    required this.leagueId,
    required this.seasonId,
    required this.personal,
    this.archived = false,
    super.key,
  });
  final String leagueId, seasonId;
  final Widget personal;
  final bool archived;
  @override
  State<LeagueCooperationTabs> createState() => _LeagueCooperationTabsState();
}

class _LeagueCooperationTabsState extends State<LeagueCooperationTabs> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          onTap: (i) => setState(() => selected = i),
          tabs: const [
            Tab(text: 'Punti fantasy'),
            Tab(text: 'Cooperazione'),
          ],
        ),
        if (selected == 0)
          widget.personal
        else
          LeagueCooperationPanel(
            key: ValueKey('${widget.leagueId}-${widget.seasonId}'),
            leagueId: widget.leagueId,
            seasonId: widget.seasonId,
            archived: widget.archived,
          ),
      ],
    ),
  );
}
