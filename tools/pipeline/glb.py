"""Minimal binary glTF 2.0 writer (numpy) for static meshes with named nodes.

Each mesh: positions, normals, uv0, optional COLOR_0 (RGBA float), indices (uint32), material index.
Materials are plain PBR metallic-roughness with a base colour; Godot replaces them with project
shaders on import by material name (see godot/scripts/world/*).
"""
import json
import struct

import numpy as np


def _pad4(b, fill=b'\x00'):
    return b + fill * ((4 - len(b) % 4) % 4)


class GLB:
    def __init__(self):
        self.buffers = []  # list of bytes chunks
        self.views = []
        self.accessors = []
        self.materials = []
        self.meshes = []
        self.nodes = []
        self._offset = 0
        self._mat_index = {}

    # -- buffers -----------------------------------------------------------
    def _add_blob(self, arr, target=None):
        b = _pad4(np.ascontiguousarray(arr).tobytes())
        view = {'buffer': 0, 'byteOffset': self._offset, 'byteLength': len(b)}
        if target:
            view['target'] = target
        self.buffers.append(b)
        self._offset += len(b)
        self.views.append(view)
        return len(self.views) - 1

    def _accessor(self, arr, ctype, atype, target, minmax=False):
        arr = np.ascontiguousarray(arr)
        v = self._add_blob(arr, target)
        acc = {'bufferView': v, 'componentType': ctype, 'count': int(arr.shape[0]), 'type': atype}
        if minmax:
            acc['min'] = [float(x) for x in arr.min(axis=0)]
            acc['max'] = [float(x) for x in arr.max(axis=0)]
        self.accessors.append(acc)
        return len(self.accessors) - 1

    # -- materials -----------------------------------------------------------
    def material(self, name, color=(0.8, 0.8, 0.8, 1.0), metallic=0.0, roughness=0.8, emissive=None, double_sided=False):
        if name in self._mat_index:
            return self._mat_index[name]
        m = {
            'name': name,
            'pbrMetallicRoughness': {'baseColorFactor': list(map(float, color)), 'metallicFactor': float(metallic),
                                     'roughnessFactor': float(roughness)},
            'doubleSided': bool(double_sided),
        }
        if emissive:
            m['emissiveFactor'] = list(map(float, emissive))
        self.materials.append(m)
        self._mat_index[name] = len(self.materials) - 1
        return self._mat_index[name]

    # -- meshes --------------------------------------------------------------
    def mesh(self, name, prims):
        """prims: list of dicts {pos (n,3), nrm (n,3), uv (n,2), col (n,4) optional, idx (m,), mat}"""
        out = []
        for p in prims:
            if len(p['idx']) == 0:
                continue
            attrs = {
                'POSITION': self._accessor(p['pos'].astype(np.float32), 5126, 'VEC3', 34962, True),
                'NORMAL': self._accessor(p['nrm'].astype(np.float32), 5126, 'VEC3', 34962),
                'TEXCOORD_0': self._accessor(p['uv'].astype(np.float32), 5126, 'VEC2', 34962),
            }
            if p.get('col') is not None:
                col = np.clip(p['col'], 0, 1)
                attrs['COLOR_0'] = self._accessor((col * 255 + 0.5).astype(np.uint8), 5121, 'VEC4', 34962)
                self.accessors[-1]['normalized'] = True
            if p.get('uv2') is not None:
                attrs['TEXCOORD_1'] = self._accessor(p['uv2'].astype(np.float32), 5126, 'VEC2', 34962)
            idx = self._accessor(p['idx'].reshape(-1).astype(np.uint32), 5125, 'SCALAR', 34963)
            out.append({'attributes': attrs, 'indices': idx, 'material': int(p['mat']), 'mode': 4})
        if not out:
            return None
        self.meshes.append({'name': name, 'primitives': out})
        return len(self.meshes) - 1

    def node(self, name, mesh=None, translation=None, children=None, extras=None, rotation=None, scale=None):
        n = {'name': name}
        if mesh is not None:
            n['mesh'] = mesh
        if translation is not None:
            n['translation'] = [float(x) for x in translation]
        if rotation is not None:
            n['rotation'] = [float(x) for x in rotation]  # quaternion x, y, z, w
        if scale is not None:
            n['scale'] = [float(x) for x in scale]
        if children:
            n['children'] = children
        if extras:
            n['extras'] = extras
        self.nodes.append(n)
        return len(self.nodes) - 1

    def write(self, path, root_nodes=None):
        if root_nodes is None:
            root_nodes = list(range(len(self.nodes)))
        bin_blob = b''.join(self.buffers)
        gltf = {
            'asset': {'version': '2.0', 'generator': 'kafshim-asfalti-pipeline'},
            'scene': 0,
            'scenes': [{'nodes': root_nodes}],
            'nodes': self.nodes,
            'meshes': self.meshes,
            'materials': self.materials,
            'accessors': self.accessors,
            'bufferViews': self.views,
            'buffers': [{'byteLength': len(bin_blob)}],
        }
        js = _pad4(json.dumps(gltf, separators=(',', ':')).encode(), b' ')
        total = 12 + 8 + len(js) + 8 + len(bin_blob)
        with open(path, 'wb') as f:
            f.write(struct.pack('<III', 0x46546C67, 2, total))
            f.write(struct.pack('<II', len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack('<II', len(bin_blob), 0x004E4942))
            f.write(bin_blob)
        return total


# ---------------------------------------------------------------------------
# geometry helpers shared by builders

def face_normals_smooth(pos, idx):
    n = np.zeros_like(pos)
    a, b, c = pos[idx[:, 0]], pos[idx[:, 1]], pos[idx[:, 2]]
    fn = np.cross(b - a, c - a)
    for k in range(3):
        np.add.at(n, idx[:, k], fn)
    ln = np.linalg.norm(n, axis=1)
    ln[ln == 0] = 1
    return n / ln[:, None]


def flat_shade(pos, idx):
    """Split vertices per face and return flat normals."""
    tri = pos[idx.ravel()]
    a, b, c = tri[0::3], tri[1::3], tri[2::3]
    fn = np.cross(b - a, c - a)
    ln = np.linalg.norm(fn, axis=1)
    ln[ln == 0] = 1
    fn = fn / ln[:, None]
    nrm = np.repeat(fn, 3, axis=0)
    return tri, nrm, np.arange(len(tri), dtype=np.uint32).reshape(-1, 3)


def earcut(poly):
    """Ear clipping triangulation of a simple polygon (list of (x, y)). Returns index triples."""
    n = len(poly)
    if n < 3:
        return []
    pts = [(float(x), float(y)) for x, y in poly]
    area = 0.0
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        area += x0 * y1 - x1 * y0
    order = list(range(n))
    if area < 0:
        order.reverse()
    idx = order[:]
    tris = []

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    def inside(p, a, b, c):
        return cross(a, b, p) >= -1e-9 and cross(b, c, p) >= -1e-9 and cross(c, a, p) >= -1e-9

    guard = 0
    while len(idx) > 3 and guard < 10 * n:
        guard += 1
        m = len(idx)
        ear_found = False
        for i in range(m):
            i0, i1, i2 = idx[(i - 1) % m], idx[i], idx[(i + 1) % m]
            a, b, c = pts[i0], pts[i1], pts[i2]
            if cross(a, b, c) <= 1e-9:
                continue
            ok = True
            for j in idx:
                if j in (i0, i1, i2):
                    continue
                if inside(pts[j], a, b, c):
                    ok = False
                    break
            if ok:
                tris.append((i0, i1, i2))
                idx.pop(i)
                ear_found = True
                break
        if not ear_found:
            # degenerate: fan the rest
            break
    if len(idx) >= 3:
        for i in range(1, len(idx) - 1):
            tris.append((idx[0], idx[i], idx[i + 1]))
    return tris
