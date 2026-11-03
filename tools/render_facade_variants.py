"""Render facade variants from Poly Haven modular urban apartments facade (CC0).

Run: blender -b -t 2 --python tools/render_facade_variants.py -- model.gltf output.png small|double
"""
import bpy,sys
from mathutils import Vector
source,output,variant=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
window={'small':'window_centered_small_01','double':'window_centered_double_01'}[variant]
keep={'wall_standard_standard_01',window}
for o in list(bpy.data.objects):
 if o.type=='MESH' and o.name not in keep:bpy.data.objects.remove(o,do_unlink=True)
w=bpy.data.objects[window]
w.location.x-= {'small':15,'double':19}[variant]
w.location.z-=4
mat=bpy.data.materials.new('window_glass');mat.diffuse_color=(0.065,0.11,0.14,1);mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(0.065,0.11,0.14,1);bs.inputs['Roughness'].default_value=0.22;bs.inputs['Metallic'].default_value=0.18
for pane_x in ([-1.5] if variant == 'small' else [-2.25, -0.75]):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(pane_x,-0.03,1.25));pane=bpy.context.object;pane.scale=(1.08,0.02,2.0);pane.data.materials.append(mat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False;scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('World');scene.world.color=(0.4,0.4,0.4);scene.view_settings.view_transform='Standard'
bpy.ops.object.camera_add(location=(-1.5,-10,1.5));cam=bpy.context.object;cam.rotation_euler=(Vector((-1.5,0,1.5))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.0;scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-2,-5,6));light=bpy.context.object;light.data.energy=600;light.data.shape='DISK';light.data.size=10;light.rotation_euler=(Vector((-1.5,0,1.5))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.image_settings.file_format='PNG';scene.render.filepath=output;bpy.ops.render.render(write_still=True)
