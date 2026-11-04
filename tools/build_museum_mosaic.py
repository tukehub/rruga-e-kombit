"""Rectify Marina Lamaj's CC BY-SA 4.0 museum photograph for the museum model.

Download https://commons.wikimedia.org/wiki/File:Mosaic_of_the_National_Historical_Museum_of_Albania.jpg
and pass its local path as the first argument. The adaptation is also CC BY-SA 4.0.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

image = Image.open(sys.argv[1]).convert('RGB')
scale = image.width / 900.0
source = np.array([(0, 285), (899, 155), (899, 565), (0, 623)], dtype=float) * scale
width, height = 1536, 456
dest = np.array([(0, 0), (width, 0), (width, height), (0, height)], dtype=float)
matrix, values = [], []
for (x, y), (u, v) in zip(dest, source):
    matrix.extend([[x, y, 1, 0, 0, 0, -u*x, -u*y], [0, 0, 0, x, y, 1, -v*x, -v*y]])
    values.extend([u, v])
coefficients = np.linalg.solve(np.array(matrix), np.array(values))
result = image.transform((width, height), Image.Transform.PERSPECTIVE, coefficients, Image.Resampling.BICUBIC)
result = ImageEnhance.Color(result).enhance(0.84)
output = Path(__file__).resolve().parents[1] / 'godot/assets/landmarks/national_museum_mosaic.jpg'
result.save(output, quality=88, optimize=True)
