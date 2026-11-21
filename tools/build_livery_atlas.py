"""Build godot/assets/cars/livery_atlas.png: transparent artwork for the
car liveries (README 6.3). Four columns, one per livery tile; the top row is
seen from above (u = across the car, v = front to back), the bottom row from
the side (u = front to back, v = top to bottom). The car shader projects them
and replaces the white ink with a colour that contrasts with the paint."""
from pathlib import Path
from PIL import Image, ImageDraw

TILE = 256
OUT = Path(__file__).resolve().parents[1] / 'godot' / 'assets' / 'cars' / 'livery_atlas.png'


def tile(col, row):
    return col * TILE, row * TILE


def rect(draw, col, row, u0, v0, u1, v1, ink="white"):
    x, y = tile(col, row)
    draw.rectangle([x + u0 * TILE, y + v0 * TILE, x + u1 * TILE - 1, y + v1 * TILE - 1], fill=ink)


def poly(draw, col, row, points, ink="white"):
    x, y = tile(col, row)
    draw.polygon([(x + u * TILE, y + v * TILE) for u, v in points], fill=ink)


def main():
    image = Image.new('RGBA', (TILE * 4, TILE * 2), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    # Endurance stripes with offset copper pinlines and a rising rocker stripe.
    for u in (0.34, 0.52):
        rect(draw, 0, 0, u, 0, u + 0.12, 1)
        rect(draw, 0, 0, u + 0.135, 0, u + 0.155, 1, "#dc9359")
    poly(draw, 0, 1, [(0, .71), (.69, .62), (.96, .43), (.83, .62), (.69, .68), (0, .75)])
    poly(draw, 0, 1, [(0, .78), (.70, .71), (.86, .61), (.72, .75), (0, .81)], "#dc9359")

    # A broken lightning flash runs forward from the rear quarter to the nose.
    poly(draw, 1, 1, [(.05,.64), (.48,.35), (.43,.48), (.96,.28), (.53,.57), (.58,.43)])
    poly(draw, 1, 1, [(.27,.62), (.53,.48), (.49,.59), (.87,.41), (.41,.72), (.45,.57)], "#3bdbe5")
    poly(draw, 1, 0, [(.20,0), (.58,.30), (.48,.30), (.83,.67), (.36,.26), (.46,.26)])
    poly(draw, 1, 0, [(.28,0), (.63,.26), (.55,.26), (.71,.44), (.46,.23), (.53,.23)], "#3bdbe5")

    # A swept chequered flag follows the rear haunch. Each square has a
    # sloping edge so the ribbon reads as one graphic across the side panel.
    for i in range(9):
        x = .30 + i * .072
        y = .62 - i * .025
        for j in range(3):
            if (i + j) % 2 == 0:
                v = y + j * .067
                poly(draw, 2, 1, [(x,v), (x+.072,v-.025), (x+.072,v+.042), (x,v+.067)])
    poly(draw, 2, 1, [(.23,.63), (.97,.37), (.97,.39), (.23,.65)], "#ffb32e")
    for i in range(4):
        for j in range(8):
            if (i + j) % 2 == 0:
                rect(draw, 2, 0, .17 + i*.07, j*.125, .24 + i*.07, (j+1)*.125)
    rect(draw, 2, 0, .47, 0, .49, 1, "#ffb32e")

    # Split paint sweeps up the tail with a vermilion coachline.
    poly(draw, 3, 1, [(0,.74), (.52,.63), (.78,.38), (1,.31), (1,1), (0,1)])
    poly(draw, 3, 1, [(0,.68), (.51,.57), (.77,.32), (1,.25), (1,.28), (.78,.35), (.52,.60), (0,.71)], "#fa583d")
    poly(draw, 3, 0, [(.71,0), (1,0), (1,1), (.42,1)])
    poly(draw, 3, 0, [(.66,0), (.68,0), (.39,1), (.37,1)], "#fa583d")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
