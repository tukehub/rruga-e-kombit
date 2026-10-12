# Rruga e Kombit

Blur-style combat racing through 11 cities in Albania, Kosovo and Tetovë. Five rivals (Artur, Ritvan, Desantin, Eno, Erlin), eight power-ups, neon, light trails, wrecks.

## Install on Android
Open this link on the phone and install the APK (allow "install unknown apps" for the browser the first time):

**https://github.com/tukehub/rruga-e-kombit/releases/latest/download/rruga-e-kombit.apk**

Every push to `main` builds a new APK automatically (Actions → *Build APK*) and publishes it as the latest release. New versions install over the old one; progress is kept.

## Project layout
- `src/` — the game (plain JavaScript + three.js r128). `shell.html` is the UI markup and styles.
- `build.py` — bundles `src/` into `www/` with local three.js, bloom post-processing and fonts.
- `android/` — Capacitor 8 Android wrapper (full-screen landscape, screen kept on).
- `test/` — `race.js` simulates every race headlessly; `shots.js` renders screenshots in headless Chromium.

Local build: `npm ci && python3 build.py && npx cap sync android && cd android && ./gradlew assembleRelease`.

## Controls
- **Touch:** slide on the left pad to steer · GJUAJ fires · PRAPA fires backwards · FRENA brakes (with steering = drift) · tap the power-up icons to switch.
- **Keyboard:** ←/→ steer · ↑ gas · ↓ brake/drift · Space fire · Shift fire back · Q/E switch · P pause.
- **Gamepad:** left stick · RT gas · LT brake · X fire · Y fire back · LB switch.
