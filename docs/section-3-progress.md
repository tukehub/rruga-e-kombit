# Section 3 graphics progress

Working branch: `codex/section-3-graphics`. Base: `1314c9a`.

## Checkpoint: work started (2026-11-16)

Read the README and current renderer/visual tests. Section 3 is pending.
Implement items in README order, keeping simulation code node-free and
deterministic. Commit and push each tested checkpoint to this branch.

- **3.1 — in progress:** masked clearcoat/metallic flakes and budgeted bot
  headlights, preserving player headlights and emissive lamp visibility.
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
