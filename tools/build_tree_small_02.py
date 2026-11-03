"""Create a reduced 3D trunk/branch mesh from Poly Haven Tree Small 02 (CC0).

Download the 1k glTF from https://polyhaven.com/a/tree_small_02 including its
bin and textures, then run:
  blender -b -t 2 --python tools/build_tree_small_02.py -- tree_small_02_1k.gltf output.glb
The model retains the original materials and approximately 2,049 triangles.
"""
import sys, os
args = sys.argv[sys.argv.index('--') + 1:]
if len(args) != 2:
    raise SystemExit('Expected input glTF and output GLB')
source, output = map(os.path.abspath, args)
import bpy, numpy as np, os
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
o=next(x for x in bpy.data.objects if x.type=='MESH'); mesh=o.data
# Sample the real trunk and branching geometry; the foliage will be clustered separately.
coords=np.empty(len(mesh.vertices)*3,dtype=np.float32); mesh.vertices.foreach_get('co',coords); coords=coords.reshape((-1,3))
tris=np.empty(len(mesh.loops),dtype=np.int32);mesh.loops.foreach_get('vertex_index',tris);tris=tris.reshape((-1,3))
mi=np.empty(len(mesh.polygons),dtype=np.int32);mesh.polygons.foreach_get('material_index',mi)
uvs=[]
for layer in mesh.uv_layers:
 arr=np.empty(len(mesh.loops)*2,dtype=np.float32);layer.data.foreach_get('uv',arr);uvs.append(arr.reshape((-1,3,2)))
print('UV layers',len(uvs),flush=True)
outputs=[]
for idx,target in [(0,1400),(2,650)]:
 mask=mi==idx; tri=tris[mask]; ids, inv=np.unique(tri,return_inverse=True); faces=inv.reshape((-1,3)); points=coords[ids]
 m=bpy.data.meshes.new('tree_part');m.from_pydata(points.tolist(),[],faces.tolist());m.update(); obj=bpy.data.objects.new('branch' if idx==0 else 'trunk',m);bpy.context.collection.objects.link(obj)
 for k,uv in enumerate(uvs):
  ly=m.uv_layers.new(name=mesh.uv_layers[k].name); ly.data.foreach_set('uv',uv[mask].reshape(-1))
 m.materials.append(mesh.materials[idx]); obj.matrix_world=o.matrix_world.copy()
 for poly in m.polygons: poly.use_smooth=True
 mod=obj.modifiers.new('Mobile reduction','DECIMATE');mod.ratio=min(1.0,target/len(m.polygons));bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
 print(obj.name, len(m.polygons),flush=True); outputs.append(obj)
bpy.data.objects.remove(o,do_unlink=True)
for obj in list(bpy.data.objects):
 if obj not in outputs:bpy.data.objects.remove(obj,do_unlink=True)
# normalize entire asset by 1.85 (height near 8 m); no animations.
for obj in outputs: obj.scale=(1.85,)*3
for im in bpy.data.images:
 if im.source=='FILE':
  try: im.pack()
  except: pass
bpy.ops.object.select_all(action='DESELECT')
for o in outputs:o.select_set(True)
bpy.context.view_layer.objects.active=outputs[0]
bpy.ops.object.join()
outputs[0].name='tree_geometry'
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.ops.export_scene.gltf(filepath=output, export_format='GLB',export_apply=True,export_animations=False)
