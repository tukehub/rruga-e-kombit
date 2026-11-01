"""Fail on Godot runtime errors as well as failed assertions (Godot can exit zero on errors)."""
import argparse
from pathlib import Path
import subprocess
import sys
ap = argparse.ArgumentParser()
ap.add_argument('--godot', default='godot')
args = ap.parse_args()
root = Path(__file__).resolve().parents[1]
for scene in ['readiness', 'flow_test']:
    try:
        run = subprocess.run([args.godot, '--headless', '--path', str(root / 'godot'),
                              'res://tests/' + scene + '.tscn'], stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, timeout=240)
    except subprocess.TimeoutExpired:
        sys.exit(f'{scene} timed out')
    print(run.stdout)
    if run.returncode or any(s in run.stdout for s in ['SCRIPT ERROR:', 'ERROR:', 'CHECK FAILED']):
        sys.exit(f'{scene} failed')
