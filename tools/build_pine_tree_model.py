#!/usr/bin/env python3
"""Build the mobile pine from the first Poly Haven tree's bark and trunk.

Run using Blender: blender -b -P tools/build_pine_tree_model.py -- \
    trunk.gltf twig_diff.jpg twig_alpha.png output.glb [decimation_ratio]

The full source's needle mesh contains millions of triangles. Use its actual
bark and branch geometry with a small, double-sided textured needle-card mesh
instead. The tree is normalized to about eight metres and planted at z=0.
"""
import math
import random
import sys
from array import array
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if len(args) not in (4, 5):
    raise SystemExit('Expected trunk.gltf twig_diff.jpg twig_alpha.png output.glb [ratio]')
source, twig_diff, twig_alpha, output = map(lambda p: str(Path(p).resolve()), args[:4])
ratio = float(args[4]) if len(args) == 5 else 0.22
if not 0 < ratio <= 1:
    raise SystemExit('Decimation ratio must be in (0, 1].')

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if not objects:
    raise RuntimeError('Source glTF contains no trunk geometry')

# Bake the imported hierarchy (including the source node's translation) into
# vertex positions so foliage anchors and the exported trunk share coordinates.
for obj in objects:
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
points = [v.co.copy() for obj in objects for v in obj.data.vertices]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
height = hi.z - lo.z
if height < 0.01:
    raise RuntimeError('Trunk has no measurable height')
# Source origin is at the trunk foot; use vertices close to the ground to
# identify the centre rather than the centre of an asymmetric crown.
foot = [p for p in points if p.z < lo.z + height * 0.025]
centre = sum(foot, Vector()) / len(foot) if foot else (lo + hi) * 0.5
scale = 7.6 / height
for obj in objects:
    for vert in obj.data.vertices:
        vert.co = Vector(((vert.co.x - centre.x) * scale,
                          (vert.co.y - centre.y) * scale,
                          (vert.co.z - lo.z) * scale))

# Select real branch vertices before decimation. Sampling both by height and
# by radius avoids concentrating all needles on the densest piece of bark.
levels = [[] for _ in range(14)]
for obj in objects:
    for vert in obj.data.vertices:
        p = vert.co
        radius = math.hypot(p.x, p.y)
        if 1.7 < p.z < 7.55 and radius > 0.16:
            levels[min(13, int((p.z - 1.7) / 5.85 * 14))].append(p.copy())

# The requested 22% is an upper bound. The original trunk has more than
# 100,000 triangles, so cap at around 3,000 for mobile.
face_total = sum(len(o.data.polygons) for o in objects)
effective_ratio = min(ratio, 3000.0 / max(1, face_total))
for obj in objects:
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('MobileDecimate', 'DECIMATE')
    mod.ratio = effective_ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # Many source branches are disconnected UV islands, so Blender's
    # decimator has a floor. Retain the largest visible islands if necessary.
    budget = max(100, int(3800 / len(objects)))
    if len(obj.data.polygons) > budget:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        remaining = set(bm.faces)
        islands = []
        while remaining:
            face = remaining.pop()
            stack, island, area = [face], [], 0.0
            while stack:
                current = stack.pop()
                island.append(current)
                area += current.calc_area()
                for edge in current.edges:
                    for neighbor in edge.link_faces:
                        if neighbor in remaining:
                            remaining.remove(neighbor)
                            stack.append(neighbor)
            islands.append((area, island))
        islands.sort(key=lambda entry: entry[0], reverse=True)
        kept, discard = 0, []
        for _, island in islands:
            if kept + len(island) <= budget:
                kept += len(island)
            else:
                discard.extend(island)
        bmesh.ops.delete(bm, geom=discard, context='FACES')
        bm.to_mesh(obj.data)
        bm.free()
    obj.name = 'PineTrunk'

# Add a low-poly central bole: the original branches are disconnected islands
# and aggressive decimation otherwise leaves the lower trunk unrealistically thin.
bark = bpy.data.materials.get('pine_tree_01_bark')
if bark is None:
    bark = next((mat for obj in objects for mat in obj.data.materials if mat), None)
segments = 10
rings = ((0.0, .22), (1.8, .18), (3.8, .12), (5.8, .035))
bole_verts = [(radius * math.cos(2 * math.pi * i / segments),
               radius * math.sin(2 * math.pi * i / segments), z)
              for z, radius in rings for i in range(segments)]
bole_faces = []
for ring in range(len(rings) - 1):
    for i in range(segments):
        a = ring * segments + i
        b = ring * segments + (i + 1) % segments
        bole_faces.append((a, b, b + segments, a + segments))
bole_mesh = bpy.data.meshes.new('PineBole')
bole_mesh.from_pydata(bole_verts, [], bole_faces)
bole_mesh.update()
bole_uv = bole_mesh.uv_layers.new(name='UVMap')
for poly in bole_mesh.polygons:
    for loop in poly.loop_indices:
        vid = bole_mesh.loops[loop].vertex_index
        i = vid % segments
        # Avoid a wrap across the final segment.
        u = (segments if poly.index % segments == segments - 1 and i == 0 else i) / segments
        bole_uv.data[loop].uv = (u, bole_verts[vid][2] / 5.8)
if bark:
    bole_mesh.materials.append(bark)
bole = bpy.data.objects.new('PineBole', bole_mesh)
bpy.context.collection.objects.link(bole)
bpy.ops.object.select_all(action='DESELECT')
objects[0].select_set(True)
bole.select_set(True)
bpy.context.view_layer.objects.active = objects[0]
bpy.ops.object.join()

# The twig atlas includes several other UV islands, and its alpha is opaque
# outside the black area around the twig. Mask that area while extracting it;
# otherwise unrelated parts of the atlas become visible as rectangular cards.
color = bpy.data.images.load(twig_diff, check_existing=False)
alpha = bpy.data.images.load(twig_alpha, check_existing=False)
if tuple(color.size) != tuple(alpha.size) or color.size[0] != 1024 or color.size[1] != 1024:
    raise RuntimeError('Expected matching 1024 x 1024 Poly Haven twig atlases')
cp, ap = color.pixels[:], alpha.pixels[:]
w, h = 240, 460
out = array('f', [0.0]) * (w * h * 4)
# Polygon enclosing the upper-left twig image, in top-down image coordinates.
polygon = [(0, 0), (210, 0), (237, 85), (237, 285), (194, 450), (40, 460), (0, 390)]
def inside(x, y):
    hit = False
    j = len(polygon) - 1
    for i, (xi, yi) in enumerate(polygon):
        xj, yj = polygon[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit
for y in range(h):
    # Blender images are stored bottom-up.
    src_y = 1024 - h + y
    top_y = h - 1 - y
    for x in range(w):
        dst = (y * w + x) * 4
        src = (src_y * 1024 + x) * 4
        out[dst:dst + 3] = array('f', cp[src:src + 3])
        out[dst + 3] = ap[src] if inside(x, top_y) else 0.0
needle_image = bpy.data.images.new('PineNeedlesRGBA', width=w, height=h, alpha=True)
needle_image.pixels.foreach_set(out)
needle_image.file_format = 'PNG'
needle_image.filepath_raw = str(Path(output).with_name('_pine_needles_tmp.png'))
needle_image.save()
needle_image.pack()
Path(needle_image.filepath_raw).unlink(missing_ok=True)

material = bpy.data.materials.new('pine_twig_alpha')
material.use_nodes = True
material.diffuse_color = (0.32, 0.4, 0.22, 1.0)
material.use_backface_culling = False
material.surface_render_method = 'DITHERED'
material.alpha_threshold = 0.5
bsdf = material.node_tree.nodes.get('Principled BSDF')
tex = material.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = needle_image
material.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
material.node_tree.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
bsdf.inputs['Roughness'].default_value = 0.95

rng = random.Random(4711)
vertices, faces, uvs = [], [], []
for _ in range(900):
    available = [i for i, level in enumerate(levels) if level]
    if not available:
        break
    i = rng.choice(available)
    p = rng.choice(levels[i]).copy()
    # A tuft clusters around its source branch, with irregular outward direction.
    radial = Vector((p.x, p.y, 0.0))
    if radial.length < 0.01:
        radial = Vector((1, 0, 0))
    radial.normalize()
    p += Vector((rng.uniform(-.17, .17), rng.uniform(-.17, .17), rng.uniform(-.14, .14)))
    axis = (radial * rng.uniform(.45, 1.0) + Vector((0, 0, rng.uniform(.2, .9)))).normalized()
    # Rotate the plane around its length to avoid the four-card billboard look.
    cross = axis.cross(Vector((0, 0, 1)))
    if cross.length < 0.01:
        cross = Vector((1, 0, 0))
    cross.normalize()
    other = axis.cross(cross).normalized()
    angle = rng.uniform(0, math.tau)
    across = cross * math.cos(angle) + other * math.sin(angle)
    length = rng.uniform(.75, 1.35)
    width = length * w / h
    start = p - axis * (length * .18)
    end = start + axis * length
    v = len(vertices)
    vertices.extend((start - across * width * .5, start + across * width * .5,
                     end + across * width * .5, end - across * width * .5))
    faces.append((v, v + 1, v + 2, v + 3))
    uvs.extend(((0, 0), (1, 0), (1, 1), (0, 1)))
if not vertices:
    raise RuntimeError('No branch vertices available for needle placement')
mesh = bpy.data.meshes.new('PineNeedleCards')
mesh.from_pydata(vertices, [], faces)
mesh.update()
uv_layer = mesh.uv_layers.new(name='UVMap')
for poly in mesh.polygons:
    for loop_index in poly.loop_indices:
        uv_layer.data[loop_index].uv = uvs[mesh.loops[loop_index].vertex_index]
mesh.materials.append(material)
foliage = bpy.data.objects.new('PineNeedles', mesh)
bpy.context.collection.objects.link(foliage)

Path(output).parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=output, export_format='GLB', export_apply=True,
                          export_texcoords=True, export_normals=True,
                          export_materials='EXPORT')
print('Mobile pine built:', output, 'trunk faces:',
      sum(len(o.data.polygons) for o in objects), 'needle triangles:', len(faces) * 2)
