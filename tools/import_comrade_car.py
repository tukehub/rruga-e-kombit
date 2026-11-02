"""Convert Comrade1280's CC BY 4.0 generic sport car to the Vortex node contract.

Source: https://sketchfab.com/3d-models/20f9af9b8a404d5cb022ac6fe87f21f5
Optimized derivative: https://github.com/pedrosoandre/carros
Reproduce the checked-in asset from the pinned derivative source:
  curl -L https://raw.githubusercontent.com/pedrosoandre/carros/2d18dfd9db96bbf0d9cffa949deaf7f571388cbf/assets/generico-esportivo.glb -o source.glb
  npx -y @gltf-transform/cli copy source.glb decoded.glb
  python3 tools/neutralize_car_paint.py decoded.glb neutral.png
  blender -b --python tools/import_comrade_car.py -- decoded.glb neutral.png godot/assets/cars/vortex_gt.glb

Source GLB SHA-256: 414f803f855556a2142766ac9f213cadaab080c1d9375ef8b677f082c450d967
"""
import bpy, math, sys, os
args = sys.argv[sys.argv.index('--') + 1:]
if len(args) != 3:
 raise SystemExit('Expected: decoded source GLB, neutral texture PNG, output GLB')
source_glb, neutral_texture, output_glb = map(os.path.abspath, args)
from mathutils import Matrix, Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source_glb)
meshes=[x for x in bpy.data.objects if x.type=='MESH']
front=Vector(((-1.246-.120)/2,(-.539-1.352)/2,0)); rear=Vector(((1.301+.204)/2,(.646+1.438)/2,0))
ang=math.pi/2-math.atan2(front.y-rear.y,front.x-rear.x)
rot=Matrix.Rotation(ang,4,'Z')
for o in meshes:
 o.data.transform(rot @ o.matrix_world);o.parent=None;o.matrix_world=Matrix.Identity(4)
coords=[v.co for o in meshes for v in o.data.vertices];lo=[min(p[i] for p in coords) for i in range(3)];hi=[max(p[i] for p in coords) for i in range(3)];print('original extents',lo,hi)
scale=Matrix.Diagonal(Vector((1.94/(hi[0]-lo[0]),4.62/(hi[1]-lo[1]),1.38/(hi[2]-lo[2]),1)))
center=Matrix.Translation(Vector((-(lo[0]+hi[0])*.5,-(lo[1]+hi[1])*.5,-lo[2])))
for o in meshes:o.data.transform(scale @ center)
body=[x for x in meshes if 'Sport body_' in x.name]; wheels=[x for x in meshes if x not in body]
bpy.ops.object.select_all(action='DESELECT')
for o in body:o.select_set(True)
bpy.context.view_layer.objects.active=body[0];bpy.ops.object.join();body[0].name='body'
for o in wheels:
 verts=o.data.vertices; lo=[min(v.co[i] for v in verts) for i in range(3)];hi=[max(v.co[i] for v in verts) for i in range(3)]; p=Vector([(a+b)*.5 for a,b in zip(lo,hi)])
 left=p.x<0;front=p.y>0;o.name='wheel_'+('f' if front else 'r')+('l' if left else 'r');o.data.transform(Matrix.Translation(-p));o.location=p
 if left:o.data.transform(Matrix.Rotation(math.pi,4,'Z'))
 print('wheel',o.name,tuple(p))
for o in list(bpy.data.objects):
 if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
mat=bpy.data.materials.get('Body_6');mat.name='paint'
for node in mat.node_tree.nodes:
 if node.type=='TEX_IMAGE' and node.image and ('base' in node.name.lower() or node.outputs['Color'].is_linked):
  for lk in list(node.outputs['Color'].links):
   if lk.to_node.type=='BSDF_PRINCIPLED' and lk.to_socket.name=='Base Color':
    node.image=bpy.data.images.load(neutral_texture,check_existing=True);node.image.pack()
print('exporting');bpy.ops.export_scene.gltf(filepath=output_glb,export_format='GLB',export_animations=False)
