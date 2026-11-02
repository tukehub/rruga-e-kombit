"""Keep all corners of side-road quads clear of the racing carriageway."""
import unittest
from side_roads import _clear_of_track


class StraightTrack:
    def nearest(self, x, z):
        return abs(z), 0


class SideRoadClearanceTest(unittest.TestCase):
    def test_wide_road_can_overlap_even_when_its_midpoint_is_clear(self):
        # Old midpoint-only check accepted z=14 even though the road extends
        # 5 metres towards the carriageway at z=0.
        self.assertFalse(_clear_of_track(StraightTrack(), (0, 14), 8, 5, 10))
        self.assertTrue(_clear_of_track(StraightTrack(), (0, 24), 8, 5, 10))


if __name__ == '__main__':
    unittest.main()
