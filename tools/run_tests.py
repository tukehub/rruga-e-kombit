"""Fail on Godot runtime errors as well as failed assertions (Godot can exit zero on errors)."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from export_android import RENDERERS, launch_args

ap = argparse.ArgumentParser()
ap.add_argument('--godot', default='godot')
args = ap.parse_args()
root = Path(__file__).resolve().parents[1]


def godot(name, *arguments, expected_noise=()):
    try:
        run = subprocess.run([args.godot, '--headless', '--path', str(root / 'godot'), *arguments],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=240)
    except subprocess.TimeoutExpired:
        sys.exit(f'{name} timed out')
    print(run.stdout)
    lines = [line for line in run.stdout.splitlines() if not any(noise in line for noise in expected_noise)]
    if run.returncode or any(s in line for line in lines for s in ['SCRIPT ERROR:', 'ERROR:', 'CHECK FAILED']):
        sys.exit(f'{name} failed')
    return run.stdout


for scene in ['readiness', 'city_worlds', 'flow_test', 'wall_contact', 'driving_dynamics', 'road_geometry', 'lana_river', 'simulation_timing', 'reverse_race', 'car_visual_regression', 'tirana_turns', 'adaptive_pickups', 'two_thumb_controls', 'combat_recovery', 'combat_ui', 'visual_performance', 'route_readability', 'string_table']:
    godot(scene, 'res://tests/' + scene + '.tscn')

# Phones run the Mobile renderer and desktop Forward+. Headless Godot keeps the
# requested method's name, so both shipped paths are checked on any machine.
for renderer in RENDERERS:
    godot(f'renderer_truth on {renderer}', '--rendering-method', renderer,
          'res://tests/renderer_truth.tscn', '--', '--expect-renderer=' + renderer)
    # The command line a profile APK bakes in must reach the benchmark, and the
    # PROFILE report must say which renderer ran and what it was asked to draw.
    # Quitting mid-race leaves loaded resources behind; only that notice is expected.
    output = godot(f'profile launch on {renderer}', *launch_args(1, 'high', renderer).split(),
                   expected_noise=['resources still in use at exit'])
    reports = [json.loads(line[len('PROFILE: '):]) for line in output.splitlines() if line.startswith('PROFILE: ')]
    forward = renderer == 'forward_plus'
    if len(reports) != 1:
        sys.exit(f'profile launch on {renderer} printed {len(reports)} PROFILE reports')
    budget = reports[0]['render_budget']
    if reports[0]['renderer'] != renderer or budget['renderer'] != renderer or reports[0]['quality'] != 'high':
        sys.exit(f'profile launch on {renderer} reported another renderer or quality')
    if budget['ssao'] != forward or budget['sdfgi'] != forward:
        sys.exit(f'profile launch on {renderer} reported effects that renderer cannot draw')
