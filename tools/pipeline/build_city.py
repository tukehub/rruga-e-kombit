"""Build one city for the game from cached OSM + DEM data.

Outputs to godot/assets/cities/<city>/:
  track.json       closed centreline (x,y,z) every ~6 m, half width, start index
  terrain.json     heightmap metadata (near/far grids, origins, cell size)
  terrain_near.bin float32 heights (row major, row 0 = north), conformed to the track
  terrain_far.bin  float32 heights for the distant ring
  splat.png        RGBA ground mask: R road, G vegetation, B water, A urban
  buildings.glb    extruded OSM buildings, chunked 250 m, vertex colours for tint
  props.json       street lamps, trees (positions), landmarks (x,y,z,yaw,id)
  map.png          debug map (not shipped)
Data (c) OpenStreetMap contributors (ODbL); elevation (c) Copernicus DEM.
"""
import heapq
import math
import os
import sys
import zlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from common import CACHE, OUT, Proj, ensure_dir, load_json, log, save_json  # noqa: E402
from cities import CITIES, ROAD_WIDTH, ROUTABLE, ROUTE_COST  # noqa: E402
from glb import GLB, earcut  # noqa: E402
import fetch_dem  # noqa: E402
from side_roads import build_side_roads

SAMPLE = 2.0          # m, centreline sample spacing used for smoothing
OUT_SPACING = 6.0     # m, spacing of exported control points
SPLAT_SIZE = 2048
SPLAT_SPAN = 6000.0   # m
CHUNK = 250.0
BUILD_RADIUS = 2300.0
BUILD_NEAR = 650.0
PROP_RADIUS = 1500.0

PALETTES = {
    'tirana': [(0.93, 0.55, 0.20), (0.95, 0.80, 0.25), (0.35, 0.62, 0.85), (0.45, 0.72, 0.42), (0.92, 0.50, 0.62),
               (0.85, 0.82, 0.76), (0.78, 0.76, 0.72), (0.60, 0.62, 0.66), (0.90, 0.88, 0.80), (0.55, 0.60, 0.70)],
    'old': [(0.90, 0.86, 0.76), (0.86, 0.78, 0.62), (0.80, 0.74, 0.62), (0.93, 0.90, 0.84), (0.75, 0.66, 0.52), (0.84, 0.80, 0.70)],
    'stone': [(0.56, 0.56, 0.54), (0.62, 0.60, 0.56), (0.70, 0.68, 0.62), (0.50, 0.50, 0.50), (0.78, 0.76, 0.70)],
    'seaside': [(0.95, 0.94, 0.90), (0.90, 0.88, 0.80), (0.86, 0.82, 0.74), (0.80, 0.86, 0.90), (0.96, 0.90, 0.78)],
}

GREEN_LANDUSE = {'grass', 'forest', 'meadow', 'orchard', 'vineyard', 'farmland', 'farmyard', 'cemetery', 'recreation_ground',
                 'village_green', 'allotments', 'greenfield', 'plant_nursery'}
URBAN_LANDUSE = {'residential', 'commercial', 'retail', 'industrial', 'construction', 'garages', 'religious', 'education',
                 'institutional', 'brownfield', 'military', 'railway'}


def h32(s):
    return zlib.crc32(str(s).encode()) & 0xFFFFFFFF


def rnd(seed, i=0):
    return ((h32(f'{seed}:{i}') % 100000) / 100000.0)


# --------------------------------------------------------------------------- OSM parsing
class Osm:
    def __init__(self, path, proj):
        raw = load_json(path)
        self.nodes = {}
        self.ways = {}
        self.rels = []
        for el in raw['elements']:
            t = el['type']
            if t == 'node':
                x, z = proj.to_xz(el['lat'], el['lon'])
                self.nodes[el['id']] = (x, z, el.get('tags'))
            elif t == 'way':
                self.ways[el['id']] = el
            elif t == 'relation':
                self.rels.append(el)
        log(f'  osm: {len(self.nodes)} nodes, {len(self.ways)} ways, {len(self.rels)} relations')

    def coords(self, way):
        return [(self.nodes[n][0], self.nodes[n][1]) for n in way['nodes'] if n in self.nodes]

    def rings_of_relation(self, rel):
        """Assemble outer rings from member ways (returns list of coord lists)."""
        segs = []
        for m in rel.get('members', []):
            if m['type'] == 'way' and m.get('role', 'outer') in ('outer', ''):
                w = self.ways.get(m['ref'])
                if w:
                    segs.append(list(w['nodes']))
        rings = []
        while segs:
            cur = segs.pop()
            guard = 0
            while cur[0] != cur[-1] and guard < 200:
                guard += 1
                for i, s in enumerate(segs):
                    if s[0] == cur[-1]:
                        cur += s[1:]
                        segs.pop(i)
                        break
                    if s[-1] == cur[-1]:
                        cur += s[::-1][1:]
                        segs.pop(i)
                        break
                else:
                    break
            if len(cur) >= 4 and cur[0] == cur[-1]:
                rings.append([(self.nodes[n][0], self.nodes[n][1]) for n in cur if n in self.nodes])
        return rings


# --------------------------------------------------------------------------- routing
class Graph:
    def __init__(self, osm):
        self.adj = {}
        self.pos = {}
        for w in osm.ways.values():
            tags = w.get('tags') or {}
            hw = tags.get('highway')
            if hw not in ROUTABLE:
                continue
            if tags.get('area') == 'yes' or tags.get('tunnel') in ('yes', 'building_passage'):
                continue
            cost = ROUTE_COST.get(hw, 1.5)
            if tags.get('bridge') == 'yes':
                cost *= 1.05
            nodes = [n for n in w['nodes'] if n in osm.nodes]
            for a, b in zip(nodes, nodes[1:]):
                pa, pb = osm.nodes[a], osm.nodes[b]
                d = math.hypot(pa[0] - pb[0], pa[1] - pb[1])
                if d == 0:
                    continue
                self.adj.setdefault(a, []).append((b, d * cost, hw))
                self.adj.setdefault(b, []).append((a, d * cost, hw))
                self.pos[a] = (pa[0], pa[1])
                self.pos[b] = (pb[0], pb[1])
        self.ids = np.array(list(self.pos.keys()))
        self.xy = np.array([self.pos[i] for i in self.ids]) if len(self.ids) else np.zeros((0, 2))
        # degree for junction detection
        self.deg = {k: len(v) for k, v in self.adj.items()}
        # largest connected component
        seen = set()
        best = set()
        for start in self.adj:
            if start in seen:
                continue
            comp = {start}
            stack = [start]
            while stack:
                u = stack.pop()
                for v, _, _ in self.adj[u]:
                    if v not in comp:
                        comp.add(v)
                        stack.append(v)
            seen |= comp
            if len(comp) > len(best):
                best = comp
        self.main = best
        log(f'  graph: {len(self.pos)} nodes, main component {len(best)}')

    def nearest(self, x, z, major_only=True):
        d = np.hypot(self.xy[:, 0] - x, self.xy[:, 1] - z)
        order = np.argsort(d)[:120]
        if major_only:
            for i in order:
                nid = int(self.ids[i])
                if nid not in self.main:
                    continue
                if any(h in ('primary', 'secondary', 'tertiary', 'trunk', 'primary_link', 'secondary_link', 'unclassified', 'residential', 'living_street', 'pedestrian')
                       for _, _, h in self.adj[nid]) and self.deg[nid] >= 2:
                    return nid
        for i in order:
            if int(self.ids[i]) in self.main:
                return int(self.ids[i])
        return int(self.ids[order[0]])

    def dijkstra(self, src, dst, blocked, penalty_nodes):
        dist = {src: 0.0}
        prev = {}
        pq = [(0.0, src)]
        while pq:
            d, u = heapq.heappop(pq)
            if u == dst:
                break
            if d > dist.get(u, 1e18):
                continue
            for v, w, _ in self.adj.get(u, []):
                if v in blocked and v != dst:
                    continue
                nd = d + w * (6.0 if v in penalty_nodes and v != dst else 1.0)
                if nd < dist.get(v, 1e18):
                    dist[v] = nd
                    prev[v] = u
                    heapq.heappush(pq, (nd, v))
        if dst not in dist:
            return None
        path = [dst]
        while path[-1] != src:
            path.append(prev[path[-1]])
        return path[::-1]


def route_loop(graph, waypoints_xz):
    wp = [graph.nearest(x, z) for x, z in waypoints_xz]
    loop = []
    used = set()
    n = len(wp)
    for i in range(n):
        a, b = wp[i], wp[(i + 1) % n]
        blocked = set(used)
        blocked.discard(a)
        if i == n - 1:
            blocked.discard(wp[0])
        path = graph.dijkstra(a, b, blocked, set())
        if path is None:
            log(f'  leg {i}: no disjoint path, allowing reuse with penalty')
            path = graph.dijkstra(a, b, set(), used)
        if path is None:
            raise RuntimeError(f'no route for leg {i}')
        if loop:
            path = path[1:]
        loop += path
        used.update(path)
    if loop[0] == loop[-1]:
        loop = loop[:-1]
    pts = np.array([graph.pos[i] for i in loop])
    dup = len(loop) - len(set(loop))
    log(f'  route: {len(loop)} nodes, {dup} revisited')
    return pts


# --------------------------------------------------------------------------- centreline
def resample_closed(pts, spacing):
    p = np.vstack([pts, pts[:1]])
    seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
    cum = np.concatenate([[0], np.cumsum(seg)])
    total = cum[-1]
    n = max(8, int(total / spacing))
    s = np.linspace(0, total, n, endpoint=False)
    out = np.zeros((n, p.shape[1]))
    for k in range(p.shape[1]):
        out[:, k] = np.interp(s, cum, p[:, k])
    return out, total


def smooth_closed(a, radius, passes):
    out = a.copy()
    kernel = np.ones(2 * radius + 1) / (2 * radius + 1)
    for _ in range(passes):
        for k in range(out.shape[1]):
            col = out[:, k]
            padded = np.concatenate([col[-radius:], col, col[:radius]])
            out[:, k] = np.convolve(padded, kernel, mode='valid')
    return out


def smooth_elevation(y, spacing):
    y = smooth_closed(y[:, None], 16, 4)[:, 0]
    for _ in range(12):
        slope = np.abs(np.diff(np.concatenate([y, y[:1]]))) / spacing
        if slope.max() < 0.085:
            break
        y = smooth_closed(y[:, None], 12, 1)[:, 0]
    return y


class TrackRef:
    """Distance queries against the dense centreline."""

    def __init__(self, xz, y):
        self.xz = xz
        self.y = y
        n = len(xz)
        nxt = np.roll(xz, -1, axis=0)
        t = nxt - xz
        t /= np.linalg.norm(t, axis=1)[:, None]
        self.tan = t
        self.nrm = np.stack([-t[:, 1], t[:, 0]], axis=1)  # left normal in xz
        # grid index for fast queries
        self.cell = 40.0
        self.grid = {}
        for i, (x, z) in enumerate(xz):
            self.grid.setdefault((int(x // self.cell), int(z // self.cell)), []).append(i)
        self.coarse = xz[::8]

    def coarse_dist(self, x, z):
        return float(np.min(np.hypot(self.coarse[:, 0] - x, self.coarse[:, 1] - z)))

    def nearest(self, x, z, rad_cells=2):
        cx, cz = int(x // self.cell), int(z // self.cell)
        best, bi = 1e18, -1
        # expand rings until a hit is found (then one more ring for safety)
        r = 0
        while r <= rad_cells:
            for dx in range(-r, r + 1):
                for dz in range(-r, r + 1):
                    if max(abs(dx), abs(dz)) != r:
                        continue
                    for i in self.grid.get((cx + dx, cz + dz), ()):
                        d = (self.xz[i, 0] - x) ** 2 + (self.xz[i, 1] - z) ** 2
                        if d < best:
                            best, bi = d, i
            if bi >= 0 and r >= 1 and math.sqrt(best) <= (r - 0.5) * self.cell:
                break
            r += 1
        if bi < 0:
            d = np.hypot(self.xz[:, 0] - x, self.xz[:, 1] - z)
            bi = int(np.argmin(d))
            best = d[bi] ** 2
        return math.sqrt(best), bi

    def signed_lateral(self, x, z):
        d, i = self.nearest(x, z)
        v = np.array([x, z]) - self.xz[i]
        lat = float(v @ self.nrm[i])
        return d, lat, i


# --------------------------------------------------------------------------- terrain
def conform_terrain(h, x0, z0, cell, ref, hw):
    """Carve every grid corner supporting the road below its lowest nearby height.

    A 15 m DEM cell straddles narrow roads. Averaging heights only inside the
    road width leaves uphill corners poking through when Godot interpolates the
    grid, especially on hairpins. Include a full cell diagonal and take the
    minimum nearby road elevation instead of averaging opposing slopes.
    """
    n = h.shape[0]
    inner = hw + math.sqrt(2.0) * cell + 3.0
    outer = inner + 2.0 * cell
    r = int(math.ceil(outer / cell)) + 1
    target = np.full_like(h, np.inf)
    for i, (x, z) in enumerate(ref.xz):
        cx = int(round((x - x0) / cell))
        cz = int(round((z - z0) / cell))
        for dz in range(-r, r + 1):
            rz = cz + dz
            if not 0 <= rz < n:
                continue
            for dx in range(-r, r + 1):
                rx = cx + dx
                if not 0 <= rx < n:
                    continue
                d = math.hypot(x0 + rx * cell - x, z0 + rz * cell - z)
                if d <= outer:
                    target[rz, rx] = min(target[rz, rx], ref.y[i] - 0.5)
    for rz, rx in zip(*np.nonzero(np.isfinite(target))):
        d, _ = ref.nearest(x0 + rx * cell, z0 + rz * cell)
        u = min(1.0, max(0.0, (d - inner) / (outer - inner)))
        blend = 1.0 - u * u * (3.0 - 2.0 * u)
        # Only cut terrain; do not raise it above a lower road on a nearby bend.
        h[rz, rx] = min(h[rz, rx], h[rz, rx] * (1 - blend) + target[rz, rx] * blend)
    return h


def min_filter(h):
    p = np.pad(h, 1, mode='edge')
    out = h.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out = np.minimum(out, p[1 + dy:1 + dy + h.shape[0], 1 + dx:1 + dx + h.shape[1]])
    return out


def mean_filter(h):
    p = np.pad(h, 1, mode='edge')
    acc = np.zeros_like(h)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            acc += p[1 + dy:1 + dy + h.shape[0], 1 + dx:1 + dx + h.shape[1]]
    return acc / 9.0


def sample_grid(h, x0, z0, cell, x, z):
    n = h.shape[0]
    fx = np.clip((np.asarray(x) - x0) / cell, 0, n - 1.001)
    fz = np.clip((np.asarray(z) - z0) / cell, 0, n - 1.001)
    ix, iz = np.floor(fx).astype(int), np.floor(fz).astype(int)
    tx, tz = fx - ix, fz - iz
    return (h[iz, ix] * (1 - tx) * (1 - tz) + h[iz, ix + 1] * tx * (1 - tz)
            + h[iz + 1, ix] * (1 - tx) * tz + h[iz + 1, ix + 1] * tx * tz)


# --------------------------------------------------------------------------- buildings
def parse_height(tags, seed, style):
    h = tags.get('height')
    if h:
        try:
            return max(3.0, float(str(h).replace('m', '').strip().split(';')[0]))
        except ValueError:
            pass
    lv = tags.get('building:levels')
    if lv:
        try:
            return max(3.0, float(str(lv).split(';')[0]) * 3.1 + 1.0)
        except ValueError:
            pass
    b = tags.get('building', 'yes')
    if b in ('house', 'detached', 'semidetached_house', 'bungalow', 'hut', 'shed', 'garage', 'garages'):
        return 4.0 + 4.0 * rnd(seed, 1)
    if b in ('apartments', 'commercial', 'office', 'hotel'):
        return 14.0 + 16.0 * rnd(seed, 1)
    if style == 'tirana':
        return 7.0 + 12.0 * rnd(seed, 1)
    return 5.5 + 6.0 * rnd(seed, 1)


def poly_area(p):
    a = 0.0
    for i in range(len(p)):
        x0, y0 = p[i]
        x1, y1 = p[(i + 1) % len(p)]
        a += x0 * y1 - x1 * y0
    return abs(a) / 2


def clean_ring(ring):
    if len(ring) > 1 and ring[0] == ring[-1]:
        ring = ring[:-1]
    out = []
    for p in ring:
        if not out or math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > 0.3:
            out.append(p)
    if len(out) > 2 and math.hypot(out[0][0] - out[-1][0], out[0][1] - out[-1][1]) <= 0.3:
        out.pop()
    # enforce counter-clockwise in (x, z) plane mathematically (x right, z down => visually clockwise)
    if len(out) >= 3:
        a = 0.0
        for i in range(len(out)):
            x0, y0 = out[i]
            x1, y1 = out[(i + 1) % len(out)]
            a += x0 * y1 - x1 * y0
        if a < 0:
            out.reverse()
    return out


def build_buildings(osm, ref, hw, terrain_sample, style, out_path):
    footprints = []
    for w in osm.ways.values():
        tags = w.get('tags') or {}
        if 'building' not in tags or tags.get('building') == 'no':
            continue
        if w['nodes'][0] != w['nodes'][-1]:
            continue
        footprints.append((w['id'], tags, osm.coords(w)))
    for rel in osm.rels:
        tags = rel.get('tags') or {}
        if 'building' not in tags:
            continue
        for k, ring in enumerate(osm.rings_of_relation(rel)):
            footprints.append((f"r{rel['id']}_{k}", tags, ring))
    log(f'  buildings: {len(footprints)} footprints')

    chunks = {}
    kept = 0
    pal = PALETTES.get(style, PALETTES['old'])
    for bid, tags, ring in footprints:
        ring = clean_ring(ring)
        if len(ring) < 3:
            continue
        arr = np.array(ring)
        cx, cz = arr.mean(axis=0)
        if math.hypot(cx, cz) > BUILD_RADIUS:
            continue
        area = poly_area(ring)
        if area < 12:
            continue
        # keep buildings near the track; distant ones only when tall enough to show on the skyline
        d_track = ref.coarse_dist(cx, cz)
        pre_h = parse_height(tags, bid, style)
        if d_track > BUILD_NEAR and not (pre_h > 22 and d_track < BUILD_RADIUS):
            continue
        # push away from the track corridor
        lats = []
        dmin = 1e9
        for (x, z) in ring:
            d, lat, i = ref.signed_lateral(x, z)
            lats.append(lat)
            dmin = min(dmin, d)
        if dmin < hw + 2.5:
            if min(lats) < 0 < max(lats) or dmin < 1.0 and min(abs(l) for l in lats) < 1.0:
                continue  # straddles the centreline
            side = 1.0 if np.mean(lats) > 0 else -1.0
            push = (hw + 2.5) - min(abs(l) for l in lats)
            d0, _, i0 = ref.signed_lateral(cx, cz)
            nrm = ref.nrm[i0] * side
            arr = arr + nrm[None, :] * push
            ring = [tuple(p) for p in arr]
            cx, cz = arr.mean(axis=0)
            if math.hypot(cx, cz) > BUILD_RADIUS:
                continue
            # still intersecting? (corner cases around curves)
            if min(ref.nearest(x, z)[0] for x, z in ring) < hw + 1.0:
                continue
        height = parse_height(tags, bid, style)
        base = float(terrain_sample(arr[:, 0], arr[:, 1]).min()) - 0.6
        top = base + height
        seed_c = rnd(bid, 2)
        col = pal[int(seed_c * len(pal)) % len(pal)]
        shade = 0.85 + 0.3 * rnd(bid, 3)
        col = tuple(min(1.0, c * shade) for c in col)
        glass = 1.0 if (height > 30 and rnd(bid, 4) < 0.6) or tags.get('building') in ('office', 'hotel') and height > 18 else 0.0
        if glass:
            col = (0.35, 0.45, 0.55)
        kind = 1.0 if glass else 0.0
        key = (int(math.floor(cx / CHUNK)), int(math.floor(cz / CHUNK)))
        ch = chunks.setdefault(key, {'wall': [], 'roof': []})

        # walls
        n = len(ring)
        wp, wn, wuv, wc, wi = ch['wall'] and ch['wall'][-1] or ([], [], [], [], [])
        if not ch['wall']:
            ch['wall'].append((wp, wn, wuv, wc, wi))
        u = 0.0
        for i in range(n):
            x0, z0 = ring[i]
            x1, z1 = ring[(i + 1) % n]
            L = math.hypot(x1 - x0, z1 - z0)
            if L < 0.2:
                continue
            nx, nz = (z1 - z0) / L, -(x1 - x0) / L   # outward normal for CCW (x, z) rings
            k = len(wp)
            wp += [(x0, base, z0), (x1, base, z1), (x1, top, z1), (x0, top, z0)]
            wn += [(nx, 0, nz)] * 4
            wuv += [(u, 0), (u + L, 0), (u + L, height), (u, height)]
            wc += [(col[0], col[1], col[2], kind)] * 4
            wi += [(k, k + 2, k + 1), (k, k + 3, k + 2)]
            u += L
        # roof
        rp, rn, ruv, rc, ri = ch['roof'] and ch['roof'][-1] or ([], [], [], [], [])
        if not ch['roof']:
            ch['roof'].append((rp, rn, ruv, rc, ri))
        small = area < 320 and height < 12
        k0 = len(rp)
        if small and style in ('old', 'stone', 'seaside') and n <= 8:
            ridge = min(3.2, 0.28 * math.sqrt(area)) + 0.5
            rcol = (0.62, 0.36, 0.25) if style != 'stone' else (0.45, 0.45, 0.45)
            rp.append((cx, top + ridge, cz))
            rn.append((0, 1, 0))
            ruv.append((cx, cz))
            rc.append((rcol[0], rcol[1], rcol[2], 0.5))
            for i in range(n):
                x0, z0 = ring[i]
                x1, z1 = ring[(i + 1) % n]
                k = len(rp)
                rp += [(x0, top, z0), (x1, top, z1)]
                ex, ez = x1 - x0, z1 - z0
                nx, ny, nz = ez, (ex * ex + ez * ez) ** 0.5 * 0.9, -ex
                ln = (nx * nx + ny * ny + nz * nz) ** 0.5 or 1
                rn += [(nx / ln, ny / ln, nz / ln)] * 2
                ruv += [(x0, z0), (x1, z1)]
                rc += [(rcol[0], rcol[1], rcol[2], 0.5)] * 2
                ri.append((k0, k + 1, k))
        else:
            tris = earcut(ring)
            rcol = (0.30, 0.30, 0.32) if not glass else (0.25, 0.30, 0.35)
            for (x, z) in ring:
                rp.append((x, top, z))
                rn.append((0, 1, 0))
                ruv.append((x, z))
                rc.append((rcol[0], rcol[1], rcol[2], 0.5))
            for a, b, c in tris:
                ri.append((k0 + a, k0 + c, k0 + b))
        kept += 1

    g = GLB()
    m_wall = g.material('facade', (0.8, 0.8, 0.8, 1), 0.0, 0.7)
    m_roof = g.material('roof', (0.35, 0.35, 0.35, 1), 0.0, 0.9)
    roots = []
    tri_total = 0
    for (kx, kz), ch in sorted(chunks.items()):
        ox, oz = (kx + 0.5) * CHUNK, (kz + 0.5) * CHUNK
        prims = []
        for name, mat in (('wall', m_wall), ('roof', m_roof)):
            for (p, nrm, uv, c, idx) in ch[name]:
                if not idx:
                    continue
                pos = np.array(p, dtype=np.float32)
                pos[:, 0] -= ox
                pos[:, 2] -= oz
                prims.append({'pos': pos, 'nrm': np.array(nrm, np.float32), 'uv': np.array(uv, np.float32),
                              'col': np.array(c, np.float32), 'idx': np.array(idx, np.uint32).ravel(), 'mat': mat})
                tri_total += len(idx)
        mi = g.mesh(f'chunk_{kx}_{kz}', prims)
        if mi is not None:
            roots.append(g.node(f'chunk_{kx}_{kz}', mi, (ox, 0, oz)))
    size = g.write(out_path, roots)
    log(f'  buildings kept {kept}, chunks {len(roots)}, tris {tri_total}, glb {size // 1024} kB')
    return kept


# --------------------------------------------------------------------------- splat + props
def build_splat(osm, ref, hw, out_png, map_draw=None, map_tf=None):
    S = SPLAT_SIZE
    k = S / SPLAT_SPAN

    def tf(p):
        return ((p[0] + SPLAT_SPAN / 2) * k, (p[1] + SPLAT_SPAN / 2) * k)

    road = Image.new('L', (S, S), 0)
    green = Image.new('L', (S, S), 0)
    water = Image.new('L', (S, S), 0)
    urban = Image.new('L', (S, S), 0)
    dr, dg, dw, du = ImageDraw.Draw(road), ImageDraw.Draw(green), ImageDraw.Draw(water), ImageDraw.Draw(urban)

    def polys(filter_fn):
        for w in osm.ways.values():
            tags = w.get('tags') or {}
            if filter_fn(tags) and w['nodes'][0] == w['nodes'][-1]:
                yield osm.coords(w)
        for rel in osm.rels:
            tags = rel.get('tags') or {}
            if filter_fn(tags):
                for ring in osm.rings_of_relation(rel):
                    yield ring

    for ring in polys(lambda t: t.get('landuse') in URBAN_LANDUSE):
        du.polygon([tf(p) for p in ring], fill=255)
    for ring in polys(lambda t: t.get('landuse') in GREEN_LANDUSE or t.get('leisure') in ('park', 'pitch', 'garden')
                      or t.get('natural') in ('wood', 'scrub', 'grassland')):
        dg.polygon([tf(p) for p in ring], fill=255)
    for ring in polys(lambda t: t.get('natural') == 'water' or t.get('landuse') == 'reservoir' or t.get('water')):
        dw.polygon([tf(p) for p in ring], fill=255)
    for w in osm.ways.values():
        tags = w.get('tags') or {}
        ww = tags.get('waterway')
        if ww in ('river', 'canal', 'stream'):
            width = {'river': 14, 'canal': 8, 'stream': 3}[ww]
            dw.line([tf(p) for p in osm.coords(w)], fill=255, width=max(2, int(width * k)))
        hw_tag = tags.get('highway')
        if hw_tag and hw_tag in ROAD_WIDTH and tags.get('area') != 'yes':
            width = ROAD_WIDTH[hw_tag]
            dr.line([tf(p) for p in osm.coords(w)], fill=255, width=max(1, int(round(width * k))), joint='curve')
    # the race track itself (wider than its OSM street)
    track_pts = [tf(p) for p in ref.xz] + [tf(ref.xz[0])]
    dr.line(track_pts, fill=255, width=max(2, int(round((2 * hw + 4) * k))), joint='curve')
    # buildings footprints raise the "urban" channel too
    for ring in polys(lambda t: 'building' in t):
        du.polygon([tf(p) for p in ring], fill=255)
    urban = urban.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2))
    green = green.filter(ImageFilter.GaussianBlur(1))
    water = water.filter(ImageFilter.GaussianBlur(0.6))
    road = road.filter(ImageFilter.GaussianBlur(0.5))
    img = Image.merge('RGBA', (road, green, water, urban))
    img.save(out_png, optimize=True)
    return img


def build_props(osm, ref, hw, terrain_sample, city, proj, out_json, landmark_tf):
    lamps, trees = [], []
    for nid, (x, z, tags) in osm.nodes.items():
        if not tags or math.hypot(x, z) > PROP_RADIUS:
            continue
        d, lat, i = ref.signed_lateral(x, z)
        if tags.get('highway') == 'street_lamp' and d > hw + 1.0:
            lamps.append([round(x, 1), round(float(terrain_sample([x], [z])[0]), 1), round(z, 1)])
        elif tags.get('natural') == 'tree' and d > hw + 2.0:
            trees.append([round(x, 1), round(float(terrain_sample([x], [z])[0]), 1), round(z, 1), round(0.8 + 0.6 * rnd(nid), 2)])
    # scatter trees in parks/woods
    rng = np.random.default_rng(h32(city))
    for w in osm.ways.values():
        tags = w.get('tags') or {}
        if not (tags.get('leisure') in ('park', 'garden') or tags.get('landuse') in ('forest', 'grass', 'cemetery') or tags.get('natural') == 'wood'):
            continue
        if w['nodes'][0] != w['nodes'][-1]:
            continue
        ring = clean_ring(osm.coords(w))
        if len(ring) < 3:
            continue
        arr = np.array(ring)
        if math.hypot(*arr.mean(axis=0)) > PROP_RADIUS:
            continue
        area = poly_area(ring)
        n = min(400, int(area / 220))
        if n == 0:
            continue
        mn, mx = arr.min(axis=0), arr.max(axis=0)
        img = Image.new('L', (64, 64), 0)
        sc = 64 / np.maximum(mx - mn, 1e-3)
        ImageDraw.Draw(img).polygon([((p[0] - mn[0]) * sc[0], (p[1] - mn[1]) * sc[1]) for p in ring], fill=255)
        mask = np.array(img)
        cand = rng.uniform(mn, mx, size=(n * 3, 2))
        for (x, z) in cand:
            px, pz = int((x - mn[0]) * sc[0]), int((z - mn[1]) * sc[1])
            if 0 <= px < 64 and 0 <= pz < 64 and mask[pz, px] and ref.nearest(x, z)[0] > hw + 3.0:
                trees.append([round(float(x), 1), round(float(terrain_sample([x], [z])[0]), 1), round(float(z), 1), round(0.7 + 0.7 * rng.random(), 2)])
                if len(trees) >= 6000:
                    break
        if len(trees) >= 6000:
            break
    # lamps along the track every 28 m, alternating sides, where OSM has none nearby
    track_lamps = []
    step = int(28 / SAMPLE)
    for i in range(0, len(ref.xz), step):
        side = 1 if (i // step) % 2 == 0 else -1
        p = ref.xz[i] + ref.nrm[i] * (hw + 1.2) * side
        track_lamps.append([round(float(p[0]), 1), round(float(ref.y[i]), 1), round(float(p[1]), 1), round(float(math.atan2(-ref.tan[i][0], -ref.tan[i][1])), 3)])
    landmarks = []
    for lm in city.get('landmarks', []):
        x, z = proj.to_xz(*lm['ll'])
        y = float(terrain_sample([x], [z])[0])
        landmarks.append({'id': lm['id'], 'x': round(x, 1), 'y': round(y, 1), 'z': round(z, 1), 'yaw': lm.get('yaw', 0)})
    save_json(out_json, {'lamps': lamps, 'track_lamps': track_lamps, 'trees': trees, 'landmarks': landmarks})
    log(f'  props: {len(lamps)} lamps, {len(track_lamps)} track lamps, {len(trees)} trees, {len(landmarks)} landmarks')


# --------------------------------------------------------------------------- debug map
def debug_map(osm, ref, hw, city, proj, path, span=4200, size=2100):
    k = size / span
    img = Image.new('RGB', (size, size), (24, 26, 30))
    d = ImageDraw.Draw(img)

    def tf(p):
        return ((p[0] + span / 2) * k, (p[1] + span / 2) * k)

    for w in osm.ways.values():
        tags = w.get('tags') or {}
        if 'building' in tags and w['nodes'][0] == w['nodes'][-1]:
            d.polygon([tf(p) for p in osm.coords(w)], fill=(60, 62, 70))
    for w in osm.ways.values():
        tags = w.get('tags') or {}
        hwt = tags.get('highway')
        if hwt in ROAD_WIDTH:
            col = (160, 160, 165) if hwt in ('primary', 'secondary', 'trunk') else (105, 105, 110)
            d.line([tf(p) for p in osm.coords(w)], fill=col, width=max(1, int(ROAD_WIDTH[hwt] * k)))
    if span <= 2500:
        seen = set()
        for w in osm.ways.values():
            tags = w.get('tags') or {}
            name = tags.get('name')
            if not name or tags.get('highway') not in ('primary', 'secondary', 'tertiary', 'trunk', 'residential', 'unclassified', 'pedestrian', 'living_street'):
                continue
            c = osm.coords(w)
            if len(c) < 2:
                continue
            mid = c[len(c) // 2]
            if math.hypot(*mid) > span / 2 or name in seen:
                continue
            seen.add(name)
            x, z = tf(mid)
            d.text((x, z), name[:28], fill=(230, 230, 120))
    pts = [tf(p) for p in ref.xz] + [tf(ref.xz[0])]
    d.line(pts, fill=(255, 60, 60), width=max(2, int(2 * hw * k)))
    d.ellipse([tf(ref.xz[0])[0] - 12, tf(ref.xz[0])[1] - 12, tf(ref.xz[0])[0] + 12, tf(ref.xz[0])[1] + 12], fill=(60, 255, 90))
    for i, (lat, lon) in enumerate(city['waypoints']):
        x, z = tf(proj.to_xz(lat, lon))
        d.ellipse([x - 7, y - 7, x + 7, y + 7] if False else [x - 7, z - 7, x + 7, z + 7], outline=(90, 180, 255), width=3)
        d.text((x + 9, z - 6), str(i), fill=(90, 180, 255))
    for lm in city.get('landmarks', []):
        x, z = tf(proj.to_xz(*lm['ll']))
        d.rectangle([x - 8, z - 8, x + 8, z + 8], outline=(255, 220, 60), width=3)
        d.text((x + 11, z - 6), lm['id'], fill=(255, 220, 60))
    d.text((10, 10), f"{city['name']}  track {ref.length:.0f} m  hw {hw} m", fill=(255, 255, 255))
    img.save(path)


# --------------------------------------------------------------------------- main
def build(cid, route_only=False):
    city = CITIES[cid]
    lat0, lon0 = city['origin']
    proj = Proj(lat0, lon0)
    hw = city['half_width']
    out = ensure_dir(os.path.join(OUT, cid))
    log(f'[{cid}] build')
    osm = Osm(os.path.join(CACHE, 'osm', f'{cid}.json'), proj)

    # 1. route the loop
    g = Graph(osm)
    wps = [proj.to_xz(lat, lon) for lat, lon in city['waypoints']]
    raw = route_loop(g, wps)
    if len(raw) != len(set(map(tuple, raw))):
        raise RuntimeError(f'{cid}: route doubles back; correct the city waypoints before export')
    dense, length = resample_closed(raw, SAMPLE)
    dense = smooth_closed(dense, 7, 3)
    dense, length = resample_closed(dense, SAMPLE)
    log(f'  track length {length:.0f} m, {len(dense)} samples')

    # 2. terrain
    meta = load_json(os.path.join(CACHE, 'dem', f'{cid}_dem.json'))
    near = np.load(os.path.join(CACHE, 'dem', f'{cid}_near.npy'))
    far = np.load(os.path.join(CACHE, 'dem', f'{cid}_far.npy'))
    near = mean_filter(min_filter(near))
    nm = meta['near']
    y_raw = sample_grid(near, nm['x0'], nm['z0'], nm['cell'], dense[:, 0], dense[:, 1])
    y = smooth_elevation(y_raw.astype(np.float64), SAMPLE)
    ref = TrackRef(dense, y)
    ref.length = length
    if route_only:
        debug_map(osm, ref, hw, city, proj, os.path.join(CACHE, f'{cid}_map.png'))
        debug_map(osm, ref, hw, city, proj, os.path.join(CACHE, f'{cid}_zoom.png'), span=1800, size=1800)
        return
    near = conform_terrain(near, nm['x0'], nm['z0'], nm['cell'], ref, hw)
    sea = bool(city.get('sea') or city.get('lake'))
    sea_level = 0.3 if city.get('sea') else (float(np.percentile(near, 2)) + 0.5 if city.get('lake') else -50.0)
    if sea:
        near = np.maximum(near, sea_level - 2.0) if city.get('sea') else near
    near.astype('<f4').tofile(os.path.join(out, 'terrain_near.bin'))
    far.astype('<f4').tofile(os.path.join(out, 'terrain_far.bin'))
    save_json(os.path.join(out, 'terrain.json'), {
        'near': {'x0': nm['x0'], 'z0': nm['z0'], 'cell': nm['cell'], 'n': nm['n']},
        'far': {'x0': meta['far']['x0'], 'z0': meta['far']['z0'], 'cell': meta['far']['cell'], 'n': meta['far']['n']},
        'splat': {'span': SPLAT_SPAN, 'size': SPLAT_SIZE},
        'sea_level': sea_level,
        'origin': {'lat': lat0, 'lon': lon0},
    }, compact=False)

    def terrain_sample(x, z):
        return sample_grid(near, nm['x0'], nm['z0'], nm['cell'], np.asarray(x, float), np.asarray(z, float))

    # 3. track export
    step = int(OUT_SPACING / SAMPLE)
    pts = [[round(float(dense[i, 0]), 2), round(float(y[i]), 2), round(float(dense[i, 1]), 2)] for i in range(0, len(dense), step)]
    save_json(os.path.join(out, 'track.json'), {
        'id': cid, 'name': city['name'], 'hw': hw, 'length': round(length, 1), 'pts': pts,
        'style': city['style'], 'sea_level': sea_level,
    })
    log(f'  track.json {len(pts)} control points, elevation {y.min():.1f}..{y.max():.1f} m')

    # 4. buildings, splat, props
    build_buildings(osm, ref, hw, terrain_sample, city['style'], os.path.join(out, 'buildings.glb'))
    build_side_roads(osm, ref, hw, terrain_sample, os.path.join(out, 'roads.glb'))
    build_splat(osm, ref, hw, os.path.join(out, 'splat.png'))
    build_props(osm, ref, hw, terrain_sample, city, proj, os.path.join(out, 'props.json'), None)
    debug_map(osm, ref, hw, city, proj, os.path.join(CACHE, f'{cid}_map.png'))
    debug_map(osm, ref, hw, city, proj, os.path.join(CACHE, f'{cid}_zoom.png'), span=1800, size=1800)
    log(f'  done -> {out}')


if __name__ == '__main__':
    ids = [a for a in sys.argv[1:] if not a.startswith('-')]
    for c in ids or ['tirane']:
        build(c, route_only='--route-only' in sys.argv)
