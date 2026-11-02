"""Regression checks for the Tirana racing graph's pedestrian exclusion."""
import unittest
from types import SimpleNamespace

from build_city import Graph


class GraphRoutingTest(unittest.TestCase):
    def test_pedestrian_shortcut_is_excluded_only_when_requested(self):
        osm = SimpleNamespace(
            nodes={1: (0.0, 0.0, None), 2: (1.0, 0.0, None),
                   3: (2.0, 0.0, None), 4: (1.0, 2.0, None)},
            ways={
                10: {'nodes': [1, 2, 3], 'tags': {'highway': 'pedestrian'}},
                20: {'nodes': [1, 4, 3], 'tags': {'highway': 'residential'}},
            },
        )
        open_graph = Graph(osm)
        road_graph = Graph(osm, exclude_pedestrian=True)
        self.assertEqual(open_graph.dijkstra(1, 3, set(), set()), [1, 2, 3])
        self.assertEqual(road_graph.dijkstra(1, 3, set(), set()), [1, 4, 3])
        self.assertFalse(any(kind == 'pedestrian' for edges in road_graph.adj.values()
                             for _, _, kind in edges))


if __name__ == '__main__':
    unittest.main()
