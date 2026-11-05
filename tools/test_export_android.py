"""Checks that private-car builds cannot silently ship the fallback model."""
from pathlib import Path
import tempfile
import unittest

from export_android import validate_private_car


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


if __name__ == '__main__':
    unittest.main()
