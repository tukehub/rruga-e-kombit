"""Prepare a privately obtained CGTrader sports-car GLB for Vortex.

The source asset is NOT included in this repository. Run with Blender:
  blender -b -t 2 --python tools/import_cg_sport.py -- input.glb output.glb

The converted file is a licensed derivative and must not be published as a
standalone asset. Keep it in private storage and use an approved build path.
"""
import bpy
import math
import os
import sys
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index('--') + 1:]
if len(args) != 2:
    raise SystemExit('Expected input.glb and output.glb')
source, output = map(os.path.abspath, args)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
bpy.context.view_layer.update()

# Source faces -Y in Blender. Vortex expects +Y here, exported as -Z in glTF.
# Bring the 3.76 x 1.60 m source within the existing 4.36 x 1.96 m footprint.
convert = Matrix.Diagonal(Vector((1.17, 1.16, 1.16, 1.0))) @ Matrix.Rotation(math.pi, 4, 'Z')
groups = {
    'Wheel_FL_Textures 1_0': 'wheel_fl',
    'Wheel_FR_Textures 1_0': 'wheel_fr',
    'Wheel_BL_Textures 1_0': 'wheel_rl',
    'Wheel_BR_Textures 1_0': 'wheel_rr',
}
objects = [o for o in bpy.data.objects if o.type == 'MESH']
matrices = {o.name: o.matrix_world.copy() for o in objects}
body_parts = []
for obj in objects:
    original_name = obj.name
    pivot = convert @ matrices[original_name].translation
    obj.data.transform(convert @ matrices[original_name])
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    wheel_name = groups.get(original_name)
    if wheel_name:
        obj.data.transform(Matrix.Translation(-pivot))
        # Existing wheel animation mirrors the left wheel around Y in Godot.
        if wheel_name.endswith('l'):
            obj.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))
        obj.location = pivot
        obj.name = wheel_name
        # Keep the atlas on the wheels, without applying the body paint tint.
        for slot in obj.material_slots:
            if slot.material and slot.material.name.startswith('lambert2'):
                slot.material = slot.material.copy()
                slot.material.name = 'sport_wheel'
    elif original_name.startswith('Body_'):
        body_parts.append(obj)
    else:
        bpy.data.objects.remove(obj, do_unlink=True)
if len(body_parts) != 2 or any(name not in bpy.data.objects for name in groups.values()):
    raise RuntimeError('Unexpected source layout: expected body, glass, and four wheels')

for obj in body_parts:
    for slot in obj.material_slots:
        if slot.material and slot.material.name.startswith('lambert2'):
            slot.material.name = 'sport_body'
        elif slot.material and slot.material.name == 'Glass':
            slot.material.name = 'glass'
bpy.ops.object.select_all(action='DESELECT')
for obj in body_parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = body_parts[0]
bpy.ops.object.join()
bpy.context.object.name = 'body'

# Export only the five meshes, keeping original material textures/UVs intact.
bpy.ops.object.select_all(action='DESELECT')
for name in ['body', *groups.values()]:
    bpy.data.objects[name].select_set(True)
bpy.context.view_layer.objects.active = bpy.data.objects['body']
os.makedirs(os.path.dirname(output), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=output, export_format='GLB', use_selection=True)
print('VORTEX PRIVATE CAR prepared with body, glass and four wheel pivots')
