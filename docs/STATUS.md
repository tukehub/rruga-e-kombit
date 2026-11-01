# Delivery status — 2026-11-01

## Milestone 1: Tirana and native Android delivery

- Implemented: native scene flow, real Tirana OSM/DEM track, all car loading,
  tilt/touch controls, immersive sensor landscape, keep-screen-on, native export.
- Verified locally: Godot 4.4.1 import, menu/race/results/retry/quit integration,
  two signed native Gradle APK exports (version codes 1 and 2), with readable
  manifests and matching package/architecture/orientation. The APK certificate
  was compared against the existing keystore certificate and matches exactly.
- Packaging: Godot 4.4.1 direct export produced incorrectly typed Vulkan manifest
  attributes. Switched to the matching official Gradle template with JDK 17 /
  SDK 34; strict aapt manifest, arm64, activity, version and signature checks pass.
- CI changed from Capacitor to checksum-verified Godot and matching templates,
  native tests, signed export and fixed-name release asset/versioning.
- GitHub release 1.0.15 published successfully after fixing SDK setup: the Android
  action's default `tools` package is retired; explicitly request `platform-tools`.
  Failed run: https://github.com/tukehub/rruga-e-kombit/actions/runs/41335494256
  Successful retry: https://github.com/tukehub/rruga-e-kombit/actions/runs/41335883587
- Outstanding: install and validate the native release on a physical phone.

## Milestone 2: cars, combat and race flow

- Six original models already contain 30,320–32,496 triangles and separate spinning
  wheels. Car material/loading code was already present; stale README TODOs removed.
- Fixed disconnected FxVisual, invalid double-parenting of effect meshes, missing
  nitro exhaust visuals and moving real street lights. All eight powers are tested.
- Added pause/focus input clearing and audio shutdown cleanup. All six drivers and
  five rivals remain in one data list; race balance and AI are preserved.
- Renamed the off-roader and van display names to Murrani 4x4 and Korrieri i Linjës;
  stable IDs and model paths are retained for saved selections.
- Verified: complete simulations at all three difficulties, model geometry/wheels,
  all eight item consumption paths, effect construction/cleanup and actual scene loop.
- Rendered rainy Tirana successfully under Forward+ with software Vulkan. Art remains
  an indie procedural treatment; no claim of matching Asphalt production assets.

## Milestone 3: cities, landmarks, weather and quality

- Added original simplified landmark meshes for all configured anchor types.
  Tirana's named landmarks are 26–99 m from its route. All six cities now have
  processed datasets and landmark anchors; these are simplified original models.
- Added smooth HDRI, sun, fog, ambient, wetness and reflection transitions, with a
  persistent Albanian setting. Road/terrain/buildings, lamps, cars and tyre grip
  follow weather changes. Drying switches rain/reflections back off.
- Existing GPU/RAM automatic quality selection and low/medium/high presets retained.
- Fixed terrain chunk transforms so distance detail selection uses each chunk's
  centre; medium uses a shorter high-detail range. Added OSM side-road mesh export.
- Resolved the network blocker: OSM and Copernicus downloads succeeded for all
  six cities. Overpass needed one retry after a 502. Raw sources stay in the
  ignored cache; processed terrain, buildings, side roads, props and tracks ship.
- Corrected offshore/dead-end waypoints and removed detours that caused street
  reuse. The exporter now rejects routes that revisit nodes. Track lengths:
  Tiranë 4.89 km, Vlorë 2.10 km, Berat 5.55 km, Gjirokastër 3.06 km,
  Shkodër 8.61 km, Tetovë 4.75 km.
- Fixed hillside terrain crossing the road: carve all supporting grid corners
  below the lowest nearby road height. All six terrain checks report zero ground
  intrusion across the carriageway and no far mesh underneath the track.
- Verified locally: pipeline regression and six terrain checks pass; Godot 4.6.3
  import, 18 full simulations, six production world loads and the scene-flow test
  pass. Release CI remains pinned to Godot 4.4.1 and validates that engine too.
  In-game visual approval of the five new cities,
  particularly sea/lake/mountain horizons and landmark placement, remains open.

## Milestone 4: polish, credits and performance

- Full Godot MIT and font OFL texts added to existing Albanian credits; TXT files
  explicitly included in exports. OSM, Copernicus and Poly Haven credits retained.
- Added benchmark build/export support with warm-up and hardware-labelled JSON.
- Instrumentation check: Linux llvmpipe software Vulkan, Forward+, medium,
  1364×1024, 3 sampled frames: mean 767.41 ms, p95 791.86 ms. This two-second run
  checks data collection only. It is neither a phone benchmark nor evidence that
  the A56 performance goal is met. Initial high-preset software rendering was too
  expensive for a useful interactive test; high-on-S25 also remains unmeasured.
- REQUIRED EXTERNAL VALIDATION: sustained rain/combat races on A56, S25 FE and S25
  Ultra, target frame budgets, thermal behaviour, accelerometer orientation,
  simultaneous touch input, pause/resume, audio and update-over-existing-install.
  Tune presets from those measurements and capture the Godot remote profiler.
- Legacy application removal is deferred until the native APK is published and
  validated. Existing key path is retained in all cases.
