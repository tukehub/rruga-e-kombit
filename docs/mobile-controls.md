# Mobile controls

Automatic acceleration is the default, including upgrades whose settings predate
this option. Steering is a relative touch pad on the left; the right thumb brakes
and uses items. Brake suppresses automatic gas immediately. Touch down is neutral,
and sliding from that starting point steers; lifting the steering thumb centers
the wheel. Each finger owns its control until release or cancellation, even when
dragging outside its rectangle. A second steering finger cannot take over.

The menu and **Pause → Kontrollet** share the same persistent options:

- Automatic gas or manual gas/brake pedals. Manual pedals sit together opposite
  the steering thumb; existing keyboard W/up and S/down still operate them.
- Steering on either side, three button sizes and touch sensitivities, opacity,
  and bounded inward/upward placement. Reset placement restores size, side,
  opacity and position without changing steering mode, sensitivity or gas mode.
- Tilt sensitivity/inversion and neutral calibration. Hold the phone as during
  play when calibrating. Gravity is preferred, with acceleration as a fallback;
  neutral is subtracted before inversion. A missing sensor leaves calibration
  unchanged. Mobile races fall back to touch steering if tilt is unavailable at
  the start or for one second after selecting tilt/resuming. Desktop keyboard
  input does not trigger that fallback.

Control editing preserves the paused race. Layout, calibration and input-mode
changes clear existing pointers and pending actions. Saving an unrelated setting,
such as the mirror, preserves held controls. Intro/countdown, pause, focus loss
and finish cannot start automatic gas. Returning focus requires explicit resume;
finish clears and hides the driving controls. Resize and safe-area changes also
release old touches. Native display insets are transformed to logical canvas
coordinates for the HUD, view buttons, driving controls, menus and result actions.

The primary item action shows the selected item icon and actual action. Weapons
and mines expose their forward/reverse actions; Nitro's reverse action explicitly
says **FRENO NITRO** because it consumes Nitro to brake. Non-directional abilities
have one action. Empty inventory, full-health repair, leader lightning, spin and
wreck states disable unavailable actions. A held item thumb fires once per tap;
that tap stays latched across render frames until a fixed simulation tick consumes
it. Combat effects, ammunition and balance are unchanged.

Help and the short driving prompt explain the default layout, drift braking,
manual mode, calibration and Nitro braking. A/D and arrow steering both work.

## Validation

`tools/run_tests.py` includes `two_thumb_controls.tscn`. It exercises simultaneous
steering/gas/fire with two pointers, brake override, manual pedals, pointer
ownership/cancellation, focus/resume, race phases, contextual actions, layout
changes, stretched/inset touch coordinates, calibration and config persistence.
Layout checks cover both sides and all sizes at logical widths 1160–1920 and a
650-pixel safe height, checking inventory clearance and distinct touch targets.
The race-flow test opens control settings while paused, changes preferences,
returns to the same paused race and checks missing-tilt recovery. The existing
fixed-tick, driving, race-flow and adaptive-pickup regressions remain included.

Desktop Mobile-renderer screenshots can check placement and text. Physical
Android testing is still needed for thumb comfort, sensor orientation/calibration,
notches/navigation insets and interruption behavior on actual devices.
