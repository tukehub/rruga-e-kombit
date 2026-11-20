"""Regression: the seafront finds the sea's side from the water mask, raises
only untagged land-side blocks on the stretch, and keeps palms dry and off
the road."""
import unittest
import numpy as np
from build_city import TrackRef, rnd
import seafront


class SeafrontTest(unittest.TestCase):
    def setUp(self):
        # A straight 600 m road along x at z = 0; the sea starts at z = +60.
        x = np.arange(-300.0, 300.0, 2.0)
        self.ref = TrackRef(np.column_stack([x, np.zeros_like(x)]), np.full_like(x, 2.0))
        self.nm = {'n': 81, 'cell': 15.0, 'x0': -600.0, 'z0': -600.0}
        zs = self.nm['z0'] + np.arange(81) * 15.0
        self.mask = np.where(zs[:, None] >= 60.0, 200, 40).astype(np.uint8).repeat(81, axis=1)
        self.idx = list(range(50, 250))
        self.side = seafront.sea_side(self.ref, 10.0, self.idx, self.mask, self.nm)

    def test_sea_side_points_at_the_water(self):
        i = self.idx[0]
        p = self.ref.xz[i] + self.side * 80.0 * self.ref.nrm[i]
        self.assertTrue(seafront.is_water(self.mask, self.nm, *p))

    def test_only_untagged_land_side_blocks_rise(self):
        fn = seafront.frontage_height({'levels': (10, 15), 'frontage': 140}, self.idx, self.side, rnd)
        inland = -self.side * self.ref.nrm[100][1] * 50.0
        h = fn(self.ref, 1, {'building': 'apartments'}, 0.0, inland)
        self.assertTrue(10 * 3.1 + 1.0 <= h <= 15 * 3.1 + 1.0)
        self.assertIsNone(fn(self.ref, 1, {'building': 'yes', 'building:levels': '4'}, 0.0, inland))
        self.assertIsNone(fn(self.ref, 1, {'building': 'yes'}, 0.0, -inland))      # sea side
        self.assertIsNone(fn(self.ref, 1, {'building': 'yes'}, 280.0, inland))     # beyond the stretch

    def test_palms_are_dry_and_clear_of_the_road(self):
        sample = lambda xs, zs: np.full(len(xs), 1.5)
        palms = seafront.palms(self.ref, 10.0, self.idx, self.side, self.mask, self.nm, sample, -1.2, rnd)
        self.assertGreater(len(palms), 15)
        for x, y, z, s, yaw in palms:
            self.assertFalse(seafront.is_water(self.mask, self.nm, x, z))
            self.assertGreaterEqual(self.ref.nearest(x, z)[0], 14.0)


if __name__ == '__main__':
    unittest.main()
