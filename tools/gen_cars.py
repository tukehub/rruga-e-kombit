"""Generate Vortex's one shared modern fastback, with paint swapped per driver.

Body and four wheel nodes are separate so steering/spin and brake lamps animate.
Smooth loft surfaces, flush glazing, LED bars and rounded mirrors are original
procedural geometry. Forward=-Z, ground contact y=0. Run python tools/gen_cars.py.
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

NU = 180   # stations along the body
N1 = 20    # points lower half-section (bottom centre -> belt)
N2 = 26    # points upper half-section (belt -> roof centre)

# u: 0 = front, 1 = rear. All heights in metres (ground = 0).
CARS = {
    'vortex_gt': dict(
        L=4.62, W=1.94, wheel_r=0.36, tyre_w=0.27, spokes=10, rim=0.73, tumble=0.68,
        floor=[(0, .28), (.07, .21), (.45, .19), (.90, .22), (1, .30)],
        belt=[(0, .63), (.035, .71), (.18, .80), (.36, .85), (.60, .88), (.82, .88), (1, .82)],
        roof=[(0, .63), (.035, .71), (.22, .81), (.30, .88), (.36, 1.10), (.43, 1.31),
              (.51, 1.38), (.62, 1.37), (.72, 1.29), (.82, 1.08), (.92, .91), (1, .82)],
        hw=[(0, .74), (.035, .86), (.13, .95), (.27, .97), (.52, .955), (.78, .97), (.94, .91), (1, .83)],
        glass=[(.315, .555), (.578, .795), (.80, .88)],
        wheels=(.18, .81), extras=['modern']),
}

MATS = {
    'paint': dict(color=(0.55, 0.62, 0.72, 1), metallic=0.35, roughness=0.24),
    'glass': dict(color=(0.12, 0.20, 0.28, 1), metallic=0.12, roughness=0.10),
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
        n_glass = N2 - 9
        upper = np.vstack([
            np.array([hwb, by]),
            np.linspace(np.array([hwb, by]), shoulder, 3)[1:],
            bezier(shoulder, shoulder + np.array([-0.015, cab * 0.38]),
                   top_side + np.array([0.07, -cab * 0.20]), top_side, n_glass + 1)[1:],
            bezier(top_side, np.array([hwr, ry - 0.02]), np.array([hwr * 0.6, ry]), roof_c, 7)[1:],
        ])
    assert len(upper) == N2, len(upper)
    glass_mask = np.zeros(N2, dtype=bool)
    if cab >= 0.03:
        glass_mask[3:N2 - 6] = True
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
        # Rounded plan-view corners keep the bumper from reading as a box.
        zz = np.full(len(ring), z[i])
        front_round = max(0.0, 1.0 - u[i] / .10) ** 2
        rear_round = max(0.0, 1.0 - (1.0 - u[i]) / .10) ** 2
        zz += (.12 * front_round - .10 * rear_round) * (ring[:, 0] / hw[i]) ** 2
        rings.append(np.column_stack([ring[:, 0], ring[:, 1], zz]))
        if .315 <= u[i] <= .425 or .795 <= u[i] <= .88:
            gm[3:] = True
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


def ellipsoid(b, center, radii, mat, rings=12, segments=28):
    """Smooth rounded detail rather than a visibly block-shaped mirror or lamp."""
    pos = []
    for i in range(rings + 1):
        phi = math.pi * i / rings
        for j in range(segments):
            theta = 2 * math.pi * j / segments
            pos.append([math.sin(phi) * math.cos(theta), math.cos(phi), math.sin(phi) * math.sin(theta)])
    unit = np.array(pos)
    pos = unit * np.array(radii) + np.array(center)
    normals = unit / np.array(radii)
    normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-8)
    idx = []
    for i in range(rings):
        for j in range(segments):
            a = i * segments + j
            d = i * segments + (j + 1) % segments
            c = (i + 1) * segments + j
            e = (i + 1) * segments + (j + 1) % segments
            idx.extend([(a, d, c), (d, e, c)])
    b.add_tris(pos, idx, mat, nrm=normals)


def light_ribbon(b, points, height, depth, mat):
    """A continuous thin LED ribbon following the nose or rear quarter curve."""
    for p, q in zip(points, points[1:]):
        delta = np.array(q) - np.array(p)
        length = float(np.hypot(delta[0], delta[2]))
        center = (np.array(p) + np.array(q)) / 2
        # The box length is along X; rotation about Y follows the curved bumper.
        b.box(center, (length + .004, height, depth), mat, rot_y=-math.atan2(delta[2], delta[0]))


def add_modern_details(b, spec, geo):
    """Original 2020s fastback treatment: thin LEDs, deep grille and flush handles."""
    L, W = spec['L'], spec['W']
    front, rear = -L / 2, L / 2
    # Slim connected white DRL, then thicker outboard lamp capsules beneath it.
    xs = np.linspace(-.70, .70, 25)
    nose = [[x, .585 + .018 * (1 - (x / .70) ** 2), front - .023 + .12 * (x / .74) ** 2] for x in xs]
    light_ribbon(b, nose, .025, .027, 'light_front')
    for side in [-1, 1]:
        ellipsoid(b, (side * .575, .545, front + .048), (.15, .038, .037), 'light_front', rings=8, segments=24)
        # Vertical end signature in the bumper, visible from a three-quarter angle.
        b.box((side * .725, .505, front + .086), (.026, .125, .032), 'light_front')
    # One low grille with close-spaced vanes and a clean body-color bumper beam.
    b.box((0, .385, front - .007), (1.32, .145, .032), 'trim')
    for x in np.linspace(-.59, .59, 20):
        b.box((x, .385, front - .028), (.012, .095, .008), 'chrome')
    b.box((0, .254, front + .055), (1.55, .034, .15), 'trim')
    b.box((0, .390, front - .040), (.40, .092, .014), 'plate')
    # Continuous red rear light blade above the diffuser; a second brake signature.
    xs = np.linspace(-.79, .79, 30)
    tail = [[x, .744 + .025 * (1 - (x / .79) ** 2), rear + .019 - .10 * (x / .83) ** 2] for x in xs]
    light_ribbon(b, tail, .036, .025, 'light_rear')
    for side in [-1, 1]:
        b.box((side * .725, .686, rear - .060), (.13, .022, .025), 'light_rear')
        b.box((side * .91, .300, .10), (.035, .075, 1.68), 'trim')
    b.box((0, .385, rear + .010), (1.52, .14, .065), 'trim')
    b.box((0, .499, rear + .028), (.40, .092, .015), 'plate')
    for x in [-.50, -.25, 0, .25, .50]:
        b.box((x, .323, rear - .08), (.022, .13, .27), 'trim')
    # An integrated, understated ducktail rather than a tall racing wing.
    ellipsoid(b, (0, .888, rear - .13), (.75, .026, .085), 'paint', rings=8, segments=40)
    # Rounded wing mirrors and narrow metallic stems.
    for side in [-1, 1]:
        b.box((side * .955, .926, -.28), (.18, .034, .048), 'trim', rot_y=side * .18)
        ellipsoid(b, (side * 1.035, .954, -.25), (.125, .060, .125), 'paint')
        ellipsoid(b, (side * 1.035, .955, -.145), (.099, .042, .015), 'chrome', rings=8, segments=24)
        # Flush handle cartridges against the side surface, no protruding blocks.
        for u in [.49, .65]:
            z = -L / 2 + u * L
            belt = float(curve(spec['belt'], u))
            hw = float(curve(spec['hw'], u))
            b.box((side * (hw + .003), belt - .075, z), (.012, .025, .16), 'chrome')
    # Underside hidden inside the body; no floating chassis rectangle at the sides.
    b.box((0, .26, 0), (1.26, .13, 3.50), 'trim')


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
    add_modern_details(b, spec, geo)
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
