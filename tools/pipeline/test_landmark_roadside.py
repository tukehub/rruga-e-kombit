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
        zones = landmark_clearance_zones(city, Proj(*city['origin']))
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

    def test_props_and_lamps_clear_of_landmark_footprints(self):
        city = CITIES['tirane']
        zones = landmark_clearance_zones(city, Proj(*city['origin']))
        with open(os.path.join(OUT, 'tirane', 'props.json'), encoding='utf8') as f:
            props = json.load(f)
        for category in ('lamps', 'trees'):
            for item in props[category]:
                self.assertFalse(overlaps_landmark_bounds([(item[0], item[2])], zones))


if __name__ == '__main__':
    unittest.main()
