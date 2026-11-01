import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';

/// Framing only: these centers do not validate administrative membership.
abstract final class ProposalMapViews {
  static const views = <String, ({LatLng center, double zoom})>{
    'tuglie': (center: LatLng(40.0736, 18.0986), zoom: 15),
    'bologna': (center: LatLng(44.4949, 11.3426), zoom: 13),
    'castel-bolognese': (center: LatLng(44.3195, 11.7993), zoom: 15),
    'milano': (center: LatLng(45.4642, 9.1900), zoom: 12),
    'roma': (center: LatLng(41.9028, 12.4964), zoom: 12),
    'torino': (center: LatLng(45.0703, 7.6869), zoom: 12),
    'napoli': (center: LatLng(40.8518, 14.2681), zoom: 12),
    'palermo': (center: LatLng(38.1157, 13.3615), zoom: 12),
    'firenze': (center: LatLng(43.7696, 11.2558), zoom: 13),
    'genova': (center: LatLng(44.4056, 8.9463), zoom: 12),
  };
  static ({LatLng center, double zoom})? forMunicipality(String id) =>
      views[id.toLowerCase().replaceFirst('comune:', '').replaceAll(' ', '-')];
}

class ProposalPointMap extends StatefulWidget {
  const ProposalPointMap({
    required this.municipalityId,
    this.coordinates,
    this.onConfirmed,
    this.tileProvider,
    super.key,
  });
  final String municipalityId;
  final ProposalCoordinates? coordinates;

  /// Without a callback this is a read-only receipt/detail preview.
  final ValueChanged<ProposalCoordinates>? onConfirmed;
  final TileProvider? tileProvider;
  @override
  State<ProposalPointMap> createState() => _ProposalPointMapState();
}

class _ProposalPointMapState extends State<ProposalPointMap> {
  final _controller = MapController();
  final _tiles = <TileCoordinates, ({TileImage image, bool ready})>{};
  bool _tileUpdateScheduled = false;
  TileProvider? _network;
  LatLng? _candidate;
  bool _ready = false, _error = false;
  int _generation = 0;
  bool get _editable => widget.onConfirmed != null;
  @override
  void initState() {
    super.initState();
    _restorePoint();
  }

  void _restorePoint() {
    final p = widget.coordinates;
    _candidate = p == null ? null : LatLng(p.latitude, p.longitude);
  }

  @override
  void didUpdateWidget(covariant ProposalPointMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinates != widget.coordinates) _restorePoint();
  }

  bool _loadedAt(LatLng point) {
    if (!_ready || _error) return false;
    final z = _controller.camera.zoom.round();
    final n = math.pow(2, z);
    final x = ((point.longitude + 180) / 360 * n).floor();
    final lat = point.latitude.clamp(-85.0511, 85.0511) * math.pi / 180;
    final y =
        ((1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * n)
            .floor();
    final tile = _tiles[TileCoordinates(x, y, z)]?.image;
    return tile != null && _tileReady(tile);
  }

  bool _tileReady(TileImage tile) =>
      !tile.cancelLoading.isCompleted && tile.readyToDisplay && !tile.loadError;

  void _scheduleTileUpdate() {
    if (!mounted || _tileUpdateScheduled) return;
    _tileUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tileUpdateScheduled = false;
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _trackTile(TileImage tile, int generation) {
    if (generation != _generation) return;
    final key = tile.coordinates;
    final prior = _tiles[key];
    if (tile.cancelLoading.isCompleted) {
      if (identical(prior?.image, tile)) {
        _tiles.remove(key);
        _scheduleTileUpdate();
      }
      return;
    }
    final ready = _tileReady(tile);
    if (identical(prior?.image, tile) && prior?.ready == ready) return;
    _tiles[key] = (image: tile, ready: ready);
    if (!identical(prior?.image, tile)) {
      // A removed tile must not invalidate its replacement at the same coordinates.
      tile.cancelLoading.future.then((_) {
        if (!mounted ||
            generation != _generation ||
            !identical(_tiles[key]?.image, tile)) {
          return;
        }
        _tiles.remove(key);
        _scheduleTileUpdate();
      });
    }
    _scheduleTileUpdate();
  }

  void _confirm() {
    final point = _candidate;
    if (!_editable || point == null || !_loadedAt(point)) return;
    widget.onConfirmed!(
      ProposalCoordinates(latitude: point.latitude, longitude: point.longitude),
    );
  }

  void _select(LatLng point) {
    if (!_editable || !_loadedAt(point)) return;
    setState(() => _candidate = point);
  }

  void _move(double latitude, double longitude, [double zoom = 0]) {
    if (!_ready) return;
    final camera = _controller.camera;
    _controller.move(
      LatLng(
        (camera.center.latitude + latitude).clamp(-85, 85),
        (camera.center.longitude + longitude).clamp(-180, 180),
      ),
      (camera.zoom + zoom).clamp(3, 19),
    );
    setState(() {});
  }

  void _refresh() {
    setState(() {
      _error = false;
      _tiles.clear();
      _ready = false;
      _generation++;
      _network = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    final config = context.read<AppConfig?>() ?? AppConfig.fromValues();
    final view = ProposalMapViews.forMunicipality(widget.municipalityId);
    final center = _candidate ?? view?.center;
    if (center == null) {
      return const Text(
        'Per questo Comune indica il luogo nel campo di testo.',
      );
    }
    Widget control(String label, IconData icon, VoidCallback action) =>
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          visualDensity: VisualDensity.standard,
          tooltip: label,
          onPressed: _ready ? action : null,
          icon: Icon(icon),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _editable ? 280 : 180,
          child: FlutterMap(
            key: ValueKey('proposal-map-$_generation'),
            mapController: _controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: widget.coordinates == null ? view!.zoom : 16,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: InteractionOptions(
                flags: _editable
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.none,
              ),
              onMapReady: () {
                if (mounted) setState(() => _ready = true);
              },
              onPositionChanged: (_, __) {
                if (mounted) setState(() {});
              },
              onTap: (_, point) => _select(point),
            ),
            children: [
              TileLayer(
                urlTemplate: config.mapTileUrl,
                tileProvider:
                    widget.tileProvider ??
                    context.read<TileProvider?>() ??
                    (_network ??= NetworkTileProvider(
                      headers: kIsWeb
                          ? null
                          : {'User-Agent': 'MiglioraPaeseFantaComune/0.1'},
                    )),
                userAgentPackageName: 'it.migliorapaese.fanta_comune',
                panBuffer: 0,
                keepBuffer: 1,
                errorTileCallback: (_, __, ___) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && generation == _generation && !_error) {
                      setState(() => _error = true);
                    }
                  });
                },
                tileBuilder: (_, child, tile) {
                  // TileLayer rebuilds this tile when its image changes.
                  _trackTile(tile, generation);
                  return child;
                },
              ),
              if (_candidate != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _candidate!,
                      width: 48,
                      height: 48,
                      child: Semantics(
                        label: 'Punto selezionato',
                        child: const Icon(
                          Icons.location_pin,
                          color: AppTokens.navy,
                          size: 44,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Wrap(
          spacing: AppTokens.s8,
          children: [
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
              child: const Text('© OpenStreetMap contributors · ODbL'),
            ),
            if (config.mapProviderAttribution.isNotEmpty)
              TextButton(
                onPressed: config.mapProviderAttributionUrl.isEmpty
                    ? null
                    : () => launchUrl(
                        Uri.parse(config.mapProviderAttributionUrl),
                      ),
                child: Text(config.mapProviderAttribution),
              ),
          ],
        ),
        if (_error) ...[
          Semantics(
            liveRegion: true,
            child: const Text(
              'Mappa non disponibile. Puoi indicare il luogo nel campo di testo; la bozza è conservata.',
            ),
          ),
          TextButton(onPressed: _refresh, child: const Text('Ricarica mappa')),
        ] else if (_editable &&
            (!_ready || !_loadedAt(_controller.camera.center)))
          Semantics(
            liveRegion: true,
            child: const Text(
              'Caricamento mappa… Puoi anche indicare il luogo nel campo di testo.',
            ),
          ),
        if (_editable) ...[
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              control(
                'Sposta mappa a nord',
                Icons.arrow_upward,
                () => _move(0.002, 0),
              ),
              control(
                'Sposta mappa a sud',
                Icons.arrow_downward,
                () => _move(-0.002, 0),
              ),
              control(
                'Sposta mappa a ovest',
                Icons.arrow_back,
                () => _move(0, -0.002),
              ),
              control(
                'Sposta mappa a est',
                Icons.arrow_forward,
                () => _move(0, 0.002),
              ),
              control('Zoom avanti', Icons.add, () => _move(0, 0, 1)),
              control('Zoom indietro', Icons.remove, () => _move(0, 0, -1)),
            ],
          ),
          Wrap(
            spacing: AppTokens.s8,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _ready && _loadedAt(_controller.camera.center)
                    ? () => _select(_controller.camera.center)
                    : null,
                child: const Text('Seleziona il centro'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _candidate != null && _loadedAt(_candidate!)
                    ? _confirm
                    : null,
                child: const Text('Usa questo punto'),
              ),
            ],
          ),
          const Text(
            'Tocca la mappa per posizionare o spostare il pin, poi conferma. L’inquadratura non verifica i confini comunali.',
          ),
        ],
        if (widget.coordinates != null)
          Semantics(
            liveRegion: true,
            child: Text(
              'Punto confermato: ${widget.coordinates!.latitude.toStringAsFixed(5)}, ${widget.coordinates!.longitude.toStringAsFixed(5)}',
            ),
          ),
      ],
    );
  }
}
