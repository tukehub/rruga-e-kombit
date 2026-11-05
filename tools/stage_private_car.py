"""Stage a licensed vehicle locally, encrypted and excluded from public Git.

Usage: python3 tools/stage_private_car.py /absolute/path/to/normalized.glb

The 32-byte key stays in ignored work/ and a generated private Godot script.
Encryption discourages casual extraction; it cannot prevent reverse engineering
of a client that must contain the key. Do not commit or distribute the source.
"""
import argparse
import os
from pathlib import Path
import secrets
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PRIVATE_DIR = ROOT / 'godot/assets/private_car'
KEY_FILE = ROOT / 'work/private_sport.key'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('model', type=Path)
    parser.add_argument('--godot', default=str(ROOT / 'work/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64'))
    args = parser.parse_args()
    source = args.model.resolve(strict=True)
    PRIVATE_DIR.mkdir(parents=True, exist_ok=True)
    KEY_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(KEY_FILE, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        pass
    else:
        with os.fdopen(fd, 'wb') as f:
            f.write(secrets.token_bytes(32))
    key = KEY_FILE.read_bytes()
    if len(key) != 32:
        raise SystemExit('Private key file must contain 32 bytes')
    key_script = PRIVATE_DIR / 'car_key.gd'
    key_script.write_text('extends RefCounted\nstatic func key() -> PackedByteArray:\n\treturn PackedByteArray([' + ','.join(str(x) for x in key) + '])\n')
    os.chmod(key_script, 0o600)
    target = PRIVATE_DIR / 'vortex_sport.bin'
    candidate = PRIVATE_DIR / '.vortex_sport.tmp'
    try:
        subprocess.run([args.godot, '--headless', '--path', str(ROOT / 'godot'),
                        '--script', str(ROOT / 'tools/stage_private_car.gd'), '--',
                        str(source), str(KEY_FILE), str(candidate)], check=True)
        os.chmod(candidate, 0o600)
        os.replace(candidate, target)
    finally:
        candidate.unlink(missing_ok=True)
    print('Encrypted vehicle staged locally; no model or key added to Git.')


if __name__ == '__main__':
    main()
