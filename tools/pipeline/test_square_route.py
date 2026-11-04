"""Regression checks for the fictional Tirana square racing circuit."""
import json
from pathlib import Path
import unittest

import numpy as np
from build_city import place_tirana_finish
from cities import CITIES
from common import Proj


class SquareRouteTest(unittest.TestCase):
    def test_rebuilding_preserves_finish_on_current_route(self):
        root = Path(__file__).resolve().parents[2]
        track = json.loads((root / 'godot/assets/cities/tirane/track.json').read_text())
        city = CITIES['tirane']
        rotated = place_tirana_finish(track['pts'], city, Proj(*city['origin']))
        self.assertEqual(rotated, track['pts'], 'saved track must agree with pipeline finish placement')

    def test_track_passes_and_circles_monument(self):
        root = Path(__file__).resolve().parents[2]
        city = root / 'godot/assets/cities/tirane'
        track = json.loads((city / 'track.json').read_text())
        props = json.loads((city / 'props.json').read_text())
        monument = next(x for x in props['landmarks'] if x['id'] == 'skanderbeg')
        points = np.asarray(track['pts'], dtype=float)[:, [0, 2]]
        delta = points - [monument['x'], monument['z']]
        distances = np.linalg.norm(delta, axis=1)
        # Leave ample room for the plinth and the 20 m wide racing surface.
        self.assertGreater(distances.min(), track['hw'] + 10.0)
        self.assertLess(distances.min(), 45.0)
        # The finish is inside the square section, so the nearby interval may
        # cross the start of the closed array. Rotate away from the square
        # before measuring the angle travelled around the monument.
        rolled = np.roll(delta, -int(np.argmax(distances)), axis=0)
        nearby = rolled[np.linalg.norm(rolled, axis=1) < 150.0]
        angles = np.unwrap(np.arctan2(nearby[:, 1], nearby[:, 0]))
        self.assertGreater(abs(angles[-1] - angles[0]), np.deg2rad(200.0))

        self.assertLess(distances[0], 65.0, 'finish line must be by the statue')
        closest = int(np.argmin(distances))
        distance_to_closest = np.linalg.norm(np.diff(points[:closest + 1], axis=0), axis=1).sum()
        self.assertGreater(distance_to_closest, 35.0, 'statue should be ahead as drivers approach the finish')
        self.assertLess(distance_to_closest, 50.0, 'finish should remain close to the statue')

        # The six cars occupy up to 31 m behind the line: retain a smooth,
        # non-overlapping grid with room for the two 4 m lane offsets.
        behind = np.r_[points[-7:], points[:2]]
        segments = np.diff(behind, axis=0)
        headings = np.unwrap(np.arctan2(segments[:, 1], segments[:, 0]))
        self.assertLess(np.max(np.abs(np.diff(headings))), np.deg2rad(20.0),
                        'grid should not contain a sharp turn')


if __name__ == '__main__':
    unittest.main()
