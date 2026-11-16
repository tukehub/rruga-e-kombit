# Vortex

Native Godot **4.4.1**, GDScript, Vulkan combat racer for Android. Phones run
Godot's Mobile renderer; desktop development runs Forward+.
**Vortex** is the only name used for the game. The strings `rruga-e-kombit`,
`al.tukehub.rruga` and `rruga.jks` survive only as the repository folder,
Android package, keystore and release-asset filenames, because changing those
would break updates to existing installs. Package: `al.tukehub.rruga`; the
fixed release key remains at `android/app/rruga.jks`.

Vortex is being perfected on **daylight Tirana** with the single Vortex GT car
model first; other cities and online play follow (see
[Changes to be made](#changes-to-be-made)). The current build has one shared sports car
for all six drivers, six paint choices with identical performance,
recognizable eagle/lightning/etc power-up badges, larger phone text, explicit
corner pedals and forward/back shooting buttons (forward on top, backward
under it), and always-visible translucent standings with each rival's
distance in metres. Only the six racers are on the street. The middle of the screen stays clear for the road and car.

The main menu starts a Tirana race directly, or a **points round** on the
walled Skanderbeg Square: the "Mënyra" button on the title page switches
between a race and points for 2 or 3 minutes. Ram the others for points
(closing speed × 14), three quick hits raise the multiplier up to ×5, a wreck
you caused pays 300 × the multiplier, and the highest score when the clock
runs out wins. Pickups on the square are ones a car uses on itself: the ram
charge ("Dashi", double points and a hard shove), nitro, shield and repair.
The simulation is `scripts/sim/arena.gd` (node-free, deterministic, a port of
the legacy `src/035_arena.js` without its projectile weapons), drawn by
`scripts/game/arena_scene.gd` with the race's touch controls; covered by
`tests/arena_sim` and `tests/arena_flow`. Other city datasets remain in the
repository for later review; they are not offered in this focused menu.
Existing installs receive a one-time daylight/touch-control settings migration.
See [current status and validation](docs/STATUS.md).

## Develop and test

Use Godot 4.4.1 and its matching export templates. Open `godot/project.godot`, or:

```sh
godot --headless --path godot --editor --import
python3 tools/run_tests.py --godot godot
godot --path godot
```

Tests exercise all available city simulations on three difficulties, load every
city through the production race scene, and check the shared
car model (four animated wheels), all eight power-ups and their transient
visuals, weather transitions, touch reset, landmark construction, and the actual
menu → race → results → retry → menu loop, the chase camera's roll, hit kick,
nitro pull-back and bumper view, the Arcade / Pro handling scales,
the rubber band's finish spread, the bolt-against-eagle defence, and reject
UI text written into a
script instead of the string table. The runner rejects script errors even
when Godot exits zero. Tests write settings only in Godot's user-data directory.
The renderer checks and a one-second benchmark launch run once as Mobile and
once as Forward+: headless Godot keeps the requested renderer's name, so the
phone's quality budget is tested on any machine.

A rendered smoke test (needs a Vulkan GPU or software Vulkan) is available as
`godot --path godot res://tests/weather_visual.tscn`.
Paint, driving particles and speed feedback have a separate rendered check:
`godot --path godot --rendering-method mobile --fixed-fps 60 res://tests/graphics_visual.tscn`
(repeat with `forward_plus`; captures go to `user://shots/`).

```sh
godot --path godot -- --scene=race --auto --city=tirane --quality=medium --env=rain --shots=3,10
```

Every race prints one `RACE seed=… city=… env=… laps=… diff=… handling=…` line (on a phone,
`adb logcat -s godot`). Pass `--seed=<n>` with the same city, direction, weather,
laps, difficulty and `--handling=<arcade|pro>` to replay it; `--laps=<n>`
shortens a race.

Controls: tilt, or the touch-pad fallback in **Cilësimet**; right half gas, left
half brake/drift; **GJUAJ** forward, **PRAPA** backward. Desktop testing supports
arrows/WASD, Space, Shift/X, Q/E and Esc. No music tracks ship yet.

## Android APK

Set `JAVA_HOME` to JDK 17 and `ANDROID_HOME` to the Android SDK (platform-tools,
platform 34 and build-tools 34.0.0), and install the matching Godot Android export
templates (including `android_source.zip`, used by the Gradle export). Then:

```sh
python3 tools/export_android.py --godot godot --version-code 123
```

Use a version code **greater than the installed build** to update an existing app.
The exporter preserves the existing signing identity, supports the standard
`GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`
overrides, and restores export presets after success or failure. It does not
print signing values. Signing credentials are already present in the legacy
project; no new key or unrelated credential is required.

GitHub Actions now installs verified Godot 4.4.1 and matching templates, runs the
native tests, exports/signs the native game and publishes `rruga-e-kombit.apk`
on pushes to `main`. Versions are `run_number` / `1.0.<run_number>`.
Remote build and release results are available in GitHub Actions.
The existing release link continues to serve its current asset until that job runs:
https://github.com/tukehub/rruga-e-kombit/releases/latest/download/rruga-e-kombit.apk

## Real geography and assets

```sh
python3 -m pip install -r tools/pipeline/requirements.txt
python3 tools/pipeline/build_all.py vlore berat gjirokaster shkoder tetove
```

This requires HTTPS access to `overpass-api.de`, `overpass.private.coffee` and
`copernicus-dem-30m.s3.amazonaws.com`. Raw downloads are cached in `tools/cache/`;
processed track, terrain, buildings, side roads and props belong in
`godot/assets/cities/<id>/`. All six processed datasets include `roads.glb`.
The builder rejects routes that double back, and terrain validation fails if the
ground intersects the road. No data is fabricated if access fails.

Pipeline regression test: `python3 tools/pipeline/test_terrain.py`.

Car source: Car Concept © 2024 Darmstadt Graphics Group GmbH and Eric Chadwick, CC BY 4.0; conversion instructions are in `tools/import_carconcept.py`. SFX: `python3 tools/gen_sfx.py`.
The central lists and model paths live in `godot/scripts/data/data.gd`; every
text the player reads lives in `godot/scripts/data/strings_sq.gd`.
Original landmark interpretations use the geographic anchors in `props.json`.
Credits include the CC BY 4.0 car, OSM ODbL, Copernicus DEM, Poly Haven CC0, Godot MIT and the font
OFL texts. [Architecture and source/licence table](docs/PLAN.md).

## Profiling on the target phones

```sh
python3 tools/export_android.py --version-code 124 --profile-seconds 60 --quality medium
adb install -r rruga-e-kombit.apk
adb logcat -c
adb shell am start -n al.tukehub.rruga/com.godot.game.GodotApp
adb logcat -s godot
```

The benchmark waits for world loading and warm-up, then logs `PROFILE:` JSON and
writes `user://profile.json`. It includes hardware, renderer, quality, resolution,
mean/median/p95/max wall-frame, CPU process, physics and GPU render times. Use a
normal export without `--profile-seconds` for distribution. Also capture the Godot
remote profiler on A56 medium, S25 FE medium and S25 Ultra high, with rain and
combat active. A short software-Vulkan run validates instrumentation only; it
cannot establish the **under-16 ms A56** requirement. Physical-device results are
still required.

The APK runs the Mobile renderer. To measure Forward+ on the same phone, export a
second profile build with a higher version code and `--renderer forward_plus`:

```sh
python3 tools/export_android.py --version-code 125 --profile-seconds 60 --quality medium --renderer forward_plus
```

`PROFILE:` names the `renderer` and, under `render_budget`, the effects it was
asked to draw (`ssao`, `sdfgi`, `ssr`, `vol_fog`, `sun_penumbra`). Compare
`frame.p95_ms` and `gpu_time` of both builds at the same quality.

The old `src/`, Capacitor wrapper and `build.py` remain as balance/reference
material and to preserve the keystore path. They are no longer used by APK CI.
Remove legacy code only after the native release is validated and published.

## Vision

Vortex is an arcade combat racer on real city maps. Tirana is the proving ground:
one circuit from OpenStreetMap streets and Copernicus elevation, one car model
(Vortex GT) in six paints. Once Tirana is a finished medium/high-end mobile
experience, the same pipeline produces the other Albanian cities already in the
repo (Vlorë, Berat, Gjirokastër, Shkodër, Tetovë), and online multiplayer lets
two or more friends race from home against each other, with or without bots.
Free and openly licensed assets only (CC0 / CC BY / OFL / MIT).

## Changes to be made

Ordered most critical first. Each item is self-contained; do them one at a time.

Rules for every change:
- The simulation in `godot/scripts/sim/` stays node-free and deterministic (it
  will carry multiplayer). Visuals consume `Race.take_events()`.
- New render features read `Quality.p` and react to `Quality.budget_changed`.
  A feature only Forward+ can draw is listed in `Quality.FORWARD_PLUS_ONLY`.
- New persisted data carries a version and a migration, like
  `PRESENTATION_VERSION` in `scripts/game/settings.gd`.
- Every change adds or updates a test under `godot/tests/` run by
  `tools/run_tests.py`.
- UI strings go through one table, not literals: add a key to
  `scripts/data/strings_sq.gd` and read it with `Data.t(key)`, `Data.t(key,
  args)` or `Data.t_list(key)`. `tests/string_table` fails on a literal left
  in a script, an unknown key and an unused key.
- The name is always "Vortex".

### 1. Foundations (critical)

1.1 **Renderer truth — decided: Mobile on phones, phone numbers still open.**
    Android keeps `rendering_method.mobile="mobile"`; desktop stays Forward+.
    `Quality.p` is filtered by `Quality.renderer`, `tests/renderer_truth` pins
    the decision, and the docs say the same. Remaining, needs the phones:
    profile the A56, S25 FE and S25 Ultra with and without
    `--renderer forward_plus`
    ([Profiling on the target phones](#profiling-on-the-target-phones)).
    Switch the override only if Forward+ holds p95 under 16 ms on the A56 at
    medium; until then Section 3 assumes the Mobile renderer.
1.2 **String table — done.** Menus, HUD, touch controls, race feed, pause,
    results, the loading screen with its facts, and the copy that was in
    `data.gd` are in `scripts/data/strings_sq.gd`, read through `Data.t(key)`.
    The simulation returns data, not words (incoming-threat side). Driver
    names and `Data.GAME_NAME` stay in `data.gd`: proper names, the same in
    every language.
1.3 **`Progress` autoload — done.** `scripts/game/progress.gd` keeps
    `user://progress.cfg`: version, fans, unlocked paints and cities, cup
    stars (`add_fans`, `spend_fans`, `unlock_paint`, `unlock_city`,
    `set_stars`). Older files are upgraded in `_upgrade`, bad values repaired,
    a damaged file set aside, and a newer build's keys kept. Race fans feed
    it since 6.1; 6.2 adds stars, 6.3 purchases, 8.3 cities. The six
    original paints stay free; 6.3 adds paints, rims and liveries to buy.
1.4 **`Music` autoload — done.** `scripts/game/music.gd` plays on a "Music"
    bus (in `Sfx.BUSES`, level from `Settings.vol_music`) with two players:
    `Music.play(track)` crossfades to `assets/music/<track>.ogg`,
    `Music.stop()` fades out, `Music.duck(amount, seconds)` pulls the music
    down and lets it rise. No tracks, no callers and no volume slider yet;
    all three come with 4.1.

### 2. Gameplay feel (Tirana)

2.1 **Camera dynamics — done.** `scripts/game/chase_cam.gd` rolls into
    bends and drifts, follows sideways faster while drifting, pulls back
    while nitro burns, and replaces the random shake with a spring kick along
    the blow: "hit" and "wreck" events carry `dir` (x to the driver's right,
    y forward) from `Race.hit()`. The view button cycles chase → cabin →
    bumper (`ChaseCam.View`, `RaceViews.set_view`). The chosen view is not
    saved between races. Covered by `tests/camera_dynamics`.
2.2 **Handling difficulty — done.** `Settings.handling` ("arcade" | "pro",
    the "Kontrolli i makinës" row in settings) picks an entry of
    `Data.HANDLING`; `Race` takes it as the `handling` option and scales the
    human driver's steering assist, corner brake trim and drift grip. Arcade
    is 1.0 throughout, so it drives as before; bots and `Data.DIFFS` are
    untouched. The settings file now records `VERSION`. The `RACE` log line
    names the handling and `--handling=<id>` replays it. Covered by
    `tests/handling`. The Pro numbers (0.7 / 0.5 / 0.5) are a first guess:
    tune them on a phone.
2.3 **Traffic and hazards — removed.** Parked and slow cars were tried and
    taken out: only the six racers are on the street.
2.4 **Rubber-band pass — done.** `Race.rubber_band()` reads five numbers
    per difficulty from `Data.DIFFS`: `catch_up` (bots behind the player) and
    `lead_drag` (bots ahead), both reached `band` metres away, and
    `runaway_drag` on a leading bot more than `runaway_gap` clear of second
    place. They replace the fixed +7.5% / -5% that saturated within 40 m; the
    player's car is never touched. `tests/rubber_band` runs one-lap Tirana
    races on all three difficulties. Without pickups the band narrows the
    finish spread in every case (for example 5.3% → 4.4% of the winner's
    time on normal with a quick driver). With weapons on, combat decides
    the spread and the band is not measurable (about 10.5% either way over
    84 races each), so those
    races only have to stay under 25% each and 13% on average. If the field
    should bunch up more during combat, raise the numbers in `Data.DIFFS`.
2.5 **Combat counterplay — done.** A bolt fired toward an eagle that hunts
    its owner (backward for one from behind) leans across the road to meet
    it and shoots it down: an "intercept" event, `Race.FANS.intercept` fans,
    a feed line, and a "RRËZOJE ME RRUFE" hint on the eagle warning while a bolt
    is selected. Bots fire that defence too, scaled by `aim`.
    `PickupDirector.weights()` scales its offers by standing through
    `RANK_WEIGHTS` ([first, last], interpolated): last place gets more
    nitro, eagle, storm and bolt, the leader more mine and shield. Covered
    by `tests/combat_counterplay`.

### 3. Graphics (Tirana, medium/high-end target)

Phones render with Godot's Mobile renderer (1.1). It has no SSAO, SSIL, SSR,
SDFGI, VoxelGI, volumetric fog, TAA, FSR 1/2, subsurface scattering or soft
(PCSS) sun shadows, and it lights one mesh with at most 8 omni lights, 8 spot
lights and 8 reflection probes. Baked lightmaps, reflection probes, decals,
glow, MSAA/FXAA, depth of field, colour adjustments and screen/depth textures
work. An item below that needs a Forward+-only feature is desktop-only.

3.1 **Car paint — implemented** (see [checkpoints](docs/section-3-progress.md))
    in `shaders/sport_car.gdshader`: `CLEARCOAT`,
    `CLEARCOAT_ROUGHNESS`, a procedural flake normal on the body mask,
    metallic ~0.6 / roughness ~0.25 on paint. Headlights for bots in
    `scripts/cars/car_visual.gd` (emissive always; real `SpotLight3D` only
    within `Quality.p.fx_light_limit`).
3.2 **Speed feedback — implemented** (see [checkpoints](docs/section-3-progress.md)):
    `GPUParticles3D` tyre smoke on drift, exhaust
    puff/flame on nitro, wheel spray when wet, wall sparks on scrape (pooled in
    `scripts/game/fx_visual.gd` with caps in `POOL_CAPS`); fullscreen
    `shaders/speed_post.gdshader` (radial blur, vignette, slight chroma) driven
    by speed ratio and nitro, disabled on low.
3.3 **Reflections:** one `ReflectionProbe` following the player (medium+),
    static probes at landmarks on high; garage in `scripts/ui/menu.gd` gets an
    HDRI background, a probe and a glossy floor. Lower the flat ambient floor in
    `scripts/world/sky_env.gd`.
3.4 **Street dressing from OSM:** the pipeline emits traffic lights, bus stops,
    benches, bins, bollards and parked-car slots into `props.json`;
    `scripts/world/props.gd` draws each kind as one `MultiMeshInstance3D` with
    visibility ranges. Low-poly CC0 props (< 500 tris each) under
    `godot/assets/props/`.
3.5 **Road decals** in `shaders/road.gdshader`: zebra crossings at OSM junction
    nodes, manholes and patches by hash, via a small decal atlas and a uniform
    list.
3.6 **Facade depth:** balcony/ledge boxes for buildings within ~60 m of the
    track (pipeline), or parallax-interior windows in `shaders/facade.gdshader`;
    start inside the existing `detail_preview` region, then extend to the whole
    lap.
3.7 **Baked lighting and culling:** `LightmapGI` per environment family for the
    static city, loaded in `SkyEnv.apply()`; SDFGI stays desktop-only
    (Forward+, high). Enable occlusion culling with pipeline-generated
    occluder boxes for tall buildings. FSR2/TAA exist only under Forward+:
    try them in `Quality.apply_viewport()` only together with the Forward+
    profile from 1.1, and keep them only if the A56 p95 frame stays under
    16 ms. On Mobile the anti-aliasing choices are MSAA and FXAA.
3.8 **Colour grading:** one LUT per `Data.ENV` preset through
    `Environment.adjustment_color_correction`.

### 4. Audio

4.1 **Music:** CC0/CC BY menu loop, 2–3 race loops (chosen by env), results
    sting, countdown hit; credits in `godot/assets/CREDITS.txt`. Hook via
    `Game.scene_changed` and `RaceScene._begin()`; duck on wreck and finish
    (`Music.duck`). Add the music slider to the settings page
    (`Settings.vol_music` already persists).
4.2 **Engine:** replace the two-loop crossfade in `RaceScene._engine_audio()`
    with idle/low/mid/high layers plus fake gears (pitch ramp, shift one-shot)
    and an off-throttle layer; the nearest two bots get 3D engine loops.
4.3 **Announcer (Albanian):** countdown, final lap, position changes, power-up
    names, new record; priority queue with a minimum gap, its own bus, a
    settings toggle.
4.4 **Mix:** reverb send under landmarks/tunnels, low-pass while
    stunned/wrecked, haptic patterns per event instead of one buzz.

### 5. Controls and UI

5.1 **Icon controls — done.** Gas and brake show SVG icons
    (`assets/ui/controls/`) and the steering pad a half wheel that turns
    with the thumb, drawn by `RaceInput.ControlFace`; the words are gone
    from the string table. A held control shrinks to 93% and lights a ring.
    `control_rect()` is unchanged and still the only hit geometry. The fire,
    rear-fire and drift buttons keep their power-up icon and their line of
    text, because that text is state ("PA RIVAL", "E PLOTË", "DRIFT 40%").
    Checked in `tests/combat_ui`.
5.2 **Motion — done.** `UiTheme.fade`, `slide_in` and `press` (every
    `UiTheme.button` gives 4% under the finger). Menu pages slide in, the
    title from the left, the rest from the right; the page shown switches at
    once and only its arrival is animated. `Game.goto()` fades the loading
    cover in (0.14 s) and off the new scene (0.3 s). Result rows arrive one
    after another, first place first. (A tap-to-open standings panel was
    tried and dropped: the full list with metres is always shown.) Covered
    by `tests/ui_motion`.
5.3 **Cinematics — done.** During the intro sweep `IntroCards`
    (`scripts/ui/intro_cards.gd`) slides in one name card per racer, front
    of the grid first, and fades them out when the countdown starts. On the
    finish line the race runs at 30% speed for 0.7 s and eases back over
    0.5 s (`RaceScene.finish_time_scale`); only the simulation clock slows,
    so the camera move and the 4.2 s to the results are unchanged. Checked
    in `tests/flow_test`.

### 6. Progression

6.1 **Fans persist — done.** A finished race passes the player's fans
    (`Race.FANS`: hits, wrecks, places gained, finishing place) to
    `Game.finish_race()`, which adds them to `Progress` and saves at once.
    The results page counts the earned fans up from zero and the total from
    what the player had, after the standings arrive. A race quit or
    restarted from pause earns nothing, and a points round earns no fans.
    Checked in `tests/flow_test`.
6.2 **Tirana Cup — done.** Five events in `Data.CUPS.tirana`, each with
    its own laps, weather, rival difficulty, direction and goal (`clean`,
    `hits`, `wrecks`, `fans`). Stars (`Data.cup_stars`): 1 for the top
    three, 2 for a win, 3 for a win that meets the goal; the best is kept in
    `Progress`. The title page's main row is now "Kupa · n/15" beside
    "Nisu!", and the cup page shows a card per event with its conditions,
    goal and stars. Every event is open from the start. An event's settings
    come through `Game.race_setting()` and never overwrite the player's
    free-race choices; "Përsërit" replays the event and the menu returns to
    the cup. Results show the stars and whether the goal was met. The free
    race stays, since points mode and the race options live beside it.
    Covered by `tests/cup`.
6.3 **Shop — done.** Six new paints (500–900 fans), five rims (250–500)
    and four liveries (400–800) in `Data.CARS`, `Data.RIMS` and
    `Data.LIVERIES`; the six original paints, silver rims and no livery are
    free. `Progress` (version 2) keeps what the player owns and `buy()`
    takes the fans; `Settings` (version 2) keeps the rim and livery worn,
    and `Game.cosmetics()` only ever returns owned ones.
    `CarVisual.setup()` takes `{"rim", "livery"}`: the rim colours the rim
    surfaces, the livery is a second, white-on-transparent atlas
    (`assets/cars/livery_atlas.png`, from `tools/build_livery_atlas.py`)
    projected onto the body from above and the sides in a contrasting
    colour, as a `next_pass` over the paint or inside `sport_car.gdshader`.
    The garage has tabs for paint, rims, livery and driver; a shop item is
    tried on the garage car with a buy button that names the price or the
    fans still missing. Bots keep plain cars. On the privately staged
    atlas car the rims are part of the texture, so only the livery changes
    there. Covered by `tests/shop`.
6.4 **Tutorial — done.** The cup's first event, "Mësimi" (`tutorial`
    in `Data.CUPS`): one lap, easy rivals that never fire or boost, no
    every station carrying a set pickup in all three lanes
    (`Data.TUTORIAL_PICKUPS`: nitro first, then bolts, shield, eagle...).
    `TutorialPrompt` shows one instruction at a time at the top centre:
    steering and pedals at the start (touch or tilt, auto or manual gas),
    each pickup before its station, the sharpest bend before it comes, and
    the finish; picking something up says how to use it, a charged drift
    says how to boost. Instructions are at least 70 m apart. "Kalo" leaves
    for the cup at any time, earning nothing; like every event it is never
    required. Covered by `tests/tutorial`.

### 7. Online multiplayer (2+ friends from home, bots optional)

7.1 **Model:** deterministic lockstep on the existing fixed-step `Race`. Each
    peer sends only `CarState.ctrl` per tick; seed, city, env, laps and diff
    are agreed in the lobby. Add an input-delay buffer (2–3 ticks) and a
    per-tick state hash for desync detection. Prerequisite: audit `race.gd` and
    `pickup_director.gd` for nondeterminism (RNG usage, dictionary iteration
    order, float accumulation) and lock it with a replay test comparing two
    runs of the same seed.
7.2 **Transport:** Godot `ENetMultiplayerPeer`; one player hosts. Add a small
    relay server (headless Godot, same project, `--server`) for players behind
    NAT.
7.3 **Lobby UI** in `menu.gd`: host/join by code, paint pick, ready, bot count
    0..(6 − humans). Remote players fill `CarState` slots in `Race._init()`.
7.4 **Resilience:** pause/resync on disconnect, bot takeover of a dropped
    player, 3 s rejoin grace. Test: two headless instances finish a race with
    equal final state hashes.

### 8. Other cities

8.1 Re-run `tools/pipeline/build_all.py` for the five datasets; fix side-road
    and terrain clearance failures; add per-city landmarks via
    `scripts/world/landmarks.gd`.
8.2 Remove the city exclusions from `godot/export_presets.cfg`; keep the APK
    under ~150 MB (compress heightmaps/meshes) or use Play Asset Delivery.
8.3 City unlock chain through cup stars; the multiplayer host may pick any
    unlocked city.

### 9. Release polish

9.1 Adaptive launcher icons, target SDK 35, Android back button → pause.
9.2 Translations (sq, en, de, it) from the string table; Google Play Games
    leaderboards (best lap per city, total fans) and cloud save; crash
    reporting.
9.3 Privacy policy link and a credits refresh for every new asset.

