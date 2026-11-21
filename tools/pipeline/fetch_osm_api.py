"""Fallback OSM extract from the main OpenStreetMap API when every Overpass
endpoint is down. Downloads the city's bbox in small /api/0.6/map tiles (the API
caps one call at 50 000 nodes), keeps what fetch_osm.query() asks for, and
writes the same Overpass-style JSON (tagged ways and relations with their node
ids, then the nodes) so build_city.py cannot tell the difference.

Raw tiles are cached per bounding box under tools/cache/osm/. Data (c) OpenStreetMap
contributors, ODbL.
"""
import json
import os
import re
import time
import xml.etree.ElementTree as ET

from common import ensure_dir, http_get, log

API = 'https://api.openstreetmap.org/api/0.6/map?bbox={w:.5f},{s:.5f},{e:.5f},{n:.5f}'
TILES = 5            # per side
PAUSE = 1.0          # seconds between calls (API usage policy)

NATURAL = re.compile(r'^(water|wood|scrub|beach|coastline|bare_rock|grassland)$')
LEISURE = re.compile(r'^(park|pitch|garden)$')
WATERWAY = re.compile(r'^(river|stream|canal)$')


def wanted_way(t):
    return ('highway' in t or 'building' in t or 'landuse' in t
            or NATURAL.match(t.get('natural', '')) or LEISURE.match(t.get('leisure', ''))
            or WATERWAY.match(t.get('waterway', '')) or t.get('railway') == 'rail')


def wanted_relation(t):
    return 'building' in t or t.get('natural') == 'water'


def wanted_node(t):
    return t.get('natural') == 'tree' or t.get('highway') == 'street_lamp'


def _tags(el):
    return {tag.get('k'): tag.get('v') for tag in el.findall('tag')}


def fetch_tiles(cache_dir, s, w, n, e):
    ensure_dir(cache_dir)
    paths = []
    for j in range(TILES):
        for i in range(TILES):
            ts = s + (n - s) * j / TILES
            tn = s + (n - s) * (j + 1) / TILES
            tw = w + (e - w) * i / TILES
            te = w + (e - w) * (i + 1) / TILES
            path = os.path.join(cache_dir, f'{j}_{i}.osm')
            if not (os.path.exists(path) and os.path.getsize(path) > 200):
                log(f'  osm api tile {j * TILES + i + 1}/{TILES * TILES}')
                blob = http_get(API.format(s=ts, w=tw, n=tn, e=te), timeout=120, retries=4)
                if b'<osm' not in blob[:400]:
                    raise RuntimeError(blob[:200])
                with open(path + '.part', 'wb') as f:
                    f.write(blob)
                os.replace(path + '.part', path)
                time.sleep(PAUSE)
            paths.append(path)
    return paths


def merge(paths):
    nodes, ways, rels = {}, {}, {}
    for p in paths:
        root = ET.parse(p).getroot()
        for el in root.findall('node'):
            nodes[int(el.get('id'))] = {'lat': float(el.get('lat')), 'lon': float(el.get('lon')), 'tags': _tags(el)}
        for el in root.findall('way'):
            ways[int(el.get('id'))] = {'nodes': [int(nd.get('ref')) for nd in el.findall('nd')], 'tags': _tags(el)}
        for el in root.findall('relation'):
            rels[int(el.get('id'))] = {'members': [{'type': m.get('type'), 'ref': int(m.get('ref')), 'role': m.get('role')}
                                                   for m in el.findall('member')], 'tags': _tags(el)}
    return nodes, ways, rels


def to_overpass(nodes, ways, rels):
    out, need_ways, need_nodes = [], set(), set()
    for rid, r in rels.items():
        if wanted_relation(r['tags']):
            out.append({'type': 'relation', 'id': rid, 'members': r['members'], 'tags': r['tags']})
            need_ways.update(m['ref'] for m in r['members'] if m['type'] == 'way')
    for wid, w in ways.items():
        if wanted_way(w['tags']) or wid in need_ways:
            # A way cut by the tile edge may have lost nodes; keep only complete ones.
            if all(nid in nodes for nid in w['nodes']):
                item = {'type': 'way', 'id': wid, 'nodes': w['nodes']}
                if w['tags']:
                    item['tags'] = w['tags']
                out.append(item)
                need_nodes.update(w['nodes'])
    for nid, nd in nodes.items():
        if wanted_node(nd['tags']):
            out.append({'type': 'node', 'id': nid, 'lat': nd['lat'], 'lon': nd['lon'], 'tags': nd['tags']})
            need_nodes.discard(nid)
    for nid in sorted(need_nodes):
        out.append({'type': 'node', 'id': nid, 'lat': nodes[nid]['lat'], 'lon': nodes[nid]['lon']})
    return {'version': 0.6, 'generator': 'vortex fetch_osm_api', 'osm3s': {'copyright': 'OpenStreetMap contributors, ODbL'},
            'elements': out}


def fetch(cache_root, cid, bb, path):
    s, w, n, e = (float(v) for v in bb.split(','))
    # Tile indices alone identify different places when a city's bounds change.
    paths = fetch_tiles(os.path.join(cache_root, f'api_{cid}_{bb}'), s, w, n, e)
    data = to_overpass(*merge(paths))
    with open(path, 'w', encoding='utf8') as f:
        json.dump(data, f, separators=(',', ':'))
    log(f'  osm api: {len(data["elements"])} elements')
    return path
