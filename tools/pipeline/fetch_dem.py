"""Download Copernicus GLO-30 DEM tiles (COG GeoTIFF) and sample a metric height window per city.

Output: tools/cache/dem/<city>_dem.npy (float32 metres, row 0 = north) plus meta json.
Licence: Copernicus DEM, ESA/Airbus, free use with attribution (see docs/LICENSES.md).
"""
import math
import os
import sys

import numpy as np
import tifffile

sys.path.insert(0, os.path.dirname(__file__))
from common import CACHE, Proj, download, ensure_dir, log, save_json  # noqa: E402
from cities import CITIES  # noqa: E402

DEM_DIR = ensure_dir(os.path.join(CACHE, 'dem'))
URL = ('https://copernicus-dem-30m.s3.amazonaws.com/'
       'Copernicus_DSM_COG_10_N{lat:02d}_00_E{lon:03d}_00_DEM/Copernicus_DSM_COG_10_N{lat:02d}_00_E{lon:03d}_00_DEM.tif')

_tiles = {}


def tile(lat, lon):
    key = (lat, lon)
    if key not in _tiles:
        path = os.path.join(DEM_DIR, f'N{lat:02d}_E{lon:03d}.tif')
        download(URL.format(lat=lat, lon=lon), path)
        with tifffile.TiffFile(path) as tf:
            arr = tf.pages[0].asarray().astype(np.float32)
        arr[arr < -100] = 0.0
        _tiles[key] = arr
    return _tiles[key]


def sample(lat, lon):
    """Bilinear sample of the global DEM at a lat/lon (arrays of any shape)."""
    lat = np.asarray(lat, dtype=np.float64)
    lon = np.asarray(lon, dtype=np.float64)
    out = np.zeros(lat.shape, dtype=np.float32)
    tl = np.floor(lat).astype(int)
    tn = np.floor(lon).astype(int)
    for (a, b) in set(zip(tl.ravel().tolist(), tn.ravel().tolist())):
        m = (tl == a) & (tn == b)
        arr = tile(a, b)
        n = arr.shape[0]
        # row 0 = lat a+1 (north edge), col 0 = lon b; cell size 1/n deg, pixel-is-area
        fy = ((a + 1) - lat[m]) * n - 0.5
        fx = (lon[m] - b) * n - 0.5
        fy = np.clip(fy, 0, n - 1.001)
        fx = np.clip(fx, 0, n - 1.001)
        y0 = np.floor(fy).astype(int)
        x0 = np.floor(fx).astype(int)
        ty = (fy - y0).astype(np.float32)
        tx = (fx - x0).astype(np.float32)
        y1 = np.minimum(y0 + 1, n - 1)
        x1 = np.minimum(x0 + 1, n - 1)
        v = (arr[y0, x0] * (1 - tx) * (1 - ty) + arr[y0, x1] * tx * (1 - ty)
             + arr[y1, x0] * (1 - tx) * ty + arr[y1, x1] * tx * ty)
        out[m] = v
    return out


def window(city_id, cell_m, half_km):
    c = CITIES[city_id]
    lat0, lon0 = c['origin']
    pr = Proj(lat0, lon0)
    n = int(round(half_km * 2000 / cell_m)) + 1
    xs = (np.arange(n) - (n - 1) / 2) * cell_m
    zs = (np.arange(n) - (n - 1) / 2) * cell_m
    X, Z = np.meshgrid(xs, zs)
    lat = lat0 - Z / pr.kz
    lon = lon0 + X / pr.kx
    h = sample(lat, lon)
    return h, xs[0], zs[0], cell_m


def main(ids):
    for cid in ids:
        c = CITIES[cid]
        log(f'[{cid}] DEM near window')
        near, x0, z0, cell = window(cid, 15.0, c['near_km'])
        far, fx0, fz0, fcell = window(cid, 90.0, c['far_km'])
        np.save(os.path.join(DEM_DIR, f'{cid}_near.npy'), near)
        np.save(os.path.join(DEM_DIR, f'{cid}_far.npy'), far)
        save_json(os.path.join(DEM_DIR, f'{cid}_dem.json'), {
            'near': {'x0': x0, 'z0': z0, 'cell': cell, 'n': int(near.shape[0]), 'min': float(near.min()), 'max': float(near.max())},
            'far': {'x0': fx0, 'z0': fz0, 'cell': fcell, 'n': int(far.shape[0]), 'min': float(far.min()), 'max': float(far.max())},
        }, compact=False)
        log(f'  near {near.shape} {near.min():.0f}..{near.max():.0f} m, far {far.shape} {far.min():.0f}..{far.max():.0f} m')


if __name__ == '__main__':
    main(sys.argv[1:] or list(CITIES))
