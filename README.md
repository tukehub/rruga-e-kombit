# Vortex

Native Godot **4.4.1**, GDScript, Forward+ / Vulkan combat racer for Android.
Package: `al.tukehub.rruga`. The fixed release key remains at
`android/app/rruga.jks`; changing it would break updates to existing installs.

This review build focuses on **daylight Tirana**. It has one shared sports car
for all six drivers, six paint choices with identical performance,
recognizable eagle/lightning/etc power-up badges, larger phone text, explicit
corner pedals and forward/back shooting buttons, and always-visible translucent
standings. The middle of the screen stays clear for the road and car.

The main menu starts a Tirana race directly. Other city datasets remain in the
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
menu → race → results → retry → menu loop. The runner rejects script errors even
when Godot exits zero. Tests write settings only in Godot's user-data directory.

A rendered smoke test (needs a Vulkan GPU or software Vulkan) is available as
`godot --path godot res://tests/weather_visual.tscn`.

```sh
godot --path godot -- --scene=race --auto --city=tirane --quality=medium --env=rain --shots=3,10
```

Controls: tilt, or the touch-pad fallback in **Cilësimet**; right half gas, left
half brake/drift; **GJUAJ** forward, **PRAPA** backward. Desktop testing supports
arrows/WASD, Space, Shift/X, Q/E and Esc. There is no music.

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

Car source: Comrade1280’s CC BY 4.0 Generic passenger car pack, adapted from the optimized derivative in `pedrosoandre/carros`; conversion instructions are in `tools/import_comrade_car.py`. SFX: `python3 tools/gen_sfx.py`.
The central lists and model paths live in `godot/scripts/data/data.gd`.
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

The old `src/`, Capacitor wrapper and `build.py` remain as balance/reference
material and to preserve the keystore path. They are no longer used by APK CI.
Remove legacy code only after the native release is validated and published.
