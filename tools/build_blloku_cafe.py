#!/usr/bin/env python3
"""Build the Blloku furniture GLB from Poly Haven's CC0 1k glTF.

Requires network access and Blender on PATH. The source contains one wooden
folding table and two chairs. Simplified geometry retains all source materials
and textures. The complete set is instanced in Blloku, not copied per object.
"""
import json
from pathlib import Path
import subprocess
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'godot/assets/props/blloku_cafe_furniture.glb'
AGENT = 'VortexGodotAssetPipeline/1.0'


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


BLENDER_SCRIPT = r'''
import bpy
import sys
source, output = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
chairs = [o for o in objects if o.name.lower().endswith(('_chair_01', '_chair_02'))]
tables = [o for o in objects if o.name.lower().endswith('_table')]
if len(chairs) != 2 or len(tables) != 1:
    raise RuntimeError('Unexpected Poly Haven furniture scene layout')
for o in objects:
    bpy.context.view_layer.objects.active = o
    decimate = o.modifiers.new('MobileDecimate', 'DECIMATE')
    decimate.ratio = 0.30 if o in chairs else 0.40
    decimate.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    print('MOBILE:', o.name, len(o.data.polygons), 'triangles')
bpy.ops.object.select_all(action='DESELECT')
for o in objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = chairs[0]
bpy.ops.object.join()
bpy.context.active_object.name = 'CafeFurniture'
# Lift the original small ground penetration to avoid clipping the deck.
for o in bpy.context.scene.objects:
    if o.type == 'MESH':
        o.location.z += 0.006
bpy.ops.export_scene.gltf(filepath=output, export_format='GLB', export_apply=True,
                          export_texcoords=True, export_normals=True, export_materials='EXPORT')
'''


def main():
    metadata = json.loads(get('https://api.polyhaven.com/files/outdoor_table_chair_set_01'))
    source = metadata['gltf']['1k']['gltf']
    with tempfile.TemporaryDirectory(prefix='vortex-cafe-') as directory:
        root = Path(directory)
        (root / 'source.gltf').write_bytes(get(source['url']))
        for relative, file_info in source['include'].items():
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(get(file_info['url']))
        script = root / 'convert.py'
        script.write_text(BLENDER_SCRIPT, encoding='utf-8')
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['blender', '-b', '-t', '2', '--python-exit-code', '1', '--python', str(script), '--',
                        str(root / 'source.gltf'), str(OUTPUT)], check=True)
    print('Built', OUTPUT.relative_to(ROOT), flush=True)


if __name__ == '__main__':
    main()
