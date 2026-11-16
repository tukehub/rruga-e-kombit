"""Build godot/assets/cars/livery_atlas.png: white-on-transparent masks for the
car liveries (README 6.3). Four columns, one per livery tile; the top row is
seen from above (u = across the car, v = front to back), the bottom row from
the side (u = front to back, v = top to bottom). The car shader projects them
and paints the mask in the livery colour."""
from pathlib import Path
from PIL import Image, ImageDraw

TILE = 256
OUT = Path(__file__).resolve().parents[1] / 'godot' / 'assets' / 'cars' / 'livery_atlas.png'


def tile(col, row):
    return col * TILE, row * TILE


def rect(draw, col, row, u0, v0, u1, v1):
    x, y = tile(col, row)
    draw.rectangle([x + u0 * TILE, y + v0 * TILE, x + u1 * TILE - 1, y + v1 * TILE - 1], fill=(255, 255, 255, 255))


def poly(draw, col, row, points):
    x, y = tile(col, row)
    draw.polygon([(x + u * TILE, y + v * TILE) for u, v in points], fill=(255, 255, 255, 255))


def main():
    image = Image.new('RGBA', (TILE * 4, TILE * 2), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    # 0 stripes: twin racing stripes nose to tail, a thin line along the sills.
    rect(draw, 0, 0, 0.36, 0.0, 0.45, 1.0)
    rect(draw, 0, 0, 0.55, 0.0, 0.64, 1.0)
    rect(draw, 0, 1, 0.04, 0.70, 0.96, 0.75)
    # 1 arrow: a long arrow along each side, pointing forward.
    poly(draw, 1, 1, [(0.06, 0.52), (0.30, 0.34), (0.30, 0.45), (0.92, 0.45), (0.92, 0.59), (0.30, 0.59), (0.30, 0.70)])
    # 2 checker: a chequered band over the rear quarters and across the roof.
    for i in range(8):
        for j in range(3):
            if (i + j) % 2 == 0:
                rect(draw, 2, 1, 0.56 + i * 0.05, 0.40 + j * 0.09, 0.61 + i * 0.05, 0.49 + j * 0.09)
    for i in range(8):
        for j in range(2):
            if (i + j) % 2 == 0:
                rect(draw, 2, 0, 0.1 + i * 0.1, 0.50 + j * 0.06, 0.2 + i * 0.1, 0.56 + j * 0.06)
    # 3 split: the lower half of the body in the second colour.
    rect(draw, 3, 1, 0.0, 0.62, 1.0, 1.0)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
