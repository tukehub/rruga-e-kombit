"""Regression: a coarse hillside must stay beneath both edges of a turning road."""
import unittest
import numpy as np
from build_city import TrackRef, conform_terrain, sample_grid


class TerrainClearanceTest(unittest.TestCase):
    def test_sloped_loop_clears_grid_corners_without_raising_terrain(self):
        cell, origin, width = 15.0, -300.0, 10.0
        angle = np.linspace(0, 2 * np.pi, 800, endpoint=False)
        xz = np.column_stack([120 * np.cos(angle), 75 * np.sin(angle)])
        road_y = 40 + 8 * np.sin(angle)
        ref = TrackRef(xz, road_y)
        x, z = np.meshgrid(origin + np.arange(41) * cell,
                           origin + np.arange(41) * cell)
        dem = (50 + 0.2 * x + 0.1 * z).astype(np.float32)
        before = dem.copy()
        carved = conform_terrain(dem, origin, origin, cell, ref, width)
        for offset in [-width, -width / 2, 0, width / 2, width]:
            points = xz + ref.nrm * offset
            ground = sample_grid(carved, origin, origin, cell, points[:, 0], points[:, 1])
            self.assertLess(float(np.max(ground - road_y)), 0)
        np.testing.assert_array_less(carved, before + 0.001)
        np.testing.assert_array_equal(carved[[0, -1], :], before[[0, -1], :])


if __name__ == '__main__':
    unittest.main()
