"""Download CC0 assets from Poly Haven into the Godot project.

    python tools/fetch_assets.py            # textures + hdris
    python tools/fetch_assets.py --hdri     # only hdris

Textures are 1k JPG (diffuse / normal / rough), HDRIs 2k HDR. Everything is
CC0 (https://polyhaven.com/license). Assets are cached under tools/cache.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "tools", "cache", "polyhaven")
TEX_OUT = os.path.join(ROOT, "godot", "assets", "textures")
HDRI_OUT = os.path.join(ROOT, "godot", "assets", "hdri")
UA = {"User-Agent": "vortex-build/1.0 (github.com/tukehub/rruga-e-kombit)"}

TEXTURES = {
    # slug: short name used by shaders
    "asphalt_02": "asphalt",
    "aerial_grass_rock": "grass",
    "rocky_terrain_02": "rock",
    "concrete_floor_02": "concrete",
    "cobblestone_floor_08": "cobble",
    "brick_wall_02": "brick",
    "plaster_brick_pattern": "plaster",
    "roof_tiles_14": "rooftiles",
    "concrete_wall_008": "concrete_wall",
    "asphalt_04": "asphalt_wet",
}
TEX_MAPS = {"Diffuse": "diff", "nor_gl": "nor", "Rough": "rough"}

HDRIS = {
    "kloppenheim_06_puresky": "sky_day",
    "belfast_sunset_puresky": "sky_sunset",
    "dikhololo_night": "sky_night",
    "kiara_1_dawn": "sky_dawn",
    "industrial_sunset_puresky": "sky_dusk",
    "qwantani_dusk_2_puresky": "sky_golden",
    "kloofendal_overcast_puresky": "sky_overcast",
}


def fetch(url: str, dst: str) -> None:
    if os.path.exists(dst) and os.path.getsize(dst) > 0:
        return
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    print("  GET", url)
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r, open(dst + ".part", "wb") as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    os.replace(dst + ".part", dst)


def files_json(slug: str) -> dict:
    dst = os.path.join(CACHE, slug + ".json")
    fetch(f"https://api.polyhaven.com/files/{slug}", dst)
    with open(dst, encoding="utf-8") as f:
        return json.load(f)


def pick(d: dict, keys: list[str]):
    for k in keys:
        if k in d:
            return d[k]
    return None


def fetch_textures() -> None:
    os.makedirs(TEX_OUT, exist_ok=True)
    for slug, short in TEXTURES.items():
        print(slug)
        info = files_json(slug)
        for map_key, suffix in TEX_MAPS.items():
            maps = pick(info, [map_key, map_key.lower(), map_key.capitalize()])
            if not maps:
                print("   missing map", map_key)
                continue
            res = pick(maps, ["1k", "2k"])
            if not res:
                continue
            fmt = pick(res, ["jpg", "png"])
            if not fmt:
                continue
            ext = "jpg" if "jpg" in res else "png"
            url = fmt["url"]
            cache = os.path.join(CACHE, f"{slug}_{suffix}_1k.{ext}")
            fetch(url, cache)
            out = os.path.join(TEX_OUT, f"{short}_{suffix}.{ext}")
            if not os.path.exists(out):
                with open(cache, "rb") as s, open(out, "wb") as d:
                    d.write(s.read())


def fetch_hdris() -> None:
    os.makedirs(HDRI_OUT, exist_ok=True)
    for slug, short in HDRIS.items():
        print(slug)
        info = files_json(slug)
        hdri = info.get("hdri", {})
        res = pick(hdri, ["2k", "1k"])
        if not res:
            print("   no hdri entry")
            continue
        fmt = pick(res, ["hdr", "exr"])
        ext = "hdr" if "hdr" in res else "exr"
        cache = os.path.join(CACHE, f"{slug}_2k.{ext}")
        fetch(fmt["url"], cache)
        out = os.path.join(HDRI_OUT, f"{short}.{ext}")
        if not os.path.exists(out):
            with open(cache, "rb") as s, open(out, "wb") as d:
                d.write(s.read())


FONT_OUT = os.path.join(ROOT, "godot", "assets", "fonts")
# SIL Open Font License 1.1 fonts from the Google Fonts repository.
FONTS = {
    "BigShouldersDisplay.ttf": "https://github.com/google/fonts/raw/main/ofl/bigshouldersdisplay/BigShouldersDisplay%5Bwght%5D.ttf",
    "ChakraPetch-Regular.ttf": "https://github.com/google/fonts/raw/main/ofl/chakrapetch/ChakraPetch-Regular.ttf",
    "ChakraPetch-Bold.ttf": "https://github.com/google/fonts/raw/main/ofl/chakrapetch/ChakraPetch-Bold.ttf",
    "OFL-ChakraPetch.txt": "https://github.com/google/fonts/raw/main/ofl/chakrapetch/OFL.txt",
    "OFL-BigShouldersDisplay.txt": "https://github.com/google/fonts/raw/main/ofl/bigshouldersdisplay/OFL.txt",
}


def fetch_fonts() -> None:
    os.makedirs(FONT_OUT, exist_ok=True)
    for name, url in FONTS.items():
        print(name)
        fetch(url, os.path.join(FONT_OUT, name))


def main(argv: list[str]) -> int:
    if "--hdri" in argv:
        fetch_hdris()
    elif "--tex" in argv:
        fetch_textures()
    elif "--fonts" in argv:
        fetch_fonts()
    else:
        fetch_textures()
        fetch_hdris()
        fetch_fonts()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
