"""Regression: open water is the low ground reached from the open sea, never a
road's lowered ground, and its surface stays under every dry cell."""
import unittest
import numpy as np
from water import build_water, track_corridor


class WaterMaskTest(unittest.TestCase):
    def setUp(self):
        self.n, self.cell = 60, 15.0
        self.nm = {'n': self.n, 'cell': self.cell, 'x0': -450.0, 'z0': -450.0}
        h = np.full((self.n, self.n), 3.0, np.float32)
        h[:, :20] = 0.0            # the sea along the west edge
        h[28:32, 20:50] = 0.0      # a road trench at sea height running inland
        h[45, 45] = -1.7           # an enclosed DEM pit
        self.h = h
        self.none = np.zeros((self.n, self.n), bool)

    def test_sea_reached_from_the_edge_and_trench_kept_dry(self):
        roads = self.none.copy()
        roads[28:32, 20:50] = True
        mask, surface = build_water(self.h, self.nm, 0.3, roads, self.none, self.none)
        water = mask >= 128
        self.assertTrue(water[:, :20].all())
        self.assertFalse(water[28:32, 20:50].any())
        self.assertFalse(water[45, 45])
        self.assertLess(surface, 0.3)
        self.assertGreaterEqual(surface, 0.3 - 1.5)

    def test_track_corridor_blocks_water_even_without_a_mapped_road(self):
        pts = [[x, 0.0, 0.0] for x in np.linspace(-450, 0, 40)]
        corridor = track_corridor(pts, 10.0, self.n, -450.0, -450.0, self.cell)
        mask, _ = build_water(self.h, self.nm, 0.3, self.none, self.none, corridor)
        self.assertFalse((mask >= 128)[corridor].any())

    def test_shore_distance_rises_offshore_and_land_counts_down_inland(self):
        mask, _ = build_water(self.h, self.nm, 0.3, self.none, self.none, self.none)
        row = mask[10].astype(int)
        self.assertTrue(all(a >= b for a, b in zip(row[:19], row[1:20])))   # water: farther out is larger
        self.assertTrue(row[20] <= 127 and row[20] > row[25])              # land: nearer the water is larger
        self.assertEqual(int(mask[10, 59]), 0)                              # far inland


if __name__ == '__main__':
    unittest.main()
