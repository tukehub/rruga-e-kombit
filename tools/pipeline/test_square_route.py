"""Checks for the requested Tirana circuit and museum-front finish."""
import json
from pathlib import Path
import unittest

import numpy as np
from scipy.spatial import cKDTree
from build_city import place_tirana_finish, blloku_building_mask, blloku_building_overlap
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

    def test_blloku_cafes_are_on_both_sides_and_clear_the_road(self):
        cafes = self.props.get('cafes', [])
        self.assertGreaterEqual(len(cafes), 12)
        self.assertLessEqual(len(cafes), 24, 'keep detailed furniture bounded for mobile')
        self.assertGreaterEqual(sum(c[4] < 0 for c in cafes), 6)
        self.assertGreaterEqual(sum(c[4] > 0 for c in cafes), 6)
        nearest = cKDTree(self.points)
        buildings = blloku_building_mask(Path(__file__).resolve().parents[2] / 'godot/assets/cities/tirane/buildings.glb')
        polytechnic = next(l for l in self.props['landmarks'] if l['id'] == 'polytechnic')
        cathedral = next(l for l in self.props['landmarks'] if l['id'] == 'cathedral')
        poly_index = nearest.query([polytechnic['x'], polytechnic['z']])[1]
        cathedral_index = nearest.query([cathedral['x'], cathedral['z']])[1]
        for x, _ground, z, yaw, _side, _road in cafes:
            tangent = np.array([np.cos(yaw), -np.sin(yaw)])
            normal = np.array([np.sin(yaw), np.cos(yaw)])
            corners = [[x, z] + dx * tangent + dz * normal
                       for dx in (-2.8, 2.8) for dz in (-1.55, 1.55)]
            self.assertGreater(float(nearest.query(corners)[0].min()), self.track['hw'] + 1.8)
            self.assertFalse(blloku_building_overlap(corners, buildings), 'café must not overlap existing building walls')
            index = nearest.query([x, z])[1]
            self.assertTrue(poly_index < index < cathedral_index, 'café must be on the return leg')

    def test_cafe_building_mask_handles_overlaps_and_touching_edges(self):
        building = np.array([[0., 0.], [4., 0.], [4., 4.], [0., 4.]])
        walls = (np.tile(building, (2, 1)), np.tile(np.roll(building, -1, axis=0), (2, 1)))
        inside = np.array([[1., 1.], [1., 2.], [2., 1.], [2., 2.]])
        touching = np.array([[4., 1.], [4., 2.], [5., 1.], [5., 2.]])
        outside = np.array([[6., 1.], [6., 2.], [7., 1.], [7., 2.]])
        self.assertTrue(blloku_building_overlap(inside, walls))
        self.assertTrue(blloku_building_overlap(touching, walls))
        self.assertFalse(blloku_building_overlap(outside, walls))


if __name__ == '__main__':
    unittest.main()
