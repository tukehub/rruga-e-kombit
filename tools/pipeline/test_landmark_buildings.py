"""A custom landmark must replace an OSM relation and its member footprints."""
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from build_city import build_buildings


class LandmarkBuildingTest(unittest.TestCase):
    def test_excludes_relation_and_member_ways(self):
        osm = SimpleNamespace(
            ways={7: {'id': 7, 'nodes': [1, 2, 3, 1], 'tags': {'building': 'yes'}}},
            rels=[{'id': 42, 'tags': {'building': 'cathedral'},
                   'members': [{'type': 'way', 'ref': 7, 'role': 'outer'}]}],
            coords=MagicMock(side_effect=AssertionError('excluded member was processed')),
            rings_of_relation=MagicMock(side_effect=AssertionError('excluded relation was processed')),
        )
        with patch('build_city.GLB') as glb:
            build_buildings(osm, None, 10, None, 'tirana', '/tmp/not-written.glb', [42])
        osm.coords.assert_not_called()
        osm.rings_of_relation.assert_not_called()
        glb.return_value.write.assert_called_once_with('/tmp/not-written.glb', [])


if __name__ == '__main__':
    unittest.main()
