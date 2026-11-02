"""Terrain-following OSM side-road ribbons, grouped into spatial GLB chunks."""
import math
import numpy as np
from glb import GLB
from cities import ROAD_WIDTH


def _clear_of_track(ref, midpoint, segment_length, road_half_width, track_half_width):
    """Keep the whole side-road quad, not just its midpoint, outside the track.

    The track index samples every 2m, so add 1m for its sampling error. The
    circumradius bounds every point of the rectangular 8m road segment.
    """
    radius = math.hypot(segment_length / 2.0, road_half_width)
    return ref.nearest(*midpoint)[0] >= track_half_width + 2.0 + radius + 1.0


def build_side_roads(osm, ref, half_width, height, path):
    chunks = {}
    for way in osm.ways.values():
        road_type = way.get('tags', {}).get('highway')
        if road_type not in ROAD_WIDTH:
            continue
        points = osm.coords(way)
        for a, b in zip(points, points[1:]):
            a, b = np.asarray(a, float), np.asarray(b, float)
            length = np.linalg.norm(b - a)
            if length < 0.1:
                continue
            normal = np.array([-(b - a)[1], (b - a)[0]]) / length
            steps = max(1, math.ceil(length / 8.0))
            for step in range(steps):
                start, end = a + (b - a) * step / steps, a + (b - a) * (step + 1) / steps
                mid = (start + end) / 2
                # Avoid side-road quads bridging over the detailed racing ribbon.
                width = float(ROAD_WIDTH[road_type]) / 2
                if not _clear_of_track(ref, mid, float(np.linalg.norm(end - start)), width, half_width) or np.linalg.norm(mid) > 2600:
                    continue
                key = tuple(np.floor(mid / 250).astype(int))
                quads = chunks.setdefault(key, [])
                quad = [start - normal * width, start + normal * width,
                        end + normal * width, end - normal * width]
                quads.append([[x, float(height(x, z)) + 0.08, z] for x, z in quad])
    glb = GLB()
    mat = glb.material('side_road', (0.14, 0.15, 0.17, 1), roughness=0.8)
    for (cx, cz), quads in sorted(chunks.items()):
        center = np.array([(cx + 0.5) * 250, 0, (cz + 0.5) * 250])
        pos = np.asarray(quads).reshape(-1, 3) - center
        idx = np.array([[i, i + 1, i + 2, i, i + 2, i + 3] for i in range(0, len(pos), 4)]).ravel()
        # Flat normals are adequate for 8m segments; elevations retain the DEM slope.
        nrm = np.tile([0, 1, 0], (len(pos), 1))
        uv = pos[:, [0, 2]] / 4
        mesh = glb.mesh(f'road_{cx}_{cz}', [dict(pos=pos, nrm=nrm, uv=uv, idx=idx, mat=mat)])
        glb.node(f'road_{cx}_{cz}', mesh=mesh, translation=center)
    glb.write(path)
    return len(chunks)
