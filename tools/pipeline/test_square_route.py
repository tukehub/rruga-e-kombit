"""Regression checks for the fictional Tirana square racing circuit."""
import json
from pathlib import Path
import unittest

import numpy as np


class SquareRouteTest(unittest.TestCase):
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
        nearby = delta[distances < 150.0]
        angles = np.unwrap(np.arctan2(nearby[:, 1], nearby[:, 0]))
        self.assertGreater(abs(angles[-1] - angles[0]), np.deg2rad(200.0))


if __name__ == '__main__':
    unittest.main()
