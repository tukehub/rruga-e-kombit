"""Fetch OpenStreetMap extracts (roads, buildings, landuse, water) per city via Overpass.

Output: tools/cache/osm/<city>.json (raw Overpass JSON, ODbL). Data (c) OpenStreetMap contributors.
"""
import os
import sys
import urllib.parse

sys.path.insert(0, os.path.dirname(__file__))
from common import CACHE, Proj, ensure_dir, http_get, log  # noqa: E402
from cities import CITIES  # noqa: E402

OSM_DIR = ensure_dir(os.path.join(CACHE, 'osm'))
ENDPOINTS = ['https://overpass-api.de/api/interpreter', 'https://overpass.private.coffee/api/interpreter']


def bbox(cid, half_m):
    lat0, lon0 = CITIES[cid]['origin']
    pr = Proj(lat0, lon0)
    s, w = pr.to_ll(-half_m, half_m)
    n, e = pr.to_ll(half_m, -half_m)
    return f'{s:.5f},{w:.5f},{n:.5f},{e:.5f}'


def query(cid):
    bb = bbox(cid, 2600)
    return f"""[out:json][timeout:180];
(
  way["highway"]({bb});
  way["building"]({bb});
  relation["building"]({bb});
  way["landuse"]({bb});
  way["natural"~"^(water|wood|scrub|beach|coastline|bare_rock|grassland)$"]({bb});
  relation["natural"="water"]({bb});
  way["leisure"~"^(park|pitch|garden)$"]({bb});
  way["waterway"~"^(river|stream|canal)$"]({bb});
  way["railway"="rail"]({bb});
  node["natural"="tree"]({bb});
  node["highway"="street_lamp"]({bb});
);
out body;
>;
out skel qt;
"""


def fetch(cid, force=False):
    path = os.path.join(OSM_DIR, f'{cid}.json')
    if os.path.exists(path) and os.path.getsize(path) > 1000 and not force:
        log(f'[{cid}] cached {os.path.getsize(path) // 1024} kB')
        return path
    data = urllib.parse.urlencode({'data': query(cid)}).encode()
    last = None
    for ep in ENDPOINTS:
        try:
            log(f'[{cid}] overpass {ep}')
            blob = http_get(ep, data=data, timeout=240, retries=2)
            if not blob.lstrip().startswith(b'{'):
                raise RuntimeError(blob[:200])
            with open(path, 'wb') as f:
                f.write(blob)
            log(f'  {len(blob) // 1024} kB')
            return path
        except Exception as e:  # noqa: BLE001
            last = e
            log(f'  failed: {e}')
    raise last


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    for c in args or list(CITIES):
        fetch(c, force='--force' in sys.argv)
