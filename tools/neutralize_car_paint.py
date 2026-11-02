"""Extract and neutralize the paint atlas from the decoded CC BY sport car.

Usage: python3 tools/neutralize_car_paint.py decoded.glb neutral.png
"""
import io
import json
from pathlib import Path
import struct
import sys

import numpy as np
from PIL import Image

raw = Path(sys.argv[1]).read_bytes()
json_size, json_type = struct.unpack_from('<I4s', raw, 12)
if json_type != b'JSON':
    raise ValueError('Expected glTF binary JSON chunk')
gltf = json.loads(raw[20:20 + json_size])
mat = next(x for x in gltf['materials'] if x.get('name') == 'Body_6')
tex = gltf['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]
image = gltf['images'][tex['source']]
view = gltf['bufferViews'][image['bufferView']]
binary_start = 20 + json_size + 8
start = binary_start + view.get('byteOffset', 0)
img = Image.open(io.BytesIO(raw[start:start + view['byteLength']])).convert('RGBA')
data = np.array(img)
lightness = data[:, :, :3].max(axis=2)
data[:, :, :3] = lightness[:, :, None]
Image.fromarray(data).save(sys.argv[2])
