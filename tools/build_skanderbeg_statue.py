"""Build a mobile-budget, *approximate* Skanderbeg equestrian statue.

Run: blender -b --python tools/build_skanderbeg_statue.py -- RIDER.glb BUST.glb OUT.glb
RIDER.glb: CC BY 4.0 Loïc Norgeot, https://zenodo.org/records/10260808
BUST.glb: CC BY 4.0 xorgol, https://zenodo.org/records/10285017
Uses the horse and rider scan as a base, replacing the head with a cleaned-up
Skanderbeg bust scan. This is an artistic approximation, not a scan of the
Tirana monument. The generated mesh is 7.8m tall and sits on a separate plinth.
"""
import bpy
import bmesh
import sys
from mathutils import Matrix

args = sys.argv[sys.argv.index('--') + 1:]
if len(args) != 3:
    raise SystemExit('Expected rider GLB, Skanderbeg bust GLB, output GLB')
rider_path, bust_path, output_path = args
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def flatten(obj):
    matrix = obj.matrix_world.copy()
    for vertex in obj.data.vertices:
        vertex.co = matrix @ vertex.co
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)


def cut(obj, z, keep_above):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                           dist=0.0001, plane_co=(0, 0, z), plane_no=(0, 0, 1),
                           clear_inner=keep_above, clear_outer=not keep_above)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def decimate(obj, target):
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new('Phone triangle budget', 'DECIMATE')
    modifier.ratio = min(1.0, target / max(1, len(obj.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    for face in obj.data.polygons:
        face.use_smooth = True


bpy.ops.import_scene.gltf(filepath=rider_path)
body = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
flatten(body)
cut(body, 84.0, keep_above=False)
body.name = 'Equestrian bronze'
decimate(body, 22000)

bpy.ops.object.select_all(action='DESELECT')
bpy.ops.import_scene.gltf(filepath=bust_path)
heads = [o for o in bpy.context.selected_objects if o.type == 'MESH']
for obj in heads:
    flatten(obj)
    obj.select_set(True)
bpy.context.view_layer.objects.active = heads[0]
bpy.ops.object.join()
head = bpy.context.object
cut(head, -0.8, keep_above=True)
verts = [v.co for v in head.data.vertices]
lo = [min(v[i] for v in verts) for i in range(3)]
hi = [max(v[i] for v in verts) for i in range(3)]
for v in head.data.vertices:
    v.co.x = (v.co.x - (lo[0] + hi[0]) * 0.5) * 14.0
    v.co.y = (v.co.y - (lo[1] + hi[1]) * 0.5) * 14.0 + 2.0
    v.co.z = (v.co.z - lo[2]) * 14.0 + 83.5
head.name = 'Skanderbeg portrait'
bronze = bpy.data.materials.new('Weathered bronze')
bronze.diffuse_color = (0.19, 0.24, 0.20, 1.0)
bronze.use_nodes = True
pbr = bronze.node_tree.nodes.get('Principled BSDF')
pbr.inputs['Base Color'].default_value = (0.19, 0.24, 0.20, 1.0)
pbr.inputs['Metallic'].default_value = 0.58
pbr.inputs['Roughness'].default_value = 0.66
head.data.materials.clear()
head.data.materials.append(bronze)
for face in head.data.polygons:
    face.material_index = 0
decimate(head, 10000)

# Fill the open seam under the scan, creating a bronze collar at the neck.
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=(0, 2, 83.7))
collar = bpy.context.object
collar.name = 'Bronze collar'
collar.scale = (9, 6.5, 2.5)
collar.data.materials.append(bronze)
for face in collar.data.polygons:
    face.use_smooth = True

# The original scan is in arbitrary units; the model's final height is 7.8m.
for obj in [body, head, collar]:
    obj.scale *= 7.8 / 100.0
    obj.location *= 7.8 / 100.0
bpy.ops.object.select_all(action='DESELECT')
for obj in [body, head, collar]:
    obj.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB', use_selection=True)
print('body faces:', len(body.data.polygons), 'head faces:', len(head.data.polygons))
