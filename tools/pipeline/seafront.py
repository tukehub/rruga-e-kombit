"""Seafront dressing for a stretch of the race road along the water (Vlorë's
Lungomare): which track samples it covers, which side the sea is on, taller
apartment blocks along the land side, and anchors for café terraces (land
side) and palms (sea side promenade).

City config (cities.py):
  'seafront': {'from': (lat, lon), 'to': (lat, lon),
               'levels': (10, 15), 'frontage': 140}
The stretch runs along the loop from the sample nearest `from` to the sample
nearest `to`, in loop order.
"""
import json
import math
import os

import numpy as np

STOREY = 3.1          # metres, as parse_height
PALM_SPACING = 17.0   # metres along the promenade
PALM_OFFSET = 7.5     # metres beyond the road edge
CAFE_SPACING = 30.0


def stretch(ref, proj, cfg):
    """Sample indices of the stretch, in loop order (may wrap)."""
    a = int(np.argmin(np.linalg.norm(ref.xz - np.asarray(proj.to_xz(*cfg['from'])), axis=1)))
    b = int(np.argmin(np.linalg.norm(ref.xz - np.asarray(proj.to_xz(*cfg['to'])), axis=1)))
    n = len(ref.xz)
    return [(a + k) % n for k in range(((b - a) % n) + 1)]


def load_water(out_dir):
    with open(os.path.join(out_dir, 'terrain.json')) as f:
        meta = json.load(f)
    nm = meta['near']
    n = int(nm['n'])
    mask = np.fromfile(os.path.join(out_dir, 'water_near.bin'), np.uint8).reshape(n, n)
    return mask, nm


def is_water(mask, nm, x, z):
    n = int(nm['n'])
    ix = int(round((x - nm['x0']) / nm['cell']))
    iz = int(round((z - nm['z0']) / nm['cell']))
    return 0 <= ix < n and 0 <= iz < n and mask[iz, ix] >= 128


def sea_side(ref, hw, idx, mask, nm, probe=120.0):
    """+1 when the sea lies along +normal, -1 along -normal."""
    votes = 0
    for i in idx[::5]:
        for side in (1.0, -1.0):
            for r in np.arange(hw + 10.0, hw + probe, 10.0):
                p = ref.xz[i] + side * r * ref.nrm[i]
                if is_water(mask, nm, *p):
                    votes += int(side)
                    break
    if votes == 0:
        raise RuntimeError('seafront stretch sees no water on either side')
    return 1.0 if votes > 0 else -1.0


def frontage_height(cfg, idx, side, rnd):
    """A height override for build_buildings: land-side blocks along the
    stretch without mapped heights become 10-15 storey apartment blocks."""
    span = set(idx)
    lo, hi = cfg.get('levels', (10, 15))
    within = float(cfg.get('frontage', 140.0))

    def override(ref, bid, tags, cx, cz):
        if tags.get('height') or tags.get('building:levels'):
            return None
        if tags.get('building') in ('house', 'detached', 'shed', 'garage', 'garages', 'hut', 'roof', 'kiosk'):
            return None
        d, lat, i = ref.signed_lateral(cx, cz)
        if i not in span or d > within or lat * side > 0:
            return None
        levels = lo + int(rnd(bid, 7) * (hi - lo + 1))
        return min(hi, levels) * STOREY + 1.0
    return override


def palms(ref, hw, idx, side, mask, nm, terrain_sample, surface, rnd_fn, offset=PALM_OFFSET, avoid=(), seed=0):
    """A row of palms `offset` metres beyond the road edge on `side`: on dry
    ground, clear of the road and of the points in `avoid` (café terraces)."""
    out = []
    step = max(1, int(round(PALM_SPACING / float(np.median(np.linalg.norm(np.diff(ref.xz, axis=0), axis=1))))))
    avoid = np.asarray(avoid, float).reshape(-1, 2)
    for k, i in enumerate(idx[::step]):
        k += seed
        p = ref.xz[i] + side * (hw + offset) * ref.nrm[i]
        if len(avoid) and np.min(np.hypot(*(avoid - p).T)) < 4.5:
            continue
        if is_water(mask, nm, *p) or ref.nearest(*p)[0] < hw + min(4.0, offset - 0.5):
            continue
        y = float(terrain_sample([p[0]], [p[1]])[0])
        if y < surface + 0.4:
            continue
        out.append([round(float(p[0]), 1), round(y, 2), round(float(p[1]), 1),
                    round(0.85 + 0.35 * rnd_fn(k, 11), 2), round(rnd_fn(k, 12) * math.tau, 2)])
    return out


def promenade(ref, hw, idx, side, mask, nm, terrain_sample, blocked=None, every=4.0, beach=22.0, reach=55.0):
    """The seafront outline for the game: centreline samples with their
    normals; on the sea side, how far from the centreline the promenade and
    lawns may run before the beach (keeping `beach` metres of sand); on the
    land side, how far the pavement may run. Both stop at buildings
    (`blocked(x, z)`)."""
    spacing = float(np.median(np.linalg.norm(np.diff(ref.xz, axis=0), axis=1)))
    step = max(1, int(round(every / spacing)))
    blocked = blocked or (lambda x, z: False)
    line = []
    for i in idx[::step]:
        c, n = ref.xz[i], ref.nrm[i] * side
        edge = hw + 1.0
        for r in np.arange(hw + 2.0, hw + reach, 2.0):
            p = c + n * r
            if is_water(mask, nm, *(c + n * (r + beach))) or blocked(*p):
                break
            edge = r
        land = hw + 1.0
        for r in np.arange(hw + 2.0, hw + 9.5, 1.5):
            if blocked(*(c - n * r)):
                break
            land = r
        line.append([round(float(c[0]), 2), round(float(ref.y[i]), 2), round(float(c[1]), 2),
                     round(float(n[0]), 4), round(float(n[1]), 4), round(float(edge), 1), round(float(land), 1)])
    return line
