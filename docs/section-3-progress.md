# Section 3 graphics progress

Working branch: `codex/section-3-graphics`. Base: `1314c9a`.

## Checkpoint: work started (2026-11-16)

Read the README and current renderer/visual tests. Section 3 is pending.
Implement items in README order, keeping simulation code node-free and
deterministic. Commit and push each tested checkpoint to this branch.

- **3.1 — implemented and tested:** masked clearcoat/metallic flakes and
  budgeted bot headlights, preserving player headlights and emissive lamps.
- **3.2 — next:** pooled GPU driving particles and a quality-aware speed post
  effect, with regression coverage for state changes and bounded allocation.
- **3.3–3.8 — pending:** reflections, OSM dressing, road decals, facade depth,
  baked lighting/culling, and colour grading.

Validation: `godot --headless --path godot --editor --import`, then
`python3 tools/run_tests.py --godot godot`. Rendered checks should exercise
Mobile and Forward+ where Vulkan is available. Physical phone frame-time
claims remain blocked on measurements from the actual devices.

Resume by reading this file, `README.md` section 3, and `git log`/`git status`.
Do not merge to `main`; the user requested a separate branch.

## Checkpoint: 3.1 (2026-11-16)

- Atlas paint now uses metallic 0.6 / roughness 0.25, masked clearcoat and
  procedural flake normals that fade below a pixel. The public GLB's separate
  paint surfaces get the same finish and a shared procedural normal texture.
- Damage dulls the finish; repair restores it. Flakes disable on low or under
  sustained pressure through `Quality.p.paint_flakes`.
- All six cars have emissive lamps. The nearest eligible bots share at most
  `Quality.p.fx_light_limit` spots, within 70 m. Two player spots are reserved;
  total spots stay below Mobile's eight-per-mesh ceiling. Existing omni-light
  shares are unchanged. Lights are allocated once and reassigned in place.
- **Passed:** complete `tools/run_tests.py` suite on Godot 4.4.1, including the
  new `car_paint_lights` scene on Mobile and Forward+. Rendered Vulkan check
  is in progress; phone profiling remains pending.
- Environment: `godot` on PATH is 4.6.3, so use
  `/workspace/godot441/Godot_v4.4.1-stable_linux.x86_64`. Scratch wrapper
  `work/godot` sets writable `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and
  `XDG_CACHE_HOME` under `work/`. This is untracked machine-local setup.
