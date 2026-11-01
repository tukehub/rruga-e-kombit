"""Shared helpers for the data pipeline: paths, HTTP with cache, local metric projection."""
import json
import math
import os
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, 'tools', 'cache')
OUT = os.path.join(ROOT, 'godot', 'assets', 'cities')
UA = 'kafshim-asfalti-pipeline/1.0 (+https://github.com/tukehub/rruga-e-kombit)'

M_PER_DEG_LAT = 110574.0


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def ensure_dir(p):
    os.makedirs(p, exist_ok=True)
    return p


def http_get(url, data=None, timeout=300, retries=3, headers=None):
    hdr = {'User-Agent': UA}
    if headers:
        hdr.update(headers)
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=data, headers=hdr)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001
            last = e
            log(f'  retry {attempt + 1}/{retries} for {url}: {e}')
            time.sleep(3 * (attempt + 1))
    raise last


def download(url, path, timeout=600):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path
    ensure_dir(os.path.dirname(path))
    log(f'  downloading {url}')
    blob = http_get(url, timeout=timeout)
    with open(path + '.part', 'wb') as f:
        f.write(blob)
    os.replace(path + '.part', path)
    return path


class Proj:
    """Equirectangular local projection: x east, z south (Godot -Z is north), metres."""

    def __init__(self, lat0, lon0):
        self.lat0, self.lon0 = lat0, lon0
        self.kx = math.cos(math.radians(lat0)) * M_PER_DEG_LAT * 1.0033  # ~111320 at the equator
        self.kz = M_PER_DEG_LAT

    def to_xz(self, lat, lon):
        return (lon - self.lon0) * self.kx, -(lat - self.lat0) * self.kz

    def to_ll(self, x, z):
        return self.lat0 - z / self.kz, self.lon0 + x / self.kx


def load_json(p):
    with open(p, encoding='utf8') as f:
        return json.load(f)


def save_json(p, obj, compact=True):
    ensure_dir(os.path.dirname(p))
    with open(p, 'w', encoding='utf8') as f:
        if compact:
            json.dump(obj, f, separators=(',', ':'))
        else:
            json.dump(obj, f, indent=1)
