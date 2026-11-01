# Kafshim asfalti — Godot 4 rewrite plan

Original architecture decisions (retained; see STATUS.md for current verification):
- **Engine: Godot 4.4.1 stable** (use matching official binary and export templates). GDScript only; matching official Android Gradle export template (see STATUS.md for the direct-export manifest issue).
- **Renderer: Forward+ (Vulkan)** on Android (`rendering_method.mobile = forward_plus`). Low/medium presets switch off SDFGI/SSR/volumetrics; high keeps everything.
- **Cars: procedural** (`tools/pipeline/gen_cars.py` → GLB). Kenney.nl is unreachable from the build network and Sketchfab needs an account; procedural models are licence-clean and 25k–60k tris. Swapping in a downloaded model is a one-line change in `cars.gd`.
- Package name, keystore (`android/app/rruga.jks`, alias `rruga`), workflow file name and release asset name are unchanged so installs update in place and `releases/latest/download/rruga-e-kombit.apk` keeps working.

## 1. Architecture

```
godot/                         Godot 4.4 project (res://)
  project.godot                Forward+, landscape sensor, keep screen on, 60 fps physics
  export_presets.cfg           Android arm64, al.tukehub.rruga, immersive, keystore from env
  scripts/data/                cars.gd · powerups.gd · cities.gd · strings_sq.gd  (data only)
  scripts/sim/                 track.gd · race.gd · car_state.gd  (pure logic, port of 02_track/03_sim)
  scripts/game/                game.gd (state machine) · settings.gd · input_ctl.gd · quality.gd · sfx.gd
  scripts/world/               terrain.gd · road_mesh.gd · city_loader.gd · sky_weather.gd · landmarks.gd
  scripts/cars/                car_visual.gd (wheels, lights, damage, nitro)
  scenes/                      main.tscn · race.tscn · ui/*.tscn
  assets/cars/*.glb            generated cars
  assets/cities/<id>/          track.json · height.png · height.json · buildings.glb · roads.glb · splat.png
  assets/textures/             Poly Haven 1k sets
  assets/hdri/                 Poly Haven skies
  assets/sfx/*.wav             generated effects
  assets/fonts/                Big Shoulders Display, Chakra Petch (OFL)
tools/pipeline/                Python: fetch_osm.py · fetch_dem.py · build_city.py · gen_cars.py · gen_sfx.py · fetch_assets.py
tools/cache/                   downloaded raw data (git-ignored)
legacy/                        old three.js game kept for reference (not built)
```

Simulation stays 1-D along the loop (`s` progress, `d` lateral offset, `yaw` relative to the road) exactly like the web game, so AI, power-ups and balance port 1:1. The track centreline now comes from real OSM streets instead of hand-placed control points; the frame (`pos/tangent/normal/curv`) is the same interface.

Rendering: `Track` → `RoadMesh` (asphalt + kerbs + shoulders conforming to the DEM), `Terrain` (chunked heightmap mesh, 15 m cells, distance LOD, far ring from the same DEM at 90 m), `CityLoader` (OSM buildings as GLB chunks with a procedural facade shader: windows, night lights, wet reflectance), `Landmarks` (hand-made low-poly), `SkyWeather` (`WorldEnvironment`: HDRI sky, sun, glow with neon threshold, SSAO, SDFGI, SSR, volumetric fog, rain particles + wet roughness driven by one `wetness` uniform).

## 2. Assets and licences

| Asset | Source | Licence | Credit text |
|---|---|---|---|
| Elevation | Copernicus DEM GLO-30 (AWS Open Data `copernicus-dem-30m`) | Free, attribution | "Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018, provided under COPERNICUS by the European Union and ESA" |
| Roads, buildings, land use, water | OpenStreetMap via Overpass API | ODbL 1.0 | "© OpenStreetMap contributors" |
| Terrain textures: `aerial_grass_rock`, `asphalt_02`, `asphalt_04`, `rocky_terrain_02`, `concrete_floor_02`, `cobblestone_floor_08`, `coast_sand_rocks_02`, `rock_face_03` | Poly Haven | CC0 | "Textures: Poly Haven (CC0)" |
| Skies: `kloofendal_48d_partly_cloudy_puresky` (day), `qwantani_dusk_2_puresky` (sunset), `belfast_sunset_puresky` (golden), `satara_night`, `moonless_golf` (night), `kiara_1_dawn` (dusk) | Poly Haven | CC0 | "HDRIs: Poly Haven (CC0)" |
| Six cars (Benxi GT, Uragani V10, Shigjeta RS, Murrani 4x4, Korrieri i Linjës, Kërcyesi GTI) | `gen_cars.py`, this repo | CC0 (ours) | — |
| Landmarks (Skanderbeg statue, Pyramid, Flag Monument, castles, Painted Mosque, …) | `landmarks.gd`, this repo | CC0 (ours) | — |
| Sound effects | `gen_sfx.py`, this repo | CC0 (ours) | — |
| Fonts Big Shoulders Display, Chakra Petch | Google Fonts via `@fontsource` | SIL OFL 1.1 | font names |
| Logo / icon | `assets/` (existing) | ours | — |
| Engine | Godot Engine 4.4.1 | MIT | Godot licence text |

No Google 3D Tiles, no photos. Everything above is reproducible with `python tools/pipeline/<script>.py`.

## 3. OSM / DEM pipeline

1. `fetch_dem.py <city>` — downloads the 1°×1° Copernicus GLO-30 COG tiles covering the city (cached in `tools/cache/dem`), resamples a 4.5 km × 4.5 km window (15 m cells, bilinear) around the city origin into `height.png` (16-bit) + `height.json` (origin lat/lon, metres per pixel, min/max). A second 36 km window at 90 m becomes `far.png` for the mountain horizon.
2. `fetch_osm.py <city>` — one Overpass query per city bbox (highways, buildings with `height`/`building:levels`, landuse, natural, waterway, leisure). Cached raw JSON; retries over three mirrors; polite User-Agent (the earlier 406 came from a missing UA).
3. `build_city.py <city>` —
   - **Track:** the city's waypoints (lat/lon on real streets, in `cities.py`) are routed over the OSM drivable graph with Dijkstra, concatenated into a loop, resampled at 2 m, smoothed, elevation sampled from the DEM and slope-limited (same smoothing as the web `Track`). Self-intersection check + debug map PNG. Output `track.json` (local ENU metres).
   - **Heightmap conforming:** terrain is pulled to the road height inside the corridor so the road never floats or sinks.
   - **Buildings:** footprints → extruded prisms (height = `height` | levels×3.2 | style default), roofs flat, UVs in metres for the facade shader, vertex colour = style tint. Buildings touching the race corridor are removed. Written as GLB in 250 m chunks (frustum culling), ~6–10k buildings per city.
   - **Roads:** non-track highways → flat ribbons on the terrain (width by class), GLB chunks.
   - **Splat:** landuse/natural/water rasterised to `splat.png` (R grass, G urban, B water, A rock) for terrain blending.
   - **Landmarks:** named anchors (lat/lon → local) emitted into `track.json` so `landmarks.gd` places the hand-made models.
4. Processed outputs are committed under `godot/assets/cities/<id>/` (≈ 3–6 MB per city). Raw downloads stay in the git-ignored cache.

## 4. Milestone 1 (this delivery)

- Godot project boots to a menu, starts a race in **Tiranë** on a loop Skanderbeg Square → Bulevardi Dëshmorët e Kombit → Mother Teresa Square → Blloku → back, built from OSM + DEM.
- One car (Benxi GT) with spinning wheels and lights; bots run (the sim is complete) but the content pass for all six cars is Milestone 2.
- Tilt steering (accelerometer, sensitivity, invert) with touch-pad fallback; right half gas, left half brake (brake+steer drifts); centre fire button, second button fires backwards.
- Night Tirana look: HDR glow, emissive windows, street lamps, SSAO (high), wet reflections ready behind the `wetness` uniform.
- GitHub Actions builds a signed release APK on every push to `main` and publishes `rruga-e-kombit.apk` with `versionCode = run_number`, `versionName = 1.0.<run_number>`.

Milestones 2–4 follow the brief: all cars/bots/power-ups/race flow → six cities + weather + presets → polish, profiler pass, credits.
