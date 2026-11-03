"""Regression for the folded roadway after Tirana's long straight."""
import json
from pathlib import Path
import unittest
import numpy as np


class TiranaJogTest(unittest.TestCase):
    def test_race_road_has_no_foldover_at_old_jog(self):
        root = Path(__file__).resolve().parents[2]
        data = json.loads((root / 'godot/assets/cities/tirane/track.json').read_text())
        points = np.asarray(data['pts'], dtype=float)[:, [0, 2]]
        tangent = np.roll(points, -1, axis=0) - np.roll(points, 1, axis=0)
        tangent /= np.linalg.norm(tangent, axis=1)[:, None]
        normal = np.column_stack((-tangent[:, 1], tangent[:, 0]))
        left = points - data['hw'] * normal
        right = points + data['hw'] * normal
        def cross(a, b):
            return a[0] * b[1] - a[1] * b[0]
        checked = 0
        for i, point in enumerate(points):
            if np.linalg.norm(point - [-224, -80]) > 90:
                continue
            j = (i + 1) % len(points)
            a, b, c, d = left[i], left[j], right[j], right[i]
            self.assertGreater(cross(b - a, c - a), 0)
            self.assertGreater(cross(c - a, d - a), 0)
            checked += 1
        self.assertGreater(checked, 5)


if __name__ == '__main__':
    unittest.main()
