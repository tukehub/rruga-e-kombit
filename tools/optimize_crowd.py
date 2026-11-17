"""Batch-optimize spectator models for the points-mode crowd.

Run headless from the repository root:

    blender --background --factory-startup --python tools/optimize_crowd.py

Optional arguments after `--`:
    --src DIR        source folder (default raw_assets/crowd)
    --out DIR        output folder (default godot/assets/models/crowd)
    --tris N         target triangles per character (default 2000)
    --texture N      texture size in pixels (default 512)
    --height M       standing height in metres (default 1.75)

For every .glb/.gltf/.fbx/.obj in the source folder this:
  1. imports it into an empty scene;
  2. freezes a skinned character in the most relaxed (arms-down) pose of its
     animation, then drops rigs, actions, cameras, lights and empties;
  3. joins all meshes into one, normalises it to `height` metres, origin at
     the soles (centred), facing Blender -Y (glTF / Godot +Z);
  4. decimates it (COLLAPSE, UV-delimited, triangulated) to ~`tris` triangles;
  5. shrinks every texture to `texture` x `texture` and drops normal maps;
  6. exports <name>_opt.glb (JPEG textures, no animation or skin).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
EXTENSIONS = {".glb", ".gltf", ".fbx", ".obj"}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--src", default=str(ROOT / "raw_assets" / "crowd"))
    p.add_argument("--out", default=str(ROOT / "godot" / "assets" / "models" / "crowd"))
    p.add_argument("--tris", type=int, default=2000)
    p.add_argument("--texture", type=int, default=512)
    p.add_argument("--height", type=float, default=1.75)
    return p.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_model(path: Path) -> None:
    ext = path.suffix.lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))


def mesh_objects() -> list[bpy.types.Object]:
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def tri_count(mesh: bpy.types.Mesh) -> int:
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def world_width(objs: list[bpy.types.Object]) -> float:
    """Horizontal extent of the evaluated meshes: small = arms down."""
    dg = bpy.context.evaluated_depsgraph_get()
    xs: list[float] = []
    for o in objs:
        ev = o.evaluated_get(dg)
        m = ev.to_mesh()
        mw = o.matrix_world
        xs.extend((mw @ v.co).x for i, v in enumerate(m.vertices) if i % 7 == 0)
        ev.to_mesh_clear()
    return max(xs) - min(xs) if xs else 0.0


def relaxed_frame(objs: list[bpy.types.Object]) -> int:
    """Animation frame with the narrowest silhouette (no T-pose spectators)."""
    scene = bpy.context.scene
    actions = list(bpy.data.actions)
    if not actions:
        return scene.frame_current
    start, end = (int(f) for f in actions[0].frame_range)
    best, best_w = start, float("inf")
    for f in range(start, end + 1, max(1, (end - start) // 24)):
        scene.frame_set(f)
        w = world_width(objs)
        if w < best_w:
            best, best_w = f, w
    scene.frame_set(best)
    print(f"  pose: frame {best} (width {best_w:.2f} m)")
    return best


def bake_single_mesh(name: str) -> bpy.types.Object:
    """Evaluate every mesh in its posed, world-space form and join them."""
    objs = mesh_objects()
    if not objs:
        raise RuntimeError("no mesh in file")
    relaxed_frame(objs)
    dg = bpy.context.evaluated_depsgraph_get()
    baked: list[bpy.types.Object] = []
    for o in objs:
        mesh = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        mesh.transform(o.matrix_world)
        for slot_index, slot in enumerate(o.material_slots):
            if slot_index < len(mesh.materials):
                mesh.materials[slot_index] = slot.material
        baked.append(bpy.data.objects.new(o.name + "_baked", mesh))
    # Drop everything that came with the file: rigs, empties, cameras, lights, actions.
    for o in list(bpy.data.objects):
        if o not in baked:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    for arm in list(bpy.data.armatures):
        bpy.data.armatures.remove(arm)
    for o in baked:
        bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in baked:
        o.select_set(True)
    bpy.context.view_layer.objects.active = baked[0]
    if len(baked) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    obj.vertex_groups.clear()
    for key in list(obj.data.shape_keys.key_blocks) if obj.data.shape_keys else []:
        obj.shape_key_remove(key)
    return obj


def normalise(obj: bpy.types.Object, height: float) -> None:
    pts = [v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    s = height / (hi.z - lo.z)
    # Centre on the feet: the footprint of the lowest 5 % of the body.
    sole = [p for p in pts if p.z < lo.z + (hi.z - lo.z) * 0.05]
    cx = (min(p.x for p in sole) + max(p.x for p in sole)) * 0.5
    cy = (min(p.y for p in sole) + max(p.y for p in sole)) * 0.5
    for v in obj.data.vertices:
        v.co = Vector(((v.co.x - cx) * s, (v.co.y - cy) * s, (v.co.z - lo.z) * s))
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    obj.data.update()


def mark_uv_seams(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.seams_from_islands(mark_seams=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def decimate(obj: bpy.types.Object, target: int) -> int:
    start = tri_count(obj.data)
    if start <= target:
        return start
    mark_uv_seams(obj)
    ratio = target / start
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.use_collapse_triangulate = True
    mod.delimit = {"UV", "SEAM"}
    # Collapse overshoots a little on seam-heavy meshes: correct a few times.
    for _ in range(6):
        mod.ratio = min(1.0, ratio)
        dg = bpy.context.evaluated_depsgraph_get()
        ev = obj.evaluated_get(dg)
        tris = len(ev.data.polygons)
        if abs(tris - target) <= target * 0.03:
            break
        ratio *= target / max(1, tris)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    return tri_count(obj.data)


def shrink_textures(obj: bpy.types.Object, size: int) -> None:
    for slot in obj.material_slots:
        mat = slot.material
        if mat is None or not mat.use_nodes:
            continue
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        # A 512 px crowd member gains nothing from a normal map: drop it.
        for n in list(nodes):
            if n.type == "NORMAL_MAP":
                for link in list(n.outputs[0].links):
                    links.remove(link)
                for link in list(n.inputs["Color"].links):
                    if link.from_node.type == "TEX_IMAGE":
                        nodes.remove(link.from_node)
                nodes.remove(n)
        for n in nodes:
            if n.type == "TEX_IMAGE" and n.image is not None:
                img = n.image
                if img.size[0] > size or img.size[1] > size:
                    img.scale(size, size)
                img.file_format = "JPEG"


def export(obj: bpy.types.Object, path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    kwargs = dict(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True,
        export_yup=True, export_animations=False, export_skins=False, export_morph=False,
        export_cameras=False, export_lights=False, export_tangents=False,
        export_image_format="JPEG")
    try:
        bpy.ops.export_scene.gltf(**kwargs, export_image_quality=82)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)


def process(path: Path, out_dir: Path, args: argparse.Namespace) -> dict:
    reset_scene()
    name = path.stem
    print(f"== {path.name}")
    import_model(path)
    source_tris = sum(tri_count(o.data) for o in mesh_objects())
    obj = bake_single_mesh(name)
    normalise(obj, args.height)
    tris = decimate(obj, args.tris)
    shrink_textures(obj, args.texture)
    out = out_dir / f"{name}_opt.glb"
    export(obj, out)
    dims = obj.dimensions
    print(f"  {source_tris} -> {tris} tris, {dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} m, {out.stat().st_size / 1024:.0f} KiB")
    return {"name": name, "source_tris": source_tris, "tris": tris, "bytes": out.stat().st_size}


def main() -> None:
    args = parse_args()
    src, out_dir = Path(args.src), Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in src.iterdir() if p.suffix.lower() in EXTENSIONS) if src.is_dir() else []
    if not files:
        print(f"CROWD: no models in {src}")
        return
    results = []
    for f in files:
        try:
            results.append(process(f, out_dir, args))
        except Exception as e:  # keep going: one bad file should not stop the batch
            print(f"  FAILED {f.name}: {e}")
    print(f"CROWD: {len(results)}/{len(files)} optimised -> {out_dir}")
    for r in results:
        print(f"CROWD {r['name']}: {r['source_tris']} -> {r['tris']} tris, {r['bytes'] / 1024:.0f} KiB")


main()
