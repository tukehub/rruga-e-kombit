"""Checks that private-car builds cannot silently ship the fallback model."""
from pathlib import Path
import tempfile
import unittest

from export_android import RENDERERS, launch_args, validate_private_car


class PrivateCarExportTest(unittest.TestCase):
    def test_private_export_rejects_missing_or_unencrypted_payload(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaises(SystemExit):
                validate_private_car(root)
            (root / 'car_key.gd').write_text('test fixture', encoding='utf8')
            (root / 'vortex_sport.bin').write_bytes(b'glTF')
            with self.assertRaises(SystemExit):
                validate_private_car(root)
            (root / 'vortex_sport.bin').write_bytes(b'GDEC fixture')
            validate_private_car(root)


class LaunchArgsTest(unittest.TestCase):
    def test_distribution_build_has_no_extra_arguments(self):
        self.assertEqual(launch_args(), '')

    def test_profile_options_are_bare_and_follow_engine_options(self):
        """Godot appends engine flags after these, so a "--" separator would hide them."""
        self.assertEqual(launch_args(60, 'medium'), '--scene=race --auto --quality=medium --benchmark=60')
        for renderer in RENDERERS:
            tokens = launch_args(60, 'high', renderer).split()
            self.assertEqual(tokens[:2], ['--rendering-method', renderer])
            self.assertNotIn('--', tokens)
            self.assertIn('--benchmark=60', tokens)


if __name__ == '__main__':
    unittest.main()
