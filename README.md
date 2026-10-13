# Vortex

Vortex: Blur-style combat racing through 11 cities in Albania, Kosovo and Tetovë. Six real-ish 2020 cars (Benxi GT, Kali i Egër, Golfi GTI, Uragani, Gelendvagen, Sprinteri), five rivals (Artur, Ritvan, Desantin, Eno, Erlin), eight power-ups, neon, light trails, wrecks.

## Install on Android
Open this link on the phone and install the APK (allow "install unknown apps" for the browser the first time):

**https://github.com/tukehub/rruga-e-kombit/releases/latest/download/rruga-e-kombit.apk**

Every push to `main` builds a new APK automatically (Actions → *Build APK*) and publishes it as the latest release. New versions install over the old one; progress is kept.

## Project layout
- `src/` — the game (plain JavaScript + three.js r128). `shell.html` is the UI markup and styles. `035_arena.js` is the points-mode simulation (free 2D driving, collisions, bots), `095_arena_view.js` builds and renders Skanderbeg Square.
- `build.py` — bundles `src/` into `www/` with local three.js, bloom post-processing and fonts.
- `android/` — Capacitor 8 Android wrapper (full-screen landscape, screen kept on).
- `test/` — `race.js` simulates every race headlessly; `points.js` runs the 2- and 3-minute points mode; `shots.js` renders screenshots in headless Chromium.

Local build: `npm ci && python3 build.py && npx cap sync android && cd android && ./gradlew assembleRelease`.

## Modes
- **Garë:** the usual race through the cities, laps and power-ups. Every city shows its signature landmark on the skyline. Power-ups come back 2 seconds after somebody takes them.
- **Pikë (2 or 3 min):** no track. Five cars loose in Skanderbeg Square, a walled open arena. Ram the others: the harder the hit, the more points. Hits in a row multiply your points up to ×5, and wrecking a car adds a bonus. The eight power-ups work here too and score when they land. A live leaderboard shows the standings.

You play as one of the five drivers (Artur, Ritvan, Desantin, Eno, Erlin); the other four are your rivals. Each driver has a colour nobody else uses, on the car, its light trail, its name tag and the minimap.

## Controls
- **Phone:** tilt to steer · hold the right half for gas, the left half for brakes (brake + turn = drift) · GJUAJ in the middle fires · PRAPA fires backwards · tap the small power-up icons to switch. Touch steering is in Settings.
- **Keyboard:** ←/→ steer · ↑ gas · ↓ brake/drift · Space fire · Shift fire back · Q/E switch · P pause.
- **Gamepad:** left stick · RT gas · LT brake · X fire · Y fire back · LB switch.
