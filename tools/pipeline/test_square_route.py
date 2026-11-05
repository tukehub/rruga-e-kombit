"""Checks for the requested Tirana circuit and museum-front finish."""
import json
from pathlib import Path
import unittest

import numpy as np
from scipy.spatial import cKDTree
from build_city import place_tirana_finish
from cities import CITIES
from common import Proj


class SquareRouteTest(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[2]
        city_dir = root / 'godot/assets/cities/tirane'
        self.track = json.loads((city_dir / 'track.json').read_text())
        self.props = json.loads((city_dir / 'props.json').read_text())
        self.city = CITIES['tirane']
        self.proj = Proj(*self.city['origin'])
        self.points = np.asarray(self.track['pts'], dtype=float)[:, [0, 2]]

    def test_rebuilding_preserves_museum_finish(self):
        rotated = place_tirana_finish(self.track['pts'], self.city, self.proj)
        self.assertEqual(rotated, self.track['pts'], 'saved track must agree with the rebuild finish')
        museum = next(x for x in self.props['landmarks'] if x['id'] == 'national_museum')
        centre = np.array([museum['x'], museum['z']])
        self.assertLess(np.linalg.norm(self.points[0] - centre), 90.0)
        self.assertGreater(self.points[0, 1], centre[1], 'finish must be on the square side of the museum')
        behind = np.r_[self.points[-7:], self.points[:2]]
        segments = np.diff(behind, axis=0)
        headings = np.unwrap(np.arctan2(segments[:, 1], segments[:, 0]))
        self.assertLess(np.max(np.abs(np.diff(headings))), np.deg2rad(20.0), 'grid must not contain a sharp turn')

    def test_requested_landmark_order(self):
        sequence = [
            ('namazgja', 85), ('downtown_one', 65), ('pyramid', 100),
            ('prime_minister', 95), ('air_albania', 150), ('polytechnic', 65),
            ('cathedral', 70), ('eyes_tirana', 70),
        ]
        indices = []
        for name, radius in sequence:
            lm = next(x for x in self.props['landmarks'] if x['id'] == name)
            distance = np.linalg.norm(self.points - [lm['x'], lm['z']], axis=1)
            indices.append(int(distance.argmin()))
            self.assertLess(float(distance.min()), radius, name + ' must be visible from the circuit')
        self.assertEqual(indices, sorted(indices), 'landmarks should appear in the requested driving order')
        blloku = np.array(self.proj.to_xz(41.32084, 19.81822))
        distance = np.linalg.norm(self.points - blloku, axis=1)
        self.assertLess(distance.min(), 35, 'the return should pass through Blloku')
        self.assertTrue(indices[5] < int(distance.argmin()) < indices[6])
        self.assertGreaterEqual(len(self.props.get('cafes', [])), 3)

    def test_nonadjacent_course_sections_do_not_overlap(self):
        pairs = cKDTree(self.points).query_pairs(22.0, output_type='ndarray')
        if len(pairs):
            step_difference = np.abs(pairs[:, 0] - pairs[:, 1])
            separation = np.minimum(step_difference, len(self.points) - step_difference)
            self.assertFalse(np.any(separation > 12), 'distant course sections need room for both barriers')


if __name__ == '__main__':
    unittest.main()
