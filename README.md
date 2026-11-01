# Kafshim asfalti (Godot 4 rewrite of "Vortex")

Arcade combat racer for Android, rebuilt as a native Godot 4 project. The previous
Three.js/Capacitor WebView game still lives in `src/`, `android/` and `build.py`; the
new game is under `godot/` with its data pipeline under `tools/`.

Status: **work in progress — stopped before Milestone 1 was finished.** Nothing from
the rewrite has been committed yet; everything under `godot/`, `tools/`, `docs/` is
untracked in the working copy.

---

## What has been done

### Planning
- `docs/PLAN.md` — architecture, asset/licence table, OSM/DEM pipeline description,
  milestone breakdown.
- Engine fixed at **Godot 4.x, Forward+ (Vulkan)**. Package name `al.tukehub.rruga` and
  the existing keystore `android/app/rruga.jks` are kept.

### Data pipeline (`tools/`)
- `tools/pipeline/fetch_osm.py` — downloads OSM extracts (highway, building, height/levels,
  landuse) for a city bounding box.
- `tools/pipeline/fetch_dem.py` — downloads Copernicus DEM tiles for the same area.
- `tools/pipeline/build_city.py` (+ `cities.py`, `common.py`, `glb.py`) — turns OSM + DEM
  into Godot-ready data: track centreline (`track.json`), extruded buildings
  (`buildings.glb`), near/far terrain heightmaps (`terrain_near.bin`, `terrain_far.bin`,
  `terrain.json`), a splat map (`splat.png`) and street props (`props.json`).
- `tools/fetch_assets.py` — pulls CC0 textures/HDRIs from Poly Haven; `tools/hdri_stats.py`,
  `tools/hdr_io.py` are helpers for HDRI exposure calibration.
- `tools/gen_cars.py` — procedural PBR car generator (body, glass, emissive lights,
  separate spinning wheel meshes) → `godot/assets/cars/*.glb`.
- `tools/gen_sfx.py` — synthesises the engine/tyre/impact/pickup sound set →
  `godot/assets/sfx/` (58 files).

### Generated assets in repo (`godot/assets/`, ~77 MB)
- `cities/tirane/` — the only processed city so far (track, buildings, terrain, splat, props).
- `cars/` — six procedural cars: `benxi`, `uragani`, `gelendvagen`, `sprinteri`,
  `kercyesi`, `shigjeta` (~1 MB each; well under the 25k–60k triangle target, see TODO).
- `hdri/`, `textures/`, `fonts/`, `sfx/`.

### Godot project (`godot/`)
- `project.godot` — Forward+, landscape, autoloads `Data`, `Settings`, `Quality`, `Sfx`, `Game`.
- `export_presets.cfg` — Android export preset (not yet verified against the keystore / CI).
- **Sim** (`scripts/sim/`): `race.gd`, `car_state.gd`, `track.gd` — GDScript port of
  `src/01_data.js` + `src/03_sim.js`: car physics, 8 power-ups with original balance,
  bot AI, rubber-banding, difficulty levels, lap counting, position tracking.
  Headless tests in `tests/sim_test.tscn`, profiling in `tests/sim_prof.tscn`.
- **Data** (`scripts/data/data.gd`): single list of cars (names, model paths, stats),
  bots, power-ups, difficulties, cities.
- **World** (`scripts/world/`): `terrain.gd` (heightmap mesh + `terrain.gdshader` splat),
  `road_mesh.gd` (road ribbon + `road.gdshader` with wet/dry blend), `buildings.gd`
  (`facade.gdshader` with emissive windows), `props.gd` (poles, signs), `sky_env.gd`
  (HDRI sky, sun, day/night/rain presets, volumetric fog).
- **Rendering/quality** (`scripts/game/quality.gd`): low/medium/high presets controlling
  shadows (PSSM 2 splits ~110 m medium, 4 splits ~220 m high), SDFGI, SSAO, SSR, bloom,
  exposure. Shadows follow the player car. Sun/shadow and SDFGI calibration was done via
  headless render bisection (angular-distance fix, SDFGI energy settled around 0.35).
- **Game flow**: `main.tscn`/`main.gd` → `menu.tscn` (`ui/menu.gd`) → `race.tscn`
  (`game/race_scene.gd`, `chase_cam.gd`, `race_input.gd`, `car_visual.gd`,
  `pickup_visual.gd`, `fx_visual.gd`) → `results.tscn` (`ui/results.gd`).
- **Input** (`race_input.gd`): tilt steering with sensitivity/invert, touch-pad fallback,
  right half gas / left half brake (brake + steer = drift), centre fire-forward and
  fire-backward buttons.
- **UI**: Albanian HUD (`ui/hud.gd`) and shared theme (`ui/ui_theme.gd`); settings
  persistence in `game/settings.gd`; SFX mixer with engine/tyres/impacts/pickups buses in
  `game/sfx.gd`.
- `tests/visual_test.tscn` — headless screenshot harness used for all rendering checks.

---

## What is left to do

### To reach a basic working build (Milestone 1, ~3–4 h)
- [x] World scripts wired in `race_scene.gd` and verified: headless `--import` parses
  clean; `--scene=race --auto --laps=1 --env=day|night --shots=30,60,90` renders Tirana
  (terrain, road, buildings, props, sky, cars, HUD) in day and night with no script
  errors. Fixed the un-carved far horizon mesh (Copernicus DSM) poking through the road
  on ~28 % of the track (up to +5.4 m): `terrain.gd._build_far` now omits far quads
  inside the near-grid footprint (`tools/check_terrain.py` confirms 0 % far mesh under
  the track). Desktop frame time at 1280x720 high preset ≈ 66 ms avg (SDFGI on this
  machine; needs on-device measurement).
- [ ] Run one full race end-to-end: menu → race → results → menu loop.
- [ ] Hook the generated car GLBs into `car_visual.gd` (wheel spin, lights, glass) and
  verify all six load.
- [ ] Verify tilt + touch zones on a real device.
- [ ] **Replace `.github/workflows/apk.yml`** — it still builds the old Capacitor app.
  New job: install Godot headless + export templates, `godot --headless --export-release
  Android`, sign with `android/app/rruga.jks` (alias/passwords from secrets),
  `versionCode = run_number`, `versionName = 1.0.<run_number>`, publish as
  `rruga-e-kombit.apk` on the latest release.
- [ ] Check `export_presets.cfg`: package `al.tukehub.rruga`, landscape sensor, immersive,
  keep-screen-on, Vulkan/Forward+ on Android.
- [ ] Commit the rewrite (nothing is committed yet).

### Milestone 2 — cars, bots, power-ups visuals
- [ ] Raise car detail toward 25k–60k triangles (currently low-poly procedural); PBR
  materials pass, proper glass shader, emissive light meshes.
- [ ] Visuals for all 8 power-ups in race (missile, lightning, barge, mine, shock,
  nitro, shield, repair) — sim is done, `fx_visual.gd` covers only part of them.
- [ ] Bot name tags, minimap, position/lap HUD polish.

### Milestone 3 — cities, weather, presets
- [ ] Run the pipeline for Vlorë, Berat, Gjirokastër, Shkodër, Tetovë (only Tirana exists).
- [ ] Low-poly landmarks: Skanderbeg statue, Pyramid, Blloku, Mother Teresa Square;
  Independence Monument + promenade; Berat castle + Mangalem/Gorica; Gjirokastër castle;
  Rozafa over Lake Shkodra; Painted Mosque with Sharr mountains.
- [ ] Per-city HDRI/horizon (sea for Vlorë, mountains for Berat/Tetovë, flat for Tirana).
- [ ] Dynamic weather: rain → wet road + SSR, time-of-day cycle (presets exist, no runtime
  transition yet).
- [ ] Auto quality preset from device RAM / GPU tier on first launch (presets exist,
  auto-detect is not implemented).

### Milestone 4 — polish and release
- [ ] On-device profiling: A56 medium < 16 ms, S25 Ultra high; Godot profiler report.
  Decide whether SDFGI stays on medium or is replaced by lighter GI.
- [ ] Credits screen (Albanian) with OSM ODbL attribution, Copernicus DEM, Poly Haven
  CC0, font licences.
- [ ] Remove the legacy web game (`src/`, `www/`, `android/` Capacitor wrapper, `build.py`,
  `test/`) once the Godot APK is published.
- [ ] Clean stray logs from the repo root (`import.log`, `menu.log`, `osm_fetch.log`,
  `race.log`, `results.log`).

---

## Running locally
- Open `godot/` in Godot 4 (Forward+). Main scene is `scenes/main.tscn`.
- Regenerate a city: `python tools/pipeline/fetch_osm.py tirane && python
  tools/pipeline/fetch_dem.py tirane && python tools/pipeline/build_city.py tirane`.
- Regenerate cars / SFX: `python tools/gen_cars.py`, `python tools/gen_sfx.py`.
- Headless sim test: `godot --headless --path godot tests/sim_test.tscn`.

## Install (current published build)
The release link still serves the **old** web-based APK until the CI workflow is replaced:
https://github.com/tukehub/rruga-e-kombit/releases/latest/download/rruga-e-kombit.apk
