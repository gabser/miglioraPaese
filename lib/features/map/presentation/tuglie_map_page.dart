import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/features/map/data/map_places_repository.dart';
import 'package:fanta_comune/features/map/domain/map_place.dart';
import 'package:fanta_comune/features/map/logic/map_places_controller.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';

class TuglieMapPage extends StatefulWidget {
  const TuglieMapPage({
    required this.municipalityId,
    this.repository,
    this.tileProvider,
    super.key,
  });
  final String? municipalityId;
  final MapPlacesRepository? repository;
  final TileProvider? tileProvider;

  @override
  State<TuglieMapPage> createState() => _TuglieMapPageState();
}

class _TuglieMapPageState extends State<TuglieMapPage> {
  static final _initialBounds = LatLngBounds(
    const LatLng(40.065, 18.085),
    const LatLng(40.09, 18.11),
  );
  static final _municipalityBounds = LatLngBounds(
    const LatLng(40.0616618, 18.0707304),
    const LatLng(40.09806, 18.1154809),
  );
  final _mapController = MapController();
  final _searchController = TextEditingController();
  TileProvider? _networkTileProvider;
  late MapPlacesController _places;
  bool _showBoundary = false;
  bool _tileError = false;
  bool _tileLoaded = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _places = MapPlacesController(
      widget.repository ?? const AssetMapPlacesRepository(),
    )..addListener(_onPlacesChanged);
    _places.load(widget.municipalityId);
  }

  @override
  void didUpdateWidget(covariant TuglieMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _places.removeListener(_onPlacesChanged);
      _places.dispose();
      _places = MapPlacesController(
        widget.repository ?? const AssetMapPlacesRepository(),
      )..addListener(_onPlacesChanged);
    }
    if (oldWidget.municipalityId != widget.municipalityId ||
        oldWidget.repository != widget.repository) {
      _searchController.clear();
      _places.load(widget.municipalityId);
      _tileError = false;
      _tileLoaded = false;
    }
  }

  void _onPlacesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _places.removeListener(_onPlacesChanged);
    _places.dispose();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _fit(LatLngBounds bounds) {
    if (!_mapReady) {
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(32),
        minZoom: 12,
        maxZoom: 19,
      ),
    );
  }

  void _zoom(double delta) {
    if (!_mapReady) {
      return;
    }
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(12.0, 19.0));
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final selectedMunicipality = MunicipalityCatalog.apiIdFor(
      context.watch<AppPrefs>().municipalityId ?? '',
    );
    final id = widget.municipalityId;
    final allowed = id != null && id == selectedMunicipality;
    if (!allowed || _places.status != MapDataStatus.ready) {
      _networkTileProvider = null;
    }
    final effectiveMunicipality = allowed ? id : null;
    if (_places.municipalityId != effectiveMunicipality) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _places.municipalityId != effectiveMunicipality) {
          _searchController.clear();
          _places.load(effectiveMunicipality);
        }
      });
    }
    final title = id == null
        ? 'Mappa'
        : 'Mappa · ${MunicipalityCatalog.displayNameFromId(id)}';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Indietro',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(config.fantasyModeEnabled ? '/squad' : '/home'),
        ),
        title: Text(title),
      ),
      body: SafeArea(
        child: !allowed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    id == null
                        ? 'Seleziona un Comune per aprire la mappa.'
                        : 'La mappa richiesta non corrisponde al Comune selezionato.',
                  ),
                ),
              )
            : _buildContent(context, config),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppConfig config) {
    if (_places.status == MapDataStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('map-data-loading')),
      );
    }
    if (_places.status == MapDataStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('I luoghi non sono disponibili.'),
            TextButton(
              onPressed: () => _places.load(widget.municipalityId),
              child: const Text('Riprova'),
            ),
          ],
        ),
      );
    }
    if (_places.status == MapDataStatus.empty) {
      return const Center(
        child: Text('Nessun luogo disponibile per questo Comune.'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal =
            constraints.maxWidth >= AppTokens.desktopBreakpoint ||
            (constraints.maxWidth >= 700 && constraints.maxHeight < 500);
        final map = _buildMap(config);
        final list = _buildList(config);
        if (horizontal) {
          return Row(
            children: [
              Expanded(flex: 3, child: map),
              SizedBox(width: 350, child: list),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(
              height: constraints.maxHeight < 500
                  ? constraints.maxHeight * 0.55
                  : 320,
              child: map,
            ),
            Expanded(child: list),
          ],
        );
      },
    );
  }

  Widget _buildMap(AppConfig config) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(40.073821, 18.098125),
            initialZoom: 15,
            initialCameraFit: CameraFit.bounds(
              bounds: _initialBounds,
              padding: const EdgeInsets.all(32),
              minZoom: 12,
              maxZoom: 19,
            ),
            minZoom: 12,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              _mapReady = true;
            },
          ),
          children: [
            TileLayer(
              urlTemplate: config.mapTileUrl,
              tileProvider:
                  widget.tileProvider ??
                  (_networkTileProvider ??= NetworkTileProvider(
                    headers: kIsWeb
                        ? null
                        : {'User-Agent': 'MiglioraPaeseFantaComune/0.1'},
                  )),
              userAgentPackageName: 'it.migliorapaese.fanta_comune',
              panBuffer: 0,
              keepBuffer: 1,
              errorTileCallback: (_, __, ___) {
                if (mounted && !_tileError) {
                  setState(() => _tileError = true);
                }
              },
              tileBuilder: (context, child, tile) => AnimatedBuilder(
                animation: tile,
                builder: (_, __) {
                  if (tile.loadFinishedAt != null &&
                      !tile.loadError &&
                      !_tileLoaded) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_tileLoaded) {
                        setState(() => _tileLoaded = true);
                      }
                    });
                  }
                  return child;
                },
              ),
            ),
            if (_showBoundary)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _places.snapshot!.boundary,
                    color: AppTokens.blueSoft.withValues(alpha: 0.25),
                    borderColor: AppTokens.navy,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final place in _places.visiblePlaces)
                  Marker(
                    key: ValueKey('marker-${place.placeId}'),
                    point: place.position,
                    width: 46,
                    height: 46,
                    child: Semantics(
                      button: true,
                      label: 'Apri ${place.name}',
                      child: IconButton.filled(
                        tooltip: place.name,
                        icon: Icon(
                          _places.selectedPlaceId == place.placeId
                              ? Icons.place
                              : Icons.location_on_outlined,
                        ),
                        onPressed: () => _places.select(place.placeId),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Zoom avanti',
                  icon: const Icon(Icons.add),
                  onPressed: () => _zoom(1),
                ),
                IconButton(
                  tooltip: 'Zoom indietro',
                  icon: const Icon(Icons.remove),
                  onPressed: () => _zoom(-1),
                ),
                IconButton(
                  tooltip: 'Ripristina vista',
                  icon: const Icon(Icons.center_focus_strong),
                  onPressed: () => _fit(_initialBounds),
                ),
                IconButton(
                  tooltip: 'Intero Comune',
                  icon: const Icon(Icons.crop_free),
                  onPressed: () => _fit(_municipalityBounds),
                ),
                IconButton(
                  tooltip: _showBoundary
                      ? 'Nascondi confine'
                      : 'Mostra confine',
                  icon: const Icon(Icons.layers_outlined),
                  onPressed: () =>
                      setState(() => _showBoundary = !_showBoundary),
                ),
              ],
            ),
          ),
        ),
        if (_tileError)
          Positioned(
            top: 8,
            left: 8,
            right: 64,
            child: _mapNotice(
              'Tessere non disponibili. Usa l’elenco dei luoghi.',
            ),
          )
        else if (!_tileLoaded)
          Positioned(
            top: 8,
            left: 8,
            right: 64,
            child: _mapNotice('Caricamento tessere…'),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final links = <Widget>[
                      _attributionLink(
                        '© OpenStreetMap contributors · ODbL',
                        () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                      ),
                      _attributionLink(
                        'Segnala un problema cartografico',
                        () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/fixthemap'),
                        ),
                      ),
                      if (config.mapProviderAttribution.isNotEmpty)
                        _attributionLink(
                          config.mapProviderAttribution,
                          config.mapProviderAttributionUrl.isEmpty
                              ? null
                              : () => launchUrl(
                                  Uri.parse(config.mapProviderAttributionUrl),
                                ),
                          underlined:
                              config.mapProviderAttributionUrl.isNotEmpty,
                        ),
                    ];
                    if (constraints.maxWidth < 560) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final link in links)
                            SizedBox(width: constraints.maxWidth, child: link),
                        ],
                      );
                    }
                    return Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      children: links,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _attributionLink(
    String label,
    VoidCallback? onTap, {
    bool underlined = true,
  }) => InkWell(
    onTap: onTap,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        decoration: underlined ? TextDecoration.underline : null,
      ),
    ),
  );

  Widget _mapNotice(String message) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(padding: const EdgeInsets.all(8), child: Text(message)),
  );

  Widget _buildList(AppConfig config) {
    final categories =
        _places.snapshot!.places.map((e) => e.category).toSet().toList()
          ..sort();
    final selected = _places.selectedPlace;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Luoghi reali · ${_places.snapshot!.places.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text('Campione OpenStreetMap da verificare sul posto.'),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('map-place-search'),
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Cerca un luogo',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: _places.search,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const ValueKey('map-category-filter'),
          isExpanded: true,
          initialValue: _places.category,
          decoration: const InputDecoration(labelText: 'Filtra per categoria'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text(
                'Tutte le categorie',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final category in categories)
              DropdownMenuItem(
                value: category,
                child: Text(
                  _categoryLabel(category),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => _places.filter(value == '' ? null : value),
        ),
        const SizedBox(height: 8),
        if (selected != null)
          Card(
            key: const ValueKey('map-place-detail'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selected.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Chiudi dettaglio',
                        icon: const Icon(Icons.close),
                        onPressed: () => _places.select(null),
                      ),
                    ],
                  ),
                  Text('Categoria: ${_categoryLabel(selected.category)}'),
                  Text('Fonte: OpenStreetMap · ${selected.osmId}'),
                  Text(
                    'Posizione: ${selected.coordinateMethod == 'node_lon_lat' ? 'nodo OSM' : 'centroide della superficie OSM'}',
                  ),
                  Text(selected.qualityNote),
                  TextButton(
                    onPressed: () => launchUrl(selected.sourceUrl),
                    child: const Text('Apri fonte OSM'),
                  ),
                  if (selected.contentLinks.isEmpty)
                    const Text('Nessun contenuto collegato')
                  else
                    for (final link in selected.contentLinks)
                      TextButton(
                        onPressed: () =>
                            _openContent(link, selected.municipalityId, config),
                        child: Text('${link.kind.name}: ${link.id}'),
                      ),
                ],
              ),
            ),
          ),
        if (_places.visiblePlaces.isEmpty)
          const Text('Nessun luogo corrisponde al filtro.'),
        for (final place in _places.visiblePlaces)
          ListTile(
            key: ValueKey('place-${place.placeId}'),
            title: Text(place.name),
            subtitle: Text(_categoryLabel(place.category)),
            selected: selected?.placeId == place.placeId,
            leading: const Icon(Icons.place_outlined),
            onTap: () => _places.select(place.placeId),
          ),
      ],
    );
  }

  void _openContent(
    PlaceContentLink link,
    String municipalityId,
    AppConfig config,
  ) {
    if (MunicipalityCatalog.apiIdFor(
          context.read<AppPrefs>().municipalityId ?? '',
        ) !=
        municipalityId) {
      return;
    }
    switch (link.kind) {
      case PlaceContentKind.proposal:
        context.go(
          ProposalRouteContext.detailLocation(link.id, municipalityId),
        );
      case PlaceContentKind.mission:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missioni non disponibili in questa versione.'),
          ),
        );
      case PlaceContentKind.problem:
        context.go('/board');
    }
  }

  String _categoryLabel(String category) => switch (category) {
    'townhall' => 'Municipio',
    'park' => 'Parco',
    'place_of_worship' => 'Luogo di culto',
    'theatre' => 'Teatro',
    'railway_station' => 'Stazione ferroviaria',
    'archaeological_site' => 'Sito archeologico',
    'social_facility' => 'Centro sociale',
    'drinking_water' => 'Acqua potabile',
    _ => category,
  };
}
