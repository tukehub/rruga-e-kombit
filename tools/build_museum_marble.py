"""Create mobile museum cladding from Poly Haven Marble 01 (CC0).

Usage: python tools/build_museum_marble.py ALBEDO.jpg NORMAL.jpg ROUGHNESS.jpg
Source: https://polyhaven.com/a/marble_01, Rob Tuytel, CC0 1.0.
The photograph is cropped to one stone panel, made seamlessly repeating with
mirroring, lightened and desaturated. Normal-map channels are corrected for
mirrored axes. Panel joints are subtly darkened in albedo.
"""
from pathlib import Path
import sys
from PIL import Image, ImageEnhance, ImageOps, ImageDraw

if len(sys.argv) != 4:
    raise SystemExit('expected source albedo, normal and roughness JPG paths')
out = Path(__file__).resolve().parents[1] / 'godot/assets/textures'
out.mkdir(parents=True, exist_ok=True)
crop = (72, 12, 336, 192)

def repeat_panel(path, normal=False):
    base = Image.open(path).convert('RGB').crop(crop).resize((512, 512), Image.Resampling.LANCZOS)
    result = Image.new('RGB', (1024, 1024))
    for x in range(2):
        for y in range(2):
            p = base.copy()
            if x:
                p = ImageOps.mirror(p)
            if y:
                p = ImageOps.flip(p)
            if normal and (x or y):
                r, g, b = p.split()
                if x: r = ImageOps.invert(r)
                if y: g = ImageOps.invert(g)
                p = Image.merge('RGB', (r, g, b))
            result.paste(p, (x * 512, y * 512))
    return result

albedo = repeat_panel(sys.argv[1])
albedo = ImageEnhance.Color(albedo).enhance(0.2)
albedo = ImageEnhance.Brightness(albedo).enhance(1.34)
# Fine joints between approximately square panels, as seen on the facade.
draw = ImageDraw.Draw(albedo, 'RGBA')
for edge in (0, 512, 1023):
    draw.line([(edge, 0), (edge, 1023)], fill=(75, 70, 64, 70), width=2)
    draw.line([(0, edge), (1023, edge)], fill=(75, 70, 64, 70), width=2)
albedo.save(out / 'museum_marble_diff.jpg', quality=88, optimize=True)
repeat_panel(sys.argv[2], normal=True).save(out / 'museum_marble_nor.jpg', quality=90, optimize=True)
repeat_panel(sys.argv[3]).save(out / 'museum_marble_rough.jpg', quality=88, optimize=True)
