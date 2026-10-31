"""Procedural car generator -> godot/assets/cars/<id>.glb

Six original, trademark-free cars. Each GLB: a lofted body (paint + glass + lights + trim
materials, belt-line crease, wheel arches), interior, details, and four wheel nodes
(wheel_fl/fr/rl/rr) sharing one spoked rim + tyre mesh. ~30-45k triangles per car.
Forward = -Z (Godot), right = +X, ground contact y = 0.

Materials are swapped by name at runtime (godot/scripts/cars/car_visual.gd):
  paint glass light_front light_rear trim chrome interior tyre rim brake plate
"""
import argparse
import math
import os
import sys

import numpy as np
from scipy.interpolate import PchipInterpolator

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'pipeline'))
from glb import GLB, face_normals_smooth  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'godot', 'assets', 'cars')

NU = 150   # stations along the body
N1 = 20    # points lower half-section (bottom centre -> belt)
N2 = 22    # points upper half-section (belt -> roof centre)

# u: 0 = front, 1 = rear. All heights in metres (ground = 0).
CARS = {
    'benxi': dict(  # big GT coupe
        L=4.75, W=2.0, wheel_r=0.36, tyre_w=0.27, spokes=5, rim=0.66, tumble=0.42,
        floor=[(0, .30), (.08, .25), (.5, .21), (.92, .25), (1, .31)],
        belt=[(0, .60), (.05, .70), (.30, .82), (.5, .86), (.75, .89), (.92, .87), (1, .80)],
        roof=[(0, .60), (.05, .70), (.30, .82), (.36, .95), (.46, 1.24), (.52, 1.32), (.66, 1.32), (.78, 1.18),
              (.88, .98), (.93, .88), (1, .80)],
        hw=[(0, .78), (.04, .92), (.15, 1.0), (.85, 1.0), (.96, .93), (1, .80)],
        glass=[(.31, .50), (.52, .80), (.82, .91)],
        wheels=(.17, .80), extras=['lip', 'twin_exhaust', 'mirrors']),
    'uragani': dict(  # mid-engine supercar
        L=4.6, W=2.02, wheel_r=0.35, tyre_w=0.30, spokes=7, rim=0.70, tumble=0.5,
        floor=[(0, .20), (.1, .15), (.5, .13), (.9, .15), (1, .22)],
        belt=[(0, .40), (.08, .54), (.25, .66), (.40, .72), (.6, .78), (.8, .86), (.95, .88), (1, .82)],
        roof=[(0, .40), (.08, .54), (.25, .66), (.30, .74), (.40, 1.0), (.48, 1.12), (.58, 1.12), (.68, 1.02),
              (.78, .90), (.86, .87), (1, .82)],
        hw=[(0, .70), (.05, .88), (.2, 1.0), (.45, .98), (.7, 1.01), (.9, 1.0), (1, .90)],
        glass=[(.28, .47), (.49, .66), (.68, .78)],
        wheels=(.16, .80), extras=['wing', 'quad_exhaust', 'mirrors', 'diffuser']),
    'kercyesi': dict(  # hot hatch
        L=4.1, W=1.8, wheel_r=0.32, tyre_w=0.22, spokes=6, rim=0.62, tumble=0.32,
        floor=[(0, .30), (.08, .25), (.5, .22), (.92, .25), (1, .30)],
        belt=[(0, .60), (.05, .73), (.25, .84), (.35, .90), (.6, .94), (.9, .96), (1, .94)],
        roof=[(0, .60), (.05, .73), (.25, .84), (.30, .92), (.40, 1.28), (.47, 1.45), (.75, 1.45), (.85, 1.40),
              (.93, 1.28), (.97, 1.05), (1, .94)],
        hw=[(0, .72), (.05, .85), (.15, .90), (.90, .90), (.97, .84), (1, .74)],
        glass=[(.27, .46), (.48, .70), (.72, .88), (.905, .975)],
        wheels=(.17, .80), extras=['roof_spoiler', 'twin_exhaust', 'mirrors']),
    'shigjeta': dict(  # AWD sports sedan
        L=4.7, W=1.9, wheel_r=0.34, tyre_w=0.25, spokes=10, rim=0.64, tumble=0.36,
        floor=[(0, .30), (.08, .25), (.5, .22), (.92, .25), (1, .31)],
        belt=[(0, .60), (.05, .72), (.28, .84), (.5, .90), (.8, .92), (.95, .90), (1, .84)],
        roof=[(0, .60), (.05, .72), (.28, .84), (.34, .95), (.44, 1.30), (.50, 1.40), (.68, 1.40), (.76, 1.30),
              (.84, 1.05), (.88, .93), (.95, .90), (1, .84)],
        hw=[(0, .76), (.04, .88), (.15, .95), (.88, .95), (.96, .89), (1, .78)],
        glass=[(.29, .48), (.50, .62), (.64, .74), (.77, .87)],
        wheels=(.16, .80), extras=['lip', 'quad_exhaust', 'mirrors']),
    'gelendvagen': dict(  # boxy off-roader
        L=4.65, W=2.0, wheel_r=0.42, tyre_w=0.30, spokes=5, rim=0.58, tumble=0.12,
        floor=[(0, .48), (.05, .45), (.5, .43), (.95, .45), (1, .48)],
        belt=[(0, 1.02), (.03, 1.10), (.30, 1.14), (1, 1.14)],
        roof=[(0, 1.02), (.03, 1.10), (.30, 1.14), (.32, 1.22), (.37, 1.88), (.40, 1.95), (.97, 1.95), (.99, 1.80),
              (1, 1.14)],
        hw=[(0, .84), (.02, .95), (.08, 1.0), (.98, 1.0), (1, .95)],
        glass=[(.33, .39), (.41, .61), (.65, .80), (.83, .96), (.975, .995)],
        wheels=(.18, .80), extras=['roof_rack', 'spare', 'bullbar', 'steps', 'mirrors', 'single_exhaust']),
    'sprinteri': dict(  # intercity van
        L=5.9, W=2.05, wheel_r=0.38, tyre_w=0.24, spokes=8, rim=0.55, tumble=0.08,
        floor=[(0, .42), (.04, .36), (.5, .34), (.96, .36), (1, .42)],
        belt=[(0, .72), (.04, .90), (.14, 1.02), (.30, 1.15), (1, 1.15)],
        roof=[(0, .72), (.04, .90), (.14, 1.02), (.17, 1.25), (.24, 2.2), (.28, 2.5), (.985, 2.5), (.995, 2.4),
              (1, 1.2)],
        hw=[(0, .78), (.03, .95), (.1, 1.025), (.98, 1.025), (1, .98)],
        glass=[(.165, .27), (.29, .42)],
        wheels=(.17, .78), extras=['mirrors', 'single_exhaust', 'van_stripe']),
}

MATS = {
    'paint': dict(color=(0.6, 0.6, 0.65, 1), metallic=0.2, roughness=0.35),
    'glass': dict(color=(0.1, 0.14, 0.18, 0.55), metallic=0.0, roughness=0.05),
    'light_front': dict(color=(0.9, 0.95, 1.0, 1), metallic=0.0, roughness=0.2, emissive=(1, 1, 1)),
    'light_rear': dict(color=(0.6, 0.05, 0.05, 1), metallic=0.0, roughness=0.3, emissive=(1, 0.05, 0.02)),
    'trim': dict(color=(0.05, 0.05, 0.055, 1), metallic=0.0, roughness=0.7),
    'chrome': dict(color=(0.85, 0.85, 0.88, 1), metallic=1.0, roughness=0.15),
    'interior': dict(color=(0.08, 0.08, 0.09, 1), metallic=0.0, roughness=0.9),
    'tyre': dict(color=(0.04, 0.04, 0.045, 1), metallic=0.0, roughness=0.85),
    'rim': dict(color=(0.75, 0.75, 0.78, 1), metallic=1.0, roughness=0.25),
    'brake': dict(color=(0.7, 0.1, 0.08, 1), metallic=0.3, roughness=0.5),
    'plate': dict(color=(0.95, 0.95, 0.9, 1), metallic=0.0, roughness=0.5),
}


# ---------------------------------------------------------------- helpers
def curve(keys, u):
    xs = np.array([k[0] for k in keys], dtype=np.float64)
    ys = np.array([k[1] for k in keys], dtype=np.float64)
    return PchipInterpolator(xs, ys)(np.clip(u, 0, 1))


def bezier(p0, p1, p2, p3, n):
    t = np.linspace(0, 1, n)[:, None]
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * (t ** 2) * p2 + (t ** 3) * p3


def in_ranges(u, ranges):
    return any(a <= u <= b for a, b in ranges)


class Builder:
    def __init__(self):
        self.g = GLB()
        for n, m in MATS.items():
            self.g.material(n, **m)
        self.prims = []  # body primitives

    def mat(self, name):
        return self.g.material(name)

    # generic primitives ---------------------------------------------------
    def add_tris(self, pos, idx, mat, nrm=None, uv=None, inward=False):
        pos = np.asarray(pos, dtype=np.float32)
        idx = np.asarray(idx, dtype=np.uint32).reshape(-1, 3)
        if nrm is None:
            nrm = face_normals_smooth(pos, idx)
        if uv is None:
            uv = pos[:, [2, 1]]
        self.prims.append(dict(pos=pos, nrm=nrm, uv=uv, idx=idx, mat=self.mat(mat), inward=inward))

    def box(self, center, size, mat, rot_y=0.0, rot_x=0.0):
        cx, cy, cz = center
        sx, sy, sz = size
        corners = np.array([[x, y, z] for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)]) * [sx, sy, sz]
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        pos, nrm, idx = [], [], []
        for f in faces:
            q = corners[list(f)]
            n = np.cross(q[1] - q[0], q[2] - q[0])
            n /= np.linalg.norm(n) + 1e-9
            # ensure outward
            if np.dot(n, q.mean(axis=0)) < 0:
                q = q[::-1]
                n = -n
            b = len(pos)
            pos.extend(q)
            nrm.extend([n] * 4)
            idx.extend([(b, b + 1, b + 2), (b, b + 2, b + 3)])
        pos = np.array(pos)
        nrm = np.array(nrm)
        if rot_x:
            c, s = math.cos(rot_x), math.sin(rot_x)
            R = np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
            pos = pos @ R.T
            nrm = nrm @ R.T
        if rot_y:
            c, s = math.cos(rot_y), math.sin(rot_y)
            R = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
            pos = pos @ R.T
            nrm = nrm @ R.T
        pos = pos + [cx, cy, cz]
        self.add_tris(pos, idx, mat, nrm=nrm)

    def lathe_x(self, profile, mat, cx=(0, 0, 0), seg=48, close_ends=False, inward=False):
        """Revolve profile [(x, r), ...] around the X axis (axle). inward=True for surfaces seen from the axis."""
        prof = np.array(profile, dtype=np.float64)
        ang = np.linspace(0, 2 * math.pi, seg, endpoint=False)
        pos = []
        for x, r in prof:
            for a in ang:
                pos.append([x, r * math.cos(a), r * math.sin(a)])
        pos = np.array(pos)
        idx = []
        m = len(prof)
        for i in range(m - 1):
            for j in range(seg):
                a = i * seg + j
                b = i * seg + (j + 1) % seg
                c = (i + 1) * seg + j
                d = (i + 1) * seg + (j + 1) % seg
                # outward CCW for a profile whose x (or r) grows along the list
                idx.append((a, b, c))
                idx.append((b, d, c))
        idx = np.array(idx)
        pos = pos + np.array(cx)
        self.add_tris(pos, idx, mat, inward=inward)

    def cyl_z(self, center, r, length, mat, seg=16):
        prof = [(-length / 2, 0.0001), (-length / 2, r), (length / 2, r), (length / 2, 0.0001)]
        # build along X then rotate to Z
        prof = np.array(prof)
        ang = np.linspace(0, 2 * math.pi, seg, endpoint=False)
        pos = []
        for x, rr in prof:
            for a in ang:
                pos.append([rr * math.cos(a), rr * math.sin(a), x])
        pos = np.array(pos)
        idx = []
        for i in range(len(prof) - 1):
            for j in range(seg):
                a = i * seg + j
                b = i * seg + (j + 1) % seg
                c = (i + 1) * seg + j
                d = (i + 1) * seg + (j + 1) % seg
                idx.append((a, b, c))
                idx.append((b, d, c))
        self.add_tris(pos + np.array(center), np.array(idx), mat)

    def flush(self, name):
        for p in self.prims:
            if p.get('inward'):
                continue
            v = signed_volume(p['pos'], p['idx'])
            if v < -1e-4:
                print(f'  WARNING: {name} primitive with material #{p["mat"]} looks inside-out (volume {v:.4f})')
        mid = self.g.mesh(name, self.prims)
        self.prims = []
        return mid


def signed_volume(pos, idx):
    """Signed volume of a triangle soup; positive for outward CCW winding (glTF front faces)."""
    tri = np.asarray(pos, dtype=np.float64)[np.asarray(idx).reshape(-1, 3)]
    return float(np.einsum('ij,ij->i', tri[:, 0], np.cross(tri[:, 1], tri[:, 2])).sum() / 6.0)


# ---------------------------------------------------------------- body loft
def half_section(fy, by, ry, hwb, tumble, arch):
    """Right half of the cross-section. Returns (pts (N1+N2, 2), glass_mask for upper part)."""
    hwf = hwb - 0.10
    # lower: bottom centre -> rocker -> belt
    p0 = np.array([0.0, fy])
    p1 = np.array([hwf - 0.25, fy])
    p2 = np.array([hwb, fy + 0.22])
    p3 = np.array([hwb, by])
    lower = np.vstack([
        np.linspace(p0, p1, 7, endpoint=False),
        bezier(p1, np.array([hwf + 0.02, fy]), np.array([hwb, fy + 0.05]), p2, 7),
        np.linspace(p2, p3, N1 - 14 + 1)[1:],
    ])
    assert len(lower) == N1, len(lower)
    # wheel arch: lift the underside near the side
    if arch is not None:
        ay, aw = arch
        for k in range(N1):
            x, y = lower[k]
            if x > hwb - aw and y < ay:
                lower[k, 1] = ay
    # upper: belt -> roof centre
    cab = ry - by
    if cab < 0.03:
        crown = 0.025 + 0.03 * hwb
        upper = np.vstack([
            np.array([hwb, by]),
            bezier(np.array([hwb, by]), np.array([hwb - 0.05, by + crown * 0.9]), np.array([hwb * 0.5, by + crown]),
                   np.array([0, by + crown]), N2 - 1),
        ])
    else:
        hws = hwb - 0.06
        hwr = max(0.25, hwb - tumble * cab)
        shoulder = np.array([hws, by + 0.04])
        top_side = np.array([hwr, ry - 0.10])
        roof_c = np.array([0.0, ry])
        n_glass = N2 - 5
        upper = np.vstack([
            np.array([hwb, by]),
            np.linspace(np.array([hwb, by]), shoulder, 3)[1:],
            np.linspace(shoulder, top_side, n_glass + 1)[1:],
            bezier(top_side, np.array([hwr, ry - 0.02]), np.array([hwr * 0.6, ry]), roof_c, 3)[1:],
        ])
    assert len(upper) == N2, len(upper)
    glass_mask = np.zeros(N2, dtype=bool)
    if cab >= 0.03:
        glass_mask[3:N2 - 3] = True
    return lower, upper, glass_mask


def build_body(b: Builder, spec):
    L, W = spec['L'], spec['W']
    wr = spec['wheel_r']
    u = np.linspace(0, 1, NU)
    fy = curve(spec['floor'], u)
    by = curve(spec['belt'], u)
    ry = np.maximum(curve(spec['roof'], u), by)
    hw = curve(spec['hw'], u) * (W / 2) / max(k[1] for k in spec['hw'])
    z = -L / 2 + u * L  # front at -L/2
    wheel_z = [-L / 2 + spec['wheels'][0] * L, -L / 2 + spec['wheels'][1] * L]
    arch_R = wr + 0.10

    rings = []
    glass_rows = []
    for i in range(NU):
        arch = None
        for wz in wheel_z:
            dz = z[i] - wz
            if abs(dz) < arch_R:
                ay = wr + math.sqrt(arch_R ** 2 - dz ** 2) + 0.04
                ay = min(ay, by[i] - 0.05)
                arch = (ay, 0.45)
        lower, upper, gm = half_section(fy[i], by[i], ry[i], hw[i], spec['tumble'], arch)
        right = np.vstack([lower, upper])  # N1+N2 points, x >= 0
        left = right[::-1].copy()
        left[:, 0] *= -1
        ring = np.vstack([right, left[1:-1]])  # closed ring, 2*(N1+N2)-2
        rings.append(np.column_stack([ring[:, 0], ring[:, 1], np.full(len(ring), z[i])]))
        gmask_ring = np.concatenate([np.zeros(N1, bool), gm, np.concatenate([np.zeros(N1, bool), gm])[::-1][1:-1]])
        glass_rows.append(gmask_ring)
    R = len(rings[0])
    pos = np.vstack(rings)
    body_idx, glass_idx = [], []
    for i in range(NU - 1):
        gi = in_ranges(u[i], spec['glass']) and in_ranges(u[i + 1], spec['glass'])
        for j in range(R):
            a = i * R + j
            bq = i * R + (j + 1) % R
            c = (i + 1) * R + j
            d = (i + 1) * R + (j + 1) % R
            if np.allclose(pos[a], pos[bq]) and np.allclose(pos[c], pos[d]):
                continue  # crease duplicate
            is_glass = gi and glass_rows[i][j] and glass_rows[i][(j + 1) % R]
            tgt = glass_idx if is_glass else body_idx
            # winding: ring goes bottom->right side->roof->left side (counter-clockwise seen from +Z),
            # z grows towards the rear; (a, bq, c) gives an outward CCW triangle
            tgt.append((a, bq, c))
            tgt.append((bq, d, c))
    # caps
    cap_pos = []
    for i, zc in ((0, z[0]), (NU - 1, z[-1])):
        base = i * R
        centre_i = len(pos) + len(cap_pos)
        cap_pos.append([0.0, (fy[i] + ry[i]) * 0.5, zc])
        for j in range(R):
            a = base + j
            bq = base + (j + 1) % R
            if i == 0:
                body_idx.append((centre_i, bq, a))
            else:
                body_idx.append((centre_i, a, bq))
    pos = np.vstack([pos, np.array(cap_pos)])
    all_idx = np.array(body_idx + glass_idx, dtype=np.uint32)
    nrm = face_normals_smooth(pos, all_idx)
    # fix winding to outward normals: ring centre
    uv = np.column_stack([pos[:, 2], pos[:, 1]])
    b.prims.append(dict(pos=pos, nrm=nrm, uv=uv, idx=np.array(body_idx, dtype=np.uint32), mat=b.mat('paint')))
    if glass_idx:
        b.prims.append(dict(pos=pos, nrm=nrm, uv=uv, idx=np.array(glass_idx, dtype=np.uint32), mat=b.mat('glass')))
    return dict(z=z, fy=fy, by=by, ry=ry, hw=hw, wheel_z=wheel_z, u=u)


def check_winding(pos, idx):
    """Return fraction of triangles whose normal points away from the local centroid axis."""
    tri = pos[idx]
    n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    c = tri.mean(axis=1)
    c_axis = c.copy()
    c_axis[:, 0] = 0
    c_axis[:, 1] = pos[:, 1].mean()
    out = np.einsum('ij,ij->i', n, c - c_axis)
    return (out > 0).mean()


def add_details(b: Builder, spec, geo):
    L, W = spec['L'], spec['W']
    z, fy, by, ry, hw = geo['z'], geo['fy'], geo['by'], geo['ry'], geo['hw']
    zf, zr = z[0], z[-1]
    kind_extras = spec['extras']

    def at(u):
        i = int(round(u * (NU - 1)))
        return z[i], fy[i], by[i], ry[i], hw[i]

    # headlights
    _, f0, b0, _, h0 = at(0.0)
    lh = max(0.10, (b0 - f0) * 0.22)
    for s in (-1, 1):
        b.box((s * (h0 - 0.30), b0 - lh * 0.9, zf - 0.01), (0.42, lh, 0.06), 'light_front')
        b.box((s * (h0 - 0.30), b0 - lh * 0.9 - 0.02, zf + 0.02), (0.48, lh + 0.06, 0.06), 'trim')
    # grille + bumper + plate
    b.box((0, (f0 + b0) * 0.5 - 0.02, zf - 0.005), (h0 * 1.1, (b0 - f0) * 0.34, 0.05), 'trim')
    b.box((0, f0 + (b0 - f0) * 0.28, zf - 0.02), (0.52, 0.11, 0.02), 'plate')
    # rear lights + bumper + plate
    _, f1, b1, _, h1 = at(1.0)
    rh = max(0.10, (b1 - f1) * 0.20)
    for s in (-1, 1):
        b.box((s * (h1 - 0.33), b1 - rh * 0.9, zr + 0.01), (0.46, rh, 0.06), 'light_rear')
        b.box((s * (h1 - 0.33), b1 - rh * 0.9 - 0.02, zr - 0.02), (0.52, rh + 0.06, 0.06), 'trim')
    b.box((0, f1 + (b1 - f1) * 0.30, zr + 0.01), (h1 * 2 - 0.2, 0.18, 0.05), 'trim')
    b.box((0, f1 + (b1 - f1) * 0.55, zr + 0.02), (0.52, 0.11, 0.02), 'plate')
    # underbody
    fmin = float(fy.min())
    b.box((0, fmin + 0.08, (zf + zr) / 2), (W * 0.9, 0.16, L * 0.92), 'trim')
    # interior: cabin floor, dash, seats (dark)
    g = spec['glass']
    if g:
        u0 = g[0][0]
        u1 = g[-1][1]
        zc0, _, bc0, _, _ = at(u0)
        zc1, _, bc1, _, _ = at(u1)
        cab_by = float(np.max(by))
        b.box((0, cab_by - 0.25, (zc0 + zc1) / 2), (W - 0.3, 0.5, abs(zc1 - zc0)), 'interior')
        b.box((0, cab_by + 0.10, zc0 + 0.55), (W - 0.35, 0.22, 0.6), 'interior')  # dash
        for s in (-1, 1):
            b.box((s * (W / 4 - 0.05), cab_by + 0.22, zc0 + 1.45), (0.5, 0.55, 0.12), 'interior')  # seat backs
    # mirrors
    if 'mirrors' in kind_extras and g:
        zm, _, bm, _, hm = at(g[0][1])
        for s in (-1, 1):
            b.box((s * (hm + 0.12), bm + 0.10, zm), (0.22, 0.12, 0.16), 'paint')
            b.box((s * (hm + 0.12), bm + 0.10, zm + 0.085), (0.20, 0.10, 0.01), 'chrome')
    # exhausts
    ex = {'single_exhaust': [0.5], 'twin_exhaust': [-0.45, 0.45], 'quad_exhaust': [-0.52, -0.36, 0.36, 0.52]}
    for k, xs in ex.items():
        if k in kind_extras:
            for x in xs:
                b.cyl_z((x * (W / 2 - 0.1) / 0.5, fmin + 0.12, zr - 0.02), 0.05, 0.14, 'chrome', seg=12)
    # spoilers / wings
    if 'wing' in kind_extras:
        zw = zr - 0.25
        yw = float(by[-8]) + 0.32
        b.box((0, yw, zw), (W * 0.92, 0.04, 0.34), 'trim')
        for s in (-1, 1):
            b.box((s * W * 0.36, yw - 0.16, zw + 0.04), (0.05, 0.30, 0.22), 'trim')
    if 'lip' in kind_extras:
        b.box((0, float(by[-4]) + 0.04, zr - 0.12), (W * 0.8, 0.04, 0.16), 'paint')
    if 'roof_spoiler' in kind_extras:
        b.box((0, float(ry.max()) - 0.02, zr - 0.18), (W * 0.78, 0.05, 0.28), 'paint')
    if 'diffuser' in kind_extras:
        for x in np.linspace(-0.6, 0.6, 5):
            b.box((x * (W / 2), fmin + 0.12, zr - 0.15), (0.03, 0.18, 0.4), 'trim')
    # off-roader bits
    if 'roof_rack' in kind_extras:
        yr = float(ry.max()) + 0.06
        for s in (-1, 1):
            b.box((s * (W / 2 - 0.18), yr, (zf + zr) / 2 + 0.3), (0.04, 0.05, L * 0.55), 'trim')
        for k in range(5):
            zz = (zf + zr) / 2 + 0.3 - L * 0.26 + k * L * 0.13
            b.box((0, yr, zz), (W - 0.36, 0.035, 0.035), 'trim')
    if 'bullbar' in kind_extras:
        b.box((0, (f0 + b0) * 0.55, zf - 0.12), (W * 0.8, 0.05, 0.05), 'chrome')
        for s in (-1, 1):
            b.box((s * W * 0.4, (f0 + b0) * 0.55 - 0.15, zf - 0.12), (0.05, 0.4, 0.05), 'chrome')
    if 'steps' in kind_extras:
        for s in (-1, 1):
            b.box((s * (W / 2 + 0.05), fmin + 0.05, 0), (0.14, 0.05, L * 0.42), 'trim')
    if 'van_stripe' in kind_extras:
        for s in (-1, 1):
            b.box((s * (W / 2 + 0.005), float(by.max()) + 0.5, 0.3), (0.01, 0.12, L * 0.6), 'trim')


def build_wheel(b: Builder, spec):
    R = spec['wheel_r']
    tw = spec['tyre_w']
    rr = R * spec['rim']
    # tyre (lathe around X, outer face at +x)
    prof = [(-tw / 2, rr - 0.01), (-tw / 2, R - 0.05), (-tw / 2 + 0.04, R - 0.01), (-tw / 2 + 0.07, R),
            (tw / 2 - 0.07, R), (tw / 2 - 0.04, R - 0.01), (tw / 2, R - 0.05), (tw / 2, rr - 0.01)]
    b.lathe_x(prof, 'tyre', seg=56)
    # rim: outer lip -> barrel -> dish -> hub
    rim = [(tw / 2 + 0.005, rr), (tw / 2 + 0.01, rr - 0.02), (tw / 2 - 0.01, rr - 0.045), (tw / 2 - 0.09, rr * 0.5),
           (tw / 2 - 0.09, rr * 0.33), (tw / 2 - 0.05, rr * 0.3), (tw / 2 - 0.05, 0.001)]
    b.lathe_x(rim, 'rim', seg=48)
    # barrel (inner cylinder from dish to inner side; seen from the axle side through the spokes)
    b.lathe_x([(tw / 2 - 0.01, rr - 0.045), (-tw / 2 + 0.01, rr - 0.045), (-tw / 2 + 0.01, rr * 0.5)], 'trim', seg=32,
              inward=True)
    # spokes
    n = spec['spokes']
    r_in, r_out = rr * 0.32, rr - 0.05
    for k in range(n):
        a = 2 * math.pi * k / n
        rc = (r_in + r_out) / 2
        b.box((tw / 2 - 0.06, rc * math.cos(a), rc * math.sin(a)), (0.045, r_out - r_in, max(0.05, rr * 0.22)),
              'rim', rot_x=a)
    # brake disc + calliper
    b.lathe_x([(tw / 2 - 0.16, 0.001), (tw / 2 - 0.16, rr - 0.08), (tw / 2 - 0.13, rr - 0.08), (tw / 2 - 0.13, 0.001)],
              'chrome', seg=32)
    b.box((tw / 2 - 0.145, (rr - 0.12) * 0.7, -(rr - 0.12) * 0.7), (0.05, 0.16, 0.10), 'brake', rot_x=math.radians(45))
    return b.flush('wheel')


def build_car(cid, spec, out_dir):
    b = Builder()
    geo = build_body(b, spec)
    add_details(b, spec, geo)
    body_mesh = b.flush('body')
    wheel_mesh = build_wheel(b, spec)
    tris = sum(b.g.accessors[p['indices']]['count'] // 3 for p in b.g.meshes[body_mesh]['primitives'])
    wheel_tris = sum(b.g.accessors[p['indices']]['count'] // 3 for p in b.g.meshes[wheel_mesh]['primitives'])
    total = tris + wheel_tris * 4
    W = spec['W']
    half_track = W / 2 - spec['tyre_w'] / 2 - 0.02
    y = spec['wheel_r']
    nodes = [b.g.node('body', mesh=body_mesh)]
    for name, x, zz in (('wheel_fr', half_track, geo['wheel_z'][0]), ('wheel_fl', -half_track, geo['wheel_z'][0]),
                        ('wheel_rr', half_track, geo['wheel_z'][1]), ('wheel_rl', -half_track, geo['wheel_z'][1])):
        rot = [0, 1, 0, 0] if x < 0 else None  # left wheels: 180 deg about Y (outer face outward)
        nodes.append(b.g.node(name, mesh=wheel_mesh, translation=(x, y, zz), rotation=rot))
    if 'spare' in spec['extras']:
        nodes.append(b.g.node('spare', mesh=wheel_mesh, translation=(0.55, spec['belt'][-1][1] - 0.15, spec['L'] / 2 + 0.12),
                              rotation=[0, math.sin(math.pi / 4), 0, math.cos(math.pi / 4)]))
    path = os.path.join(out_dir, f'{cid}.glb')
    size = b.g.write(path, root_nodes=nodes)
    print(f'{cid:12s} {total:6d} tris (body {tris}, wheel {wheel_tris} x4)  {size / 1024:.0f} KB')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=OUT)
    ap.add_argument('ids', nargs='*')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for cid, spec in CARS.items():
        if a.ids and cid not in a.ids:
            continue
        build_car(cid, spec, a.out)


if __name__ == '__main__':
    main()
