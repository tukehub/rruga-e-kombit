"""Regression checks for the Tirana racing graph's pedestrian exclusion."""
import unittest
from types import SimpleNamespace

from build_city import Graph
from common import Proj


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


    def test_tunnel_is_routable_only_when_explicitly_selected(self):
        osm = SimpleNamespace(
            nodes={1: (0.0, 0.0, None), 2: (20.0, 0.0, None), 3: (10.0, 30.0, None)},
            ways={
                10: {'nodes': [1, 2], 'tags': {'highway': 'primary', 'tunnel': 'yes'}},
                20: {'nodes': [1, 3, 2], 'tags': {'highway': 'primary'}},
            },
        )
        self.assertEqual(Graph(osm).dijkstra(1, 2, set(), set()), [1, 3, 2])
        self.assertEqual(Graph(osm, race_ways=(10,)).dijkstra(1, 2, set(), set()), [1, 2])


class ProjectionTest(unittest.TestCase):
    def test_compression_shortens_only_the_configured_latitude_band(self):
        projection = Proj(40.0, 19.0, [(40.0, 40.01, 0.5), (39.97, 39.98, 0.75)])
        plain = Proj(40.0, 19.0)
        for coords in [(40.015, 19.002), (40.005, 19.002), (39.975, 19.006), (39.95, 18.99)]:
            restored = projection.to_ll(*projection.to_xz(*coords))
            self.assertAlmostEqual(restored[0], coords[0])
            self.assertAlmostEqual(restored[1], coords[1])
        above = projection.to_xz(40.01, 19.0)[1]
        self.assertAlmostEqual(projection.to_xz(40.0, 19.0)[1] - above,
                               (plain.to_xz(40.0, 19.0)[1] - plain.to_xz(40.01, 19.0)[1]) * 0.5)
        self.assertAlmostEqual(projection.to_xz(39.985, 19.0)[1] - projection.to_xz(39.99, 19.0)[1],
                               plain.to_xz(39.985, 19.0)[1] - plain.to_xz(39.99, 19.0)[1])


if __name__ == '__main__':
    unittest.main()
