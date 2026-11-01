"""Report where the terrain heightmap rises above the road surface.
Usage: python tools/check_terrain.py tirane"""
import json
import sys

import numpy as np

cid = sys.argv[1] if len(sys.argv) > 1 else 'tirane'
d = f'godot/assets/cities/{cid}/'
meta = json.load(open(d + 'terrain.json'))
g = meta['near']
n, cell, x0, z0 = g['n'], g['cell'], g['x0'], g['z0']
h = np.fromfile(d + 'terrain_near.bin', dtype='<f4').reshape(n, n)
tr = json.load(open(d + 'track.json'))
pts = np.array(tr['pts'], dtype=float)  # x, y, z
hw = tr['hw']


def sample(x, z):
    fx = np.clip((x - x0) / cell, 0, n - 1.001)
    fz = np.clip((z - z0) / cell, 0, n - 1.001)
    ix, iz = np.floor(fx).astype(int), np.floor(fz).astype(int)
    tx, tz = fx - ix, fz - iz
    return (h[iz, ix] * (1 - tx) * (1 - tz) + h[iz, ix + 1] * tx * (1 - tz)
            + h[iz + 1, ix] * (1 - tx) * tz + h[iz + 1, ix + 1] * tx * tz)


# densify the control polyline
xz = pts[:, [0, 2]]
y = pts[:, 1]
seg = np.linalg.norm(np.roll(xz, -1, axis=0) - xz, axis=1)
s = np.concatenate([[0], np.cumsum(seg)])
L = s[-1]
ss = np.arange(0, L, 2.0)
xs = np.interp(ss, s, np.concatenate([xz[:, 0], xz[:1, 0]]))
zs = np.interp(ss, s, np.concatenate([xz[:, 1], xz[:1, 1]]))
ys = np.interp(ss, s, np.concatenate([y, y[:1]]))
tan = np.gradient(np.stack([xs, zs], 1), axis=0)
tan /= np.linalg.norm(tan, axis=1)[:, None]
nrm = np.stack([-tan[:, 1], tan[:, 0]], 1)

worst = []
for lat in (0.0, hw * 0.5, hw, -hw * 0.5, -hw, hw + 3, -hw - 3):
    th = sample(xs + nrm[:, 0] * lat, zs + nrm[:, 1] * lat)
    ex = th - ys
    worst.append((lat, ex))
    bad = ex > 0.05
    print(f'lat {lat:+6.1f}: terrain above road at {bad.mean()*100:5.1f}% of track, max +{ex.max():.2f} m, '
          f'mean excess where bad {ex[bad].mean() if bad.any() else 0:.2f} m')

# where along the track (by s) is it bad at the centreline / edges?
ex_all = np.max([e for _, e in worst[:5]], axis=0)
bad = ex_all > 0.3
if bad.any():
    runs = []
    start = None
    for i, b in enumerate(bad):
        if b and start is None:
            start = i
        if not b and start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(bad)))
    print(f'\n{len(runs)} bad stretches (>0.3 m above road within the carriageway):')
    for a, b in runs[:40]:
        print(f'  s {ss[a]:7.0f}..{ss[b-1]:7.0f} m  len {ss[b-1]-ss[a]:5.0f} m  max +{ex_all[a:b].max():.2f} m  road y {ys[a]:.1f}')
print(f'\ntrack length {L:.0f} m, road y {y.min():.1f}..{y.max():.1f}, DEM near grid {h.min():.1f}..{h.max():.1f}')

# far horizon mesh: Godot builds it decimated 2x (effective cell = 2*cell) and lowers it by 2.5 m
fg = meta['far']
fn, fcell, fx0, fz0 = fg['n'], fg['cell'], fg['x0'], fg['z0']
fh = np.fromfile(d + 'terrain_far.bin', dtype='<f4').reshape(fn, fn)
step = 2
fh2 = fh[::step, ::step]
n2 = fh2.shape[0]
c2 = fcell * step


def sample_far(x, z):
    fx = np.clip((x - fx0) / c2, 0, n2 - 1.001)
    fz = np.clip((z - fz0) / c2, 0, n2 - 1.001)
    ix, iz = np.floor(fx).astype(int), np.floor(fz).astype(int)
    tx, tz = fx - ix, fz - iz
    return (fh2[iz, ix] * (1 - tx) * (1 - tz) + fh2[iz, ix + 1] * tx * (1 - tz)
            + fh2[iz + 1, ix] * (1 - tx) * tz + fh2[iz + 1, ix + 1] * tx * tz)


far_y = sample_far(xs, zs) - 2.5
ex = far_y - ys
bad = ex > 0.0
print(f'FAR mesh (y-2.5) above road at centreline: {bad.mean()*100:.1f}% of track, max +{ex.max():.2f} m, '
      f'mean excess where bad {ex[bad].mean() if bad.any() else 0:.2f} m')
# how far below the road must the far mesh sit to never show through within 300 m of the track?
near_h = sample(xs, zs)
print(f'far-minus-near along centreline: min {(sample_far(xs, zs) - near_h).min():.2f}, max {(sample_far(xs, zs) - near_h).max():.2f} m')

# Godot (terrain.gd._build_far) drops far quads fully inside the near footprint,
# so the far mesh can only show through where the track leaves the near grid.
span = cell * (n - 1)
inside = ((xs >= x0) & (xs < x0 + span) & (zs >= z0) & (zs < z0 + span))
print(f'track inside near footprint: {inside.mean()*100:.1f}% -> far mesh present under the track: {(~inside).mean()*100:.1f}%')
if (~inside).any():
    print(f'  far mesh above road where present: {(ex[~inside] > 0).mean()*100:.1f}%')
else:
    print('  OK: far mesh removed under the whole track')

