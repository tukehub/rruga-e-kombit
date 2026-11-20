"""Open-water mask for sea and lake cities.

The Copernicus DEM reports open sea as a flat 0 m, and the terrain conformer
lowers the ground under roads to about the same height, so height alone
cannot separate a harbour road from the bay. Water here is the low ground
connected to the edge of the near grid (the open sea) or to mapped OSM water
(splat blue, for lakes), never crossing a mapped road (splat red) or the race
track's corridor.

Output, next to terrain_near.bin:
  water_near.bin   uint8 per near-grid cell, a signed shore distance:
                   water 128..255 = 128 + 127 * min(d / span, 1), d metres to land;
                   land 0..127 = 127 - 127 * min(d / beach, 1), d metres to water
  terrain.json     gains "water": {"surface": y, "span": metres, "beach": metres}

The water surface sits below every road and land cell, so the race road can
never be under water, and the game drops the seabed under it.

Runs on an already processed city without network access:
  python3 tools/pipeline/water.py vlore
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CITIES_DIR = os.path.join(HERE, '..', '..', 'godot', 'assets', 'cities')

SHORE_SPAN = 320.0       # metres of shore distance the water side encodes
BEACH_SPAN = 60.0        # metres of distance to the water the land side encodes
LOW_MARGIN = 0.25        # water cells: at least this far under sea_level
SURFACE_GAP = 0.35       # surface sits this far under the lowest land/road cell
SURFACE_DROP_MAX = 1.5   # ... but never more than this under sea_level
TRACK_CLEAR = 30.0       # metres beyond the track edge that are always land


def _dilate(m):
    """8-neighbour binary dilation."""
    out = m.copy()
    out[1:, :] |= m[:-1, :]
    out[:-1, :] |= m[1:, :]
    out[:, 1:] |= m[:, :-1]
    out[:, :-1] |= m[:, 1:]
    out[1:, 1:] |= m[:-1, :-1]
    out[1:, :-1] |= m[:-1, 1:]
    out[:-1, 1:] |= m[1:, :-1]
    out[:-1, :-1] |= m[1:, 1:]
    return out


def _flood(seed, allowed):
    """Cells of `allowed` connected to `seed`."""
    region = seed & allowed
    while True:
        grown = _dilate(region) & allowed
        if grown.sum() == region.sum():
            return grown
        region = grown


def _distance(region, cell):
    """Euclidean distance (m) from each cell of `region` to the nearest cell outside it."""
    from scipy.ndimage import distance_transform_edt
    return distance_transform_edt(region) * cell


def splat_mask(splat_png, channel, n, x0, z0, cell, span, threshold=40):
    """A splat channel resampled onto the near grid (False outside the splat)."""
    img = np.asarray(Image.open(splat_png))[..., channel]
    s = img.shape[0]
    xs = x0 + np.arange(n) * cell
    zs = z0 + np.arange(n) * cell
    u = ((xs + span / 2) / span * s).astype(int)
    v = ((zs + span / 2) / span * s).astype(int)
    inside_u = (u >= 0) & (u < s)
    inside_v = (v >= 0) & (v < s)
    out = np.zeros((n, n), bool)
    sub = img[np.ix_(np.clip(v, 0, s - 1), np.clip(u, 0, s - 1))] > threshold
    out[np.ix_(inside_v, inside_u)] = sub[np.ix_(inside_v, inside_u)]
    return out


def track_corridor(pts, hw, n, x0, z0, cell):
    """Near-grid cells within hw + TRACK_CLEAR of the track polyline."""
    reach = hw + TRACK_CLEAR
    xs = x0 + np.arange(n) * cell
    zs = z0 + np.arange(n) * cell
    out = np.zeros((n, n), bool)
    p = np.asarray([[q[0], q[2]] for q in pts], float)
    seg = np.concatenate([p, p[:1]])
    for a, b in zip(seg[:-1], seg[1:]):
        lo = np.minimum(a, b) - reach
        hi = np.maximum(a, b) + reach
        ix = np.nonzero((xs >= lo[0]) & (xs <= hi[0]))[0]
        iz = np.nonzero((zs >= lo[1]) & (zs <= hi[1]))[0]
        if len(ix) == 0 or len(iz) == 0:
            continue
        gx, gz = np.meshgrid(xs[ix], zs[iz])
        ab = b - a
        t = np.clip(((gx - a[0]) * ab[0] + (gz - a[1]) * ab[1]) / max(ab @ ab, 1e-9), 0, 1)
        dist = np.hypot(gx - (a[0] + t * ab[0]), gz - (a[1] + t * ab[1]))
        out[np.ix_(iz, ix)] |= dist <= reach
    return out


def build_water(near, nm, sea_level, roads, osm_water, corridor):
    """Returns (uint8 mask, surface height)."""
    n = int(nm['n'])
    cell = float(nm['cell'])
    low = near < sea_level - LOW_MARGIN
    blocked = roads | corridor
    allowed = low & ~blocked
    seed = np.zeros_like(low)
    seed[0, :] = seed[-1, :] = seed[:, 0] = seed[:, -1] = True
    seed |= osm_water
    water = _flood(seed, allowed)
    dry = ~water
    lowest_dry = float(near[dry].min()) if dry.any() else sea_level
    surface = min(sea_level, lowest_dry - SURFACE_GAP)
    surface = max(surface, sea_level - SURFACE_DROP_MAX)
    to_land = _distance(water, cell)
    to_water = _distance(dry, cell) if water.any() else np.full(water.shape, np.inf)
    mask = np.zeros((n, n), np.uint8)
    mask[water] = (128 + np.round(127 * np.minimum(to_land[water] / SHORE_SPAN, 1.0))).astype(np.uint8)
    mask[dry] = (127 - np.round(127 * np.minimum(to_water[dry] / BEACH_SPAN, 1.0))).astype(np.uint8)
    return mask, round(surface, 2)


def process_city(cid, cities_dir=CITIES_DIR):
    out = os.path.join(cities_dir, cid)
    meta_path = os.path.join(out, 'terrain.json')
    with open(meta_path) as f:
        meta = json.load(f)
    sea_level = float(meta.get('sea_level', -50.0))
    if sea_level <= -40.0:
        return None
    nm = meta['near']
    n = int(nm['n'])
    near = np.fromfile(os.path.join(out, 'terrain_near.bin'), '<f4').reshape(n, n)
    with open(os.path.join(out, 'track.json')) as f:
        track = json.load(f)
    splat = os.path.join(out, 'splat.png')
    span = float(meta['splat']['span'])
    roads = splat_mask(splat, 0, n, nm['x0'], nm['z0'], nm['cell'], span)
    osm_water = splat_mask(splat, 2, n, nm['x0'], nm['z0'], nm['cell'], span, threshold=128)
    corridor = track_corridor(track['pts'], float(track.get('hw', 10.0)), n, nm['x0'], nm['z0'], nm['cell'])
    mask, surface = build_water(near, nm, sea_level, roads, osm_water, corridor)
    mask.tofile(os.path.join(out, 'water_near.bin'))
    meta['water'] = {'surface': surface, 'span': SHORE_SPAN, 'beach': BEACH_SPAN}
    with open(meta_path, 'w', encoding='utf8') as f:
        json.dump(meta, f, indent=1)
    print(f'{cid}: water {100.0 * (mask >= 128).mean():.1f}% of the near grid, surface {surface} m')
    return mask, surface


if __name__ == '__main__':
    for cid in sys.argv[1:] or ['vlore']:
        process_city(cid)
