# Section 3 graphics progress

Working branch: `codex/section-3-graphics`. Base: `1314c9a`.

## Checkpoint: work started (2026-11-16)

Read the README and current renderer/visual tests; section 3 was pending at
the start. Implement items in README order, keeping simulation code node-free
and deterministic. Commit and push each tested checkpoint to this branch.
Current status:

- **3.1 — implemented and tested:** masked clearcoat/metallic flakes and
  budgeted bot headlights, preserving player headlights and emissive lamps.
- **3.2 — implemented and tested:** pooled GPU driving particles and a
  quality-aware speed post effect, with regression coverage for state changes
  and bounded allocation.
- **3.3 — implemented, validation in progress:** player/landmark reflections,
  HDRI garage and reduced ambient fill.
- **3.4–3.8 — pending:** OSM dressing, road decals, facade depth,
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
  new `car_paint_lights` scene on Mobile and Forward+. The Mobile software
  Vulkan car-close render also passed and was visually inspected; phone
  profiling remains pending.
- Environment: `godot` on PATH is 4.6.3, so use
  `/workspace/godot441/Godot_v4.4.1-stable_linux.x86_64`. Scratch wrapper
  `work/godot` sets writable `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and
  `XDG_CACHE_HOME` under `work/`. This is untracked machine-local setup.

## Checkpoint: 3.2 implementation (2026-11-16)

- `FxVisual.POOL_CAPS` now also bounds 6 smoke, 3 exhaust, 6 spray and 3 scrape
  GPU emitters (438 particles maximum). `driving_particles.gd` builds them
  once, using shared meshes/process materials. No runtime emitter creation.
- Medium draws effects on up to two nearby cars; high on three, with the
  player first. Low and pressure stages 2/3 disable them. World-space trails
  follow rendered rear-wheel/exhaust/side positions; wet roads replace smoke
  with spray. Stopping, jumping, wrecking, distance, teleport/reuse and finish
  are handled without changing simulation state or its RNG.
- A peripheral radial blur, vignette and slight chromatic offset use speed
  ratio and nitro. The screen-texture pass sits below HUD, controls and the
  mirror, ignores input, and disables on low/pressure, pause, wreck and finish.
  Retry creates a fresh inactive pass.
- **Passed so far:** dedicated Mobile `speed_feedback` regression and the
  existing combined visual-performance stress test. Full runner and rendered
  Mobile/Forward+ checks are running; inspect their results before marking
  this checkpoint fully validated.
- Render check: `godot --path godot --rendering-method mobile --fixed-fps 60
  res://tests/graphics_visual.tscn` (repeat with `forward_plus`). It exercises
  production race/HUD integration, the atlas paint shader, drift, wet boost
  and low quality, and writes screenshots to `user://shots/`.
- On this machine the test display is Xorg `:97`; software Vulkan uses
  `VK_ICD_FILENAMES=/workspace/setup/lavapipe.json`. Scratch logs are in
  `work/section-3.2-tests.log`, `work/graphics-mobile.log`, and
  `work/graphics-forward.log`.

## Validation and handoff (2026-11-16)

- The full Godot 4.4.1 runner passed: **26 scene launches**, including all
  existing simulations, city/race flow, controls, string-table and performance
  checks; paint/lights, speed feedback, renderer truth and profile launches
  run on both Mobile and Forward+. No unexpected runtime errors.
- Both software Vulkan render paths completed drift, wet-boost and low
  captures. Paint/atlas shaders compile, particles appear, and UI stays sharp.
  Low reports zero driving emitters and zero post strength. Final repeats
  also check the shader's low-quality branch (flake calculations are skipped).
- Fixed the optional visual harness to resume after window focus loss; the
  production game's focus-loss pause remains intact. Render logs from the
  final shader check use `work/graphics-{mobile,forward}-final.log`.
- The initial plan, tested 3.1 and implemented 3.2 were pushed separately
  (`b544d46`, `c087cc0`, `aa2f42e`). A final validation/docs checkpoint follows.
- At this checkpoint 3.3 was next. Its implementation and final validation
  are recorded below; no phone performance claim or release was made.

## Checkpoint: 3.3 implementation (2026-11-16)

- Added `race_reflections.gd`: one medium+ player probe follows in spaced
  UPDATE_ONCE captures (18 m movement threshold, 0.5 s interval; 1 s under
  stage-1 pressure). Teleports/large gaps recenter immediately. High adds
  three static probes on the streets by the National Museum, Pyramid and
  Polytechnic. Low and pressure stages 2/3 disable probes; stage 1 removes
  landmark probes. Compatibility requests none.
- Static scenery has a dedicated capture layer. Cars, pickups, combat and
  weather do not enter the city captures. Cubemaps have no shadows, use
  coarser mesh LOD, and share a 128 px atlas with eight slots. At most four
  city probes can affect the road, below Mobile's eight-per-mesh limit.
- Weather changes and transition milestones invalidate captures; landmark
  refresh requests are staggered. Retry preserves world probes and resets
  the player anchor. Quality snapshots report the effective probe budgets.
- Garage uses the existing CC0 daylight HDRI, a static probe and a glossier
  floor. Its rotating car is excluded from capture to avoid self-reflections.
  The glossy floor reflects its environment; it is not a planar car mirror.
  Garage viewport/environment/probe budgets now respond to live changes.
- Reduced daytime flat ambient fill (day: 0.5 → 0.325); night retains a 0.48
  minimum. Weather interpolation uses the same adjusted endpoints.
- **Passed so far:** new Mobile `reflections` regression (budget, layer mask,
  reuse, movement, weather, retry, garage). Full runner and software Vulkan
  captures are in progress. Logs: `work/section-3.3-tests.log` and
  `work/reflections-{mobile,forward}.log`.
- Optional rendered check: `godot --path godot --rendering-method mobile
  --fixed-fps 60 res://tests/reflections_visual.tscn` (repeat Forward+).
  Captures garage, day without/with probes, high landmark, night and low.

## Resume and visual review (2026-11-20)

- Recovered checkpoint `4c662d7`; the saved full-runner log contains all 28
  scene launches with no unexpected errors, including both reflection tests.
  Both Vulkan render paths had produced all six captures without errors.
- Visual inspection prompted two refinements: preserve the original dark
  preset ambient fill and use full probe intensity for readable paint at
  night; move the garage camera aim slightly to keep the rotating car in view.
- Final verification is running in `work/section-3.3-final-tests.log` and
  `work/reflections-{mobile,forward}-final.log` before the final push.
