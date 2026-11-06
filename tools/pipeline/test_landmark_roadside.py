"""Verify relocated landmark keepouts stay off the road and clear of props."""
import json
import math
import os
import unittest

import numpy as np

from build_city import landmark_clearance_zones, overlaps_landmark_bounds
from cities import CITIES
from common import OUT, Proj


class RoadsideLandmarkTest(unittest.TestCase):
    def test_generated_anchors_match_source_offsets(self):
        city = CITIES['tirane']
        projector = Proj(*city['origin'])
        with open(os.path.join(OUT, 'tirane', 'props.json'), encoding='utf8') as f:
            anchors = {item['id']: item for item in json.load(f)['landmarks']}
        for landmark in city['landmarks']:
            self.assertIn(landmark['id'], anchors)
            x, z = projector.to_xz(*landmark['ll'])
            self.assertAlmostEqual(anchors[landmark['id']]['x'], x + landmark.get('offset_x', 0), delta=0.051)
            self.assertAlmostEqual(anchors[landmark['id']]['z'], z + landmark.get('offset_z', 0), delta=0.051)

    def test_rectangle_overlap_including_footprints_with_no_corner_inside(self):
        zone = [(-2, -2, 2, 2)]
        self.assertTrue(overlaps_landmark_bounds([(-4, -1), (4, 1)], zone))
        self.assertTrue(overlaps_landmark_bounds([(0, 0)], zone))
        self.assertFalse(overlaps_landmark_bounds([(3, 3)], zone))

    def test_tirana_moved_landmarks_keep_road_clear(self):
        city = CITIES['tirane']
        toptani = next(item for item in city['landmarks'] if item['id'] == 'toptani')
        self.assertGreaterEqual(toptani.get('clear_half', (0, 0))[0], 42.5,
                                'protect the full 85 m Toptani facade')
        self.assertGreaterEqual(toptani.get('clear_half', (0, 0))[1], 27.7,
                                'protect the entire Toptani building depth')
        zones = landmark_clearance_zones(city, Proj(*city['origin']))
        # The stadium's conservative axis-aligned scenery keepout is much
        # larger than its actual, rotated octagonal model. Keep that keepout
        # for props/buildings, but measure road clearance against the shell.
        zoned = [x for x in city['landmarks'] if 'clear_half' in x]
        stadium_index = next(i for i, x in enumerate(zoned) if x['id'] == 'air_albania')
        stadium = zoned[stadium_index]
        zones = [zone for i, zone in enumerate(zones) if i != stadium_index]
        sx, sz = Proj(*city['origin']).to_xz(*stadium['ll'])
        angle = math.radians(stadium['yaw'])
        ca, sa = math.cos(angle), math.sin(angle)
        # Keep in sync with outer[] in godot/scripts/world/air_albania_stadium.gd.
        outer = [(-53, -99), (53, -99), (80, -70), (80, 70),
                 (53, 99), (-53, 99), (-80, 70), (-80, -70)]
        def stadium_distance(px, pz):
            # Inverse Godot yaw rotation into the stadium's local XZ plane.
            dx, dz = px - sx, pz - sz
            x, z = ca * dx - sa * dz, sa * dx + ca * dz
            nearest = float('inf')
            signs = []
            for (ax, az), (bx, bz) in zip(outer, outer[1:] + outer[:1]):
                vx, vz = bx - ax, bz - az
                length2 = vx * vx + vz * vz
                t = max(0.0, min(1.0, ((x - ax) * vx + (z - az) * vz) / length2))
                nearest = min(nearest, math.hypot(x - ax - t * vx, z - az - t * vz))
                signs.append(vx * (z - az) - vz * (x - ax))
            return 0.0 if all(v >= 0 for v in signs) or all(v <= 0 for v in signs) else nearest
        with open(os.path.join(OUT, 'tirane', 'track.json'), encoding='utf8') as f:
            points = json.load(f)['pts']
        # Sample every segment at <= 1 m; 4 m beyond the road edge protects the
        # roadside and chase camera as well as the visible landmark footprint.
        for i, (x, _, z) in enumerate(points):
            nx, _, nz = points[(i + 1) % len(points)]
            samples = max(1, math.ceil(math.hypot(nx - x, nz - z)))
            for step in range(samples):
                t = step / samples
                px, pz = x + t * (nx - x), z + t * (nz - z)
                for x0, z0, x1, z1 in zones:
                    dx = max(x0 - px, 0, px - x1)
                    dz = max(z0 - pz, 0, pz - z1)
                    self.assertGreaterEqual(math.hypot(dx, dz), city['half_width'] + 4.0)
                self.assertGreaterEqual(stadium_distance(px, pz), city['half_width'] + 4.0,
                                        'road and chase camera must clear the stadium shell')

    def test_props_and_lamps_clear_of_landmark_footprints(self):
        city = CITIES['tirane']
        zones = landmark_clearance_zones(city, Proj(*city['origin']))
        with open(os.path.join(OUT, 'tirane', 'props.json'), encoding='utf8') as f:
            props = json.load(f)
        for category in ('lamps', 'trees'):
            for item in props[category]:
                self.assertFalse(overlaps_landmark_bounds([(item[0], item[2])], zones))

    def test_pyramid_sightline_excludes_only_configured_tree_points(self):
        city = CITIES['tirane']
        with open(os.path.join(OUT, 'tirane', 'props.json'), encoding='utf8') as f:
            trees = json.load(f)['trees']
        exclusions = city['tree_view_exclusions']
        self.assertEqual(len(exclusions), 3)
        for tree in trees:
            for x, z, radius in exclusions:
                self.assertGreater(math.hypot(tree[0] - x, tree[2] - z), radius)
        for city_id, other in CITIES.items():
            if city_id != 'tirane':
                self.assertNotIn('tree_view_exclusions', other)


if __name__ == '__main__':
    unittest.main()
