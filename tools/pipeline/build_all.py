"""Fetch and build real OSM/Copernicus data, then validate each selected city.
No synthetic replacements are made when the network or a source fails.
"""
import argparse
from pathlib import Path
import subprocess
import sys
from cities import CITIES
from common import ROOT
from fetch_osm import fetch
from fetch_dem import main as fetch_dem
from build_city import build


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cities', nargs='*', choices=list(CITIES))
    args = ap.parse_args()
    for cid in args.cities or list(CITIES):
        fetch(cid)
        fetch_dem([cid])
        build(cid)
        subprocess.run([sys.executable, str(Path(ROOT) / 'tools/check_terrain.py'), cid], cwd=ROOT, check=True)

if __name__ == '__main__':
    main()
