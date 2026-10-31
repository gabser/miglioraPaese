"""Read-only checks for this research sample; Python 3 standard library only.

Run from any working directory: python3 /absolute/path/to/verify_sample.py
No network, application dependencies, or generated outputs.
"""

import hashlib
import json
import math
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def read(name):
    return json.loads((ROOT / name).read_text())


def inside(point, ring):
    x, y = point
    crossings = 0
    for a, b in zip(ring, ring[1:]):
        if (a[1] > y) != (b[1] > y):
            cut = a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
            crossings += x < cut
    return crossings % 2 == 1


def position(value):
    assert isinstance(value, list) and len(value) == 2
    assert all(isinstance(v, (float, int)) and math.isfinite(v) for v in value)
    # Local ranges also catch reversed longitude/latitude, not just global ranges.
    assert 18.0 < value[0] < 18.2 and 40.0 < value[1] < 40.2, value


def edge(a, b):
    return tuple(sorted((tuple(a), tuple(b))))


def orientation(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def intersects(a, b, c, d):
    def on_segment(p, q, r):
        return min(p[0], r[0]) <= q[0] <= max(p[0], r[0]) and min(p[1], r[1]) <= q[1] <= max(p[1], r[1])

    first, second = orientation(a, b, c), orientation(a, b, d)
    third, fourth = orientation(c, d, a), orientation(c, d, b)
    if first * second < 0 and third * fourth < 0:
        return True
    return any((v == 0 and on_segment(p, q, r)) for v, p, q, r in [
        (first, a, c, b), (second, a, d, b), (third, c, a, d), (fourth, c, b, d)
    ])


def main():
    provenance = read('provenance.json')
    for item in provenance['artifacts']:
        data = (ROOT / item['path']).read_bytes()
        assert len(data) == item['bytes'], item['path']
        assert hashlib.sha256(data).hexdigest() == item['sha256'], item['path']

    snapshot = read('source-snapshot.json')
    sources = {(e['type'], e['id']): e for e in snapshot['elements']}
    assert len(sources) == len(snapshot['elements'])
    nodes = {ident: [e['lon'], e['lat']] for (kind, ident), e in sources.items() if kind == 'node'}
    boundary = read('boundary.geojson')
    assert boundary['type'] == 'FeatureCollection' and len(boundary['features']) == 1
    border_feature = boundary['features'][0]
    assert border_feature['geometry']['type'] == 'Polygon'
    assert len(border_feature['geometry']['coordinates']) == 1
    ring = border_feature['geometry']['coordinates'][0]
    assert len(ring) == 322 and ring[0] == ring[-1]
    assert len({tuple(p) for p in ring[:-1]}) == len(ring) - 1
    for p in ring:
        position(p)
    bbox = [min(p[0] for p in ring), min(p[1] for p in ring), max(p[0] for p in ring), max(p[1] for p in ring)]
    assert bbox == boundary['bbox']
    # Check every original boundary segment is present exactly once, regardless of direction.
    original_edges = Counter()
    relation = sources['relation', 40254]
    for member in relation['members']:
        if member['type'] == 'way':
            assert member['role'] == 'outer'
            refs = sources['way', member['ref']]['nodes']
            original_edges.update(edge(nodes[a], nodes[b]) for a, b in zip(refs, refs[1:]))
    assert original_edges == Counter(edge(a, b) for a, b in zip(ring, ring[1:]))
    assert sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(ring, ring[1:])) > 0
    # Check boundary self-intersections, excluding adjacent segments sharing a vertex.
    segments = list(zip(ring, ring[1:]))
    for i, (a, b) in enumerate(segments):
        for j in range(i + 2, len(segments)):
            if i == 0 and j == len(segments) - 1:
                continue
            c, d = segments[j]
            assert not intersects(a, b, c, d), (i, j)

    places = read('places.geojson')
    assert places['type'] == 'FeatureCollection' and len(places['features']) == 9
    ids = set()
    for feature in places['features'] + [border_feature]:
        assert feature['id'] not in ids
        ids.add(feature['id'])
        props = feature['properties']
        source = sources[props['source_type'], props['source_id']]
        assert props['name'] == source['tags']['name']
        assert props['source_version'] == source['version']
        assert props['source_updated_at'] == source['timestamp']
        assert props['retrieved_on'] == '2026-10-30'
        assert props['license'] == 'ODbL-1.0' and props['license_url'].startswith('https://opendatacommons.org/')
        assert props['attribution'] == '© OpenStreetMap contributors'
        assert props['municipalityId'] == 'tuglie'
        assert props['category'] and props['quality_note'] and props['verification_status']
        assert props['source_url'] == f"https://www.openstreetmap.org/{source['type']}/{source['id']}"
        assert props['source_version_url'].endswith(f"/{source['id']}/{source['version']}")
        if source['type'] == 'relation':
            continue
        assert feature['geometry']['type'] == 'Point'
        point = feature['geometry']['coordinates']
        position(point)
        assert inside(point, ring)
        assert props['content_links'] == [] and props['content_kind'] == 'real_place'
        if source['type'] == 'node':
            assert point == nodes[source['id']]
            assert props['coordinate_method'] == 'osm_node'
        else:
            polygon = [nodes[n] for n in source['nodes']]
            assert polygon[0] == polygon[-1] and inside(point, polygon)
            # Independently recompute area centroid using triangle decomposition.
            ox, oy = polygon[0]
            twice_area = mx = my = 0.0
            for a, b in zip(polygon[1:-1], polygon[2:]):
                ax, ay, bx, by = a[0] - ox, a[1] - oy, b[0] - ox, b[1] - oy
                weight = ax * by - bx * ay
                twice_area += weight
                mx += weight * (ax + bx) / 3
                my += weight * (ay + by) / 3
            expected = [ox + mx / twice_area, oy + my / twice_area]
            assert all(abs(a - b) <= 0.000000051 for a, b in zip(point, expected))
            assert props['coordinate_method'] == 'polygon_centroid_lon_lat'

    viewport = read('viewport.json')
    assert viewport['centre'] == nodes[68530020]
    assert any(m['type'] == 'node' and m['ref'] == 68530020 and m['role'] == 'admin_centre' for m in relation['members'])
    assert viewport['municipality_bounds'] == bbox
    west, south, east, north = viewport['initial_fit_bounds']
    for feature in places['features']:
        lon, lat = feature['geometry']['coordinates']
        assert west <= lon <= east and south <= lat <= north
    assert provenance['content_separation']['synthetic_missions_assigned'] is False
    print('PASS: hashes, 9 POIs, source IDs/versions, WGS84 lon/lat, node/centroid positions,')
    print('boundary source edges, closure/orientation/self-intersections, containment, viewport, no content links.')
    print('Not checked: field accuracy, authoritative boundary, live rendering or Flutter platform builds.')


if __name__ == '__main__':
    main()
