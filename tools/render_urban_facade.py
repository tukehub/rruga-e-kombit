"""Render a 3 m facade tile from Poly Haven's CC0 modular urban apartments.

Download the 1k glTF and dependencies from https://polyhaven.com/a/modular_urban_apartments_facade.
Run: blender -b -t 2 --python tools/render_urban_facade.py -- model.gltf output.png
"""
import sys, os
args = sys.argv[sys.argv.index('--') + 1:]
if len(args) != 2:
    raise SystemExit('Expected model.gltf output.png')
source, output = map(os.path.abspath, args)
import bpy, math
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
keep={'wall_standard_standard_01','window_centered_large_01'}
for o in list(bpy.data.objects):
 if o.type == 'MESH' and o.name not in keep: bpy.data.objects.remove(o,do_unlink=True)
w=bpy.data.objects['window_centered_large_01']; w.location.x-=11;w.location.z-=4
mat=bpy.data.materials.new('window_glass');mat.diffuse_color=(0.065,0.11,0.14,1);mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(0.065,0.11,0.14,1);bs.inputs['Roughness'].default_value=0.22;bs.inputs['Metallic'].default_value=0.18
bpy.ops.mesh.primitive_cube_add(size=1,location=(-1.5,-0.03,1.25));pane=bpy.context.object;pane.scale=(2.08,0.02,2.0);pane.data.materials.append(mat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False;scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('World');scene.world.color=(0.4,0.4,0.4)
scene.view_settings.view_transform='Standard'
bpy.ops.object.camera_add(location=(-1.5,-10,1.5));cam=bpy.context.object;cam.rotation_euler=(Vector((-1.5,0,1.5))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.0;scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-2,-5,6));light=bpy.context.object;light.data.energy=600;light.data.shape='DISK';light.data.size=10;light.rotation_euler=(Vector((-1.5,0,1.5))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.image_settings.file_format='PNG';scene.render.filepath=output;bpy.ops.render.render(write_still=True)
