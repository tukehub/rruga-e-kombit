"""Adapt the CC BY 4.0 Khronos Car Concept to Vortex's mobile car contract.

Source: https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/CarConcept
Original: © 2024 Darmstadt Graphics Group GmbH and Eric Chadwick, CC BY 4.0.
https://creativecommons.org/licenses/by/4.0/ . This derivative removes all
trademarks and all original textures, changes materials, straightens the front
wheels, simplifies geometry, rescales, and groups it for a mobile racing game.

Run: blender -b -t 2 --python tools/import_carconcept.py -- source.glb output.glb
Verified input SHA-256: c272098089d78c5cd9fd9f24ff50ee8acf8d932c55f2d55fc10adb6c8998966b
"""
import bpy
import math
import os
import sys
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index('--') + 1:]
if len(args) != 2:
    raise SystemExit('Expected source.glb and output.glb')
source, output = map(os.path.abspath, args)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
bpy.context.view_layer.update()

# The original poses the front wheels 30 degrees left and contains separate
# plate/steering-logo meshes. All source materials are replaced, so neither
# original logo atlas nor its tire-side trademark image can enter the output.
wheels = ['WheelFrontL', 'WheelFrontR', 'WheelRearL', 'WheelRearR']
pivots = {name: bpy.data.objects[name].matrix_world.translation.copy() for name in wheels}

def wheel_group(obj):
    p = obj.parent
    while p:
        if p.name in wheels:
            return p.name
        p = p.parent
    return None

def find_material(old_name):
    if old_name.startswith('Paint 1'):
        return 'paint'
    if old_name in ('Glass',):
        return 'glass'
    if old_name in ('Headlight',):
        return 'light_front'
    if old_name in ('Brakelight', 'Signallight'):
        return 'light_rear'
    if old_name in ('Rim1', 'Rim2', 'Disc', 'Mirror', 'Hardware'):
        return 'rim'
    if old_name in ('Tireside', 'Tiretread'):
        return 'tyre'
    if old_name.startswith('Interior') or old_name in ('Dashboard', 'Panel Sides', 'Floormat'):
        return 'interior'
    return 'trim'

colors = {
    'paint': ((0.7, 0.02, 0.02, 1), 0.28, 0.30),
    'glass': ((0.12, 0.20, 0.28, 1), 0.18, 0.12),
    'light_front': ((0.85, 0.9, 1, 1), 0.3, 0.2),
    'light_rear': ((0.5, 0.03, 0.03, 1), 0.1, 0.25),
    'rim': ((0.65, 0.67, 0.70, 1), 0.8, 0.2),
    'tyre': ((0.025, 0.025, 0.027, 1), 0, 0.9),
    'interior': ((0.07, 0.075, 0.08, 1), 0, 0.85),
    'trim': ((0.025, 0.03, 0.035, 1), 0.15, 0.55),
}
materials = {}
for name, (col, metallic, rough) in colors.items():
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = col
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = col
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = rough
    materials[name] = mat

remove = {'License Plate', 'InteriorSteeringEmblem', 'Engine', 'Axles',
          'InteriorFloor', 'InteriorFloormats', 'InteriorRearPanels',
          'InteriorSteeringHandleL', 'InteriorSteeringHandleR'}
# Rotate Blender front from -Y to +Y, so glTF/Godot front is -Z. Scale in
# metres to the established collision footprint while preserving aspect ratio.
turn = Matrix.Rotation(math.pi, 4, 'Z')
scale = Matrix.Diagonal(Vector((0.84, 1.0, 1.0, 1.0)))
# Translate the visual length midpoint to the simulation center; source body
# is slightly offset toward its nose. Its tires already sit on the ground.
center = Matrix.Translation(Vector((0, -0.24, 0.0)))
world_to_car = center @ scale @ turn
car_pivots = {k: world_to_car @ v for k, v in pivots.items()}
groups = {'body': []}
for w in wheels:
    groups[w] = []
objects = [o for o in bpy.data.objects if o.type == 'MESH']
# Snapshot before any parent is detached or changed. The source nests most
# parts under BodyUnderside; editing a parent changes child world matrices.
world_matrices = {obj: obj.matrix_world.copy() for obj in objects}
wheel_groups = {obj: wheel_group(obj) for obj in objects}
for obj in objects:
    if obj.name in remove or obj.name.startswith(('InteriorPedal', 'InteriorDoor')):
        bpy.data.objects.remove(obj, do_unlink=True)
        continue
    # Remove source glTF material-variant overrides before assigning paint.
    # Otherwise the exporter silently resurrects original non-tintable materials.
    obj.data.gltf2_variant_mesh_data.clear()
    obj.data.gltf2_variant_default_materials.clear()
    group = wheel_groups[obj]
    transform = world_matrices[obj]
    if group and group.startswith('WheelFront'):
        pivot = pivots[group]
        transform = Matrix.Translation(pivot) @ Matrix.Rotation(math.pi / 6.0, 4, 'Z') @ Matrix.Translation(-pivot) @ transform
    transform = world_to_car @ transform
    obj.data.transform(transform)
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    # Assign clean materials per polygon before clearing the source slots.
    old_names = [slot.material.name if slot.material else '' for slot in obj.material_slots]
    used = [find_material(n) for n in old_names] or ['trim']
    idx = [used[min(p.material_index, len(used)-1)] for p in obj.data.polygons]
    obj.data.materials.clear()
    ordered = list(dict.fromkeys(idx))
    for name in ordered:
        obj.data.materials.append(materials[name])
    for poly, name in zip(obj.data.polygons, idx):
        poly.material_index = ordered.index(name)
    # Most unnecessary geometry is in source wipers and inner wheel parts.
    count = len(obj.data.polygons)
    ratio = 1.0
    if 'WindshieldWipers' in obj.name:
        ratio = 0.025
    elif 'BrakePad' in obj.name:
        ratio = 0.12
    elif 'Rim' in obj.name:
        ratio = 0.10
    elif count > 1000:
        ratio = 0.20 if obj.name.startswith('Body') else 0.13
    if ratio < 1.0:
        mod = obj.modifiers.new('mobile simplification', 'DECIMATE')
        mod.ratio = ratio
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    groups[group or 'body'].append(obj)

# Join by body/wheel. Inverted local mesh for left wheels compensates the
# existing CarVisual's mirrored wheel spin convention.
for name, parts in groups.items():
    if not parts:
        raise RuntimeError('Missing geometry for ' + name)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    result = parts[0]
    if name == 'body':
        result.name = 'body'
    else:
        front = name.startswith('WheelFront')
        # turn flipped original +X into game's left (-X)
        left = name.endswith('L')
        pivot = car_pivots[name]
        result.data.transform(Matrix.Translation(-pivot))
        if left:
            result.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))
        result.location = pivot
        result.name = 'wheel_' + ('f' if front else 'r') + ('l' if left else 'r')
    print(result.name, 'triangles', sum(len(p.vertices)-2 for p in result.data.polygons), 'slots', len(result.data.materials))

# Low rear lip, batched into the existing body mesh to avoid extra draw calls.
# Blender +Y is the front of the converted car; the rear is at -Y.
body = bpy.data.objects['body']
aero_parts = []
for location, size in [((0.0, -1.88, 0.96), (1.25, 0.17, 0.045))]:
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    wing = bpy.context.object
    wing.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    wing.data.materials.append(materials['paint'])
    bevel = wing.modifiers.new('soft edges', 'BEVEL')
    bevel.width = 0.025
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    aero_parts.append(wing)
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
for part in aero_parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()

for obj in list(bpy.data.objects):
    if obj.type != 'MESH':
        bpy.data.objects.remove(obj, do_unlink=True)
# Strip every embedded source image (including unlicensed mark textures).
for img in list(bpy.data.images):
    bpy.data.images.remove(img)
bpy.ops.export_scene.gltf(filepath=output, export_format='GLB', export_animations=False)
