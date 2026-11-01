# Vortex — Tirana review build

## Player feedback addressed

- Restored Vortex in the game, Android launcher, credits and release title.
- Focused the menu on Tirana, with a direct start button, difficulty, paint and
  driver choices. A 1280×720 logical canvas and bold headings increase phone
  readability. Results and settings use larger text too.
- Daylight is the default; existing night/rain preferences are migrated once.
  Dynamic weather is off by default so the race does not darken unexpectedly.
  Asphalt, ambient fill, shadows and haze were tuned for clear road visibility.
- One smooth modern fastback is shared by all six racers: 42,236 triangles,
  rounded body, glazing, LED lights and alloy wheels. Paint choices share identical
  performance. Original selection IDs remain compatible with saved settings.
- Eight recognizable symbol badges replace pickup cubes. The same icons appear
  in inventory; eagle and lightning attack visuals match their pickup identities.
- Explicit accelerator/brake pedals and forward/back shooting controls sit in
  the corners. A touch steering pad or selectable tilt steering remains available.
  The road is no longer an invisible full-screen pedal surface.
- Six-driver standings remain visible in a translucent edge panel. Speed, health,
  minimap, pause and inventory leave the central driving view open.

## Validation

- Godot 4.4.1: import, 18 full race simulations, six city-world loads and the
  menu → race → results → retry → menu integration pass.
- Input checks cover simultaneous pedals/fire, independent pointer releases,
  focus reset and center-screen touches doing nothing.
- Rendered Forward+ views reviewed under software Vulkan: menu, paint selection,
  settings and a daylight Tirana approach with eagle/lightning pickups.
- Desktop rendering checks appearance only; phone performance is not established.

## Still requires phone review

- Install the new APK over the previous release and assess text size on the
  actual display, multi-touch reach, touch steering/tilt and sustained rain/combat
  performance on A56/S25-family hardware.
- Player approval of this Tirana presentation before applying another city pass.
- Other city scenery and legacy cleanup remain deferred.
