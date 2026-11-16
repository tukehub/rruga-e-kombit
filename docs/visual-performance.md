# Visual consistency and rendering budgets

Cars retain health-driven paint wear between hits. Stable marks and higher
roughness affect painted panels; glass, trim, lamps and each car's identity stay
readable. Repair and respawn restore clean paint. Public fallback cars use darker,
rougher paint. The existing contact patch follows road elevation and fades in
airtime at every quality level. These effects reuse each car's existing materials.

Road shoulders now join the baked terrain height instead of dropping a fixed
2.2 metres. Kerbs and barriers share a subdued concrete/red palette, matte
roughness and base grime. Asphalt gutters and outer edges blend into the
shoulders; wetness changes roughness and tint without rebuilding geometry.
The same material rules apply throughout a lap and in reverse.

Corner guidance is computed once from track frames. Opaque yellow chevrons face
the approach, outside the barriers, with one to three marks for severity. Two
shared mesh batches cover the route. The minimap reserves space for a matching
arrow and distance, **TANI** while in the corner, or **VIJO DREJT** on a straight.
Final-lap guidance stops at the finish. Reverse, chicanes and corners crossing
the lap seam use the recomputed driving frame. Positive lateral offset is the
driver's right; incoming homing-shot side labels now follow that same convention.

## Renderer

Android runs Godot's Mobile renderer; desktop development runs Forward+
(`project.godot`: `rendering_method` and its `.mobile` override).
`Quality.renderer` names the one in use, and `Quality.p` holds only what that
renderer can draw, so scene code reads the budget and never asks which
renderer is running.

| Budget | Forward+ (desktop) | Mobile (phones) |
| --- | --- | --- |
| SSAO; SSR on wet roads | Medium and high | Never |
| SDFGI, volumetric night fog, soft sun shadows | High | Never |
| Street lights + combat lights | Up to 14 + 4 | Up to 6 + 2 |
| 3D scale, MSAA/FXAA, glow, shadows, draw distances | By preset | By preset |

The Mobile renderer lights one mesh with at most eight omni lights, and the
road is a single mesh; street lamps and combat lights therefore share eight.
On a phone **E lartë** means native resolution, 2× MSAA, a 4096 shadow atlas
in four cascades, car shadows, longer draw distances and denser trees, not
the desktop's global illumination. Automatic detection stops at medium there.

Profile exports accept `--renderer forward_plus` to measure the other renderer
on the same phone; `PROFILE:` reports the renderer and the effective effects.
No phone has been measured yet, so Mobile stays the shipped choice.

## Frame rate and sustained load

Main-menu **Cilësimet** provides **Ritmi i pamjes → 30 FPS · Bateri** or **60 FPS**,
plus **Përshtat cilësinë gjatë lojës**. Both choices persist. Existing installs
default to 60 FPS with adaptation enabled. The rendering cap leaves simulation
at 60 Hz and the HUD at native canvas resolution.

The controller samples active racing frames after a five-second warmup. Two
consecutive two-second overloaded windows lower rendering one step; an
eight-second cooldown and twelve seconds of steady frames limit oscillation.
An isolated long stall is ignored, repeated long stalls count as load, and
pause/resume gets fresh samples and a short grace period. A 30 FPS selection
uses its own frame budget. Headless simulations don't drive adaptation.

The saved quality and mirror choices are preserved. The runtime budget reduces
3D resolution, rain density, optional halos/trails/sparks, combat and street
lights, mirror resolution/cadence and expensive shadows/post-processing.
MSAA gives way to FXAA under stronger pressure. Core threats, player headlights,
contact patches and HUD cues remain. The scale floor is 0.6; settings can disable
adaptation.

For example, medium at the strongest reduction changes:

| Budget | Normal | Reduced |
| --- | --- | --- |
| 3D render scale | 0.8 | 0.6 |
| Rain density multiplier | 1.0 | 0.45 |
| Rear mirror | 256×64, every 3 frames | 128×32, every 6 frames |
| Combat lights, combined | 2 | 0 |
| Street lights | Up to 6 | Up to 2 |
| Active explosion flashes | Up to 5 | Up to 2 |

## Fixed combat pools

Race setup preallocates 54 bolt, 18 eagle, 24 mine and 3 dome units, plus 8
flashes and 6 activation rings: 113 units total. The projectile capacity covers
a six-racer, three-slot inventory burst; mines already have a simulation cap
of 24 and the existing single-storm rule permits three domes. Dome radii scale
unit geometry. Activation rings animate fixed slots without per-use Tweens.
Projectile/dome updates never fall back to constructing a node or mesh.

When a stream exceeds capacity, player-targeted homing threats take priority,
then nearby objects. Expired units return before acquisition. Distant cores
are culled beyond 210 metres, with player-targeted homing threats retained.
Saturation is counted for tuning; simulation objects and hit rules are unchanged.
Small GDScript arrays/dictionaries still update during racing.

## Verification and device review

`tools/run_tests.py` includes 21 scenes. `renderer_truth` and a one-second
benchmark launch run once as Mobile and once as Forward+, checking the shipped
renderer settings, every preset/pressure budget, the sky, a weather
transition, the garage and the `PROFILE:` report. The other checks cover controller
hysteresis, persistence and real menu choices; automatic budget-signal delivery;
all quality/pressure combinations with night rain, lights, mirror and 99 combat
cores; exhaustion priority and stable effect node/mesh/material identities;
actual repair/respawn and fallback paint; 120 car contact samples; every shoulder
edge across all six cities; reverse/seam/chicane guidance and finish limits.

Nine desktop Mobile-renderer captures checked forward/reverse boards,
healthy/damaged/repaired paint, three further Tirana lap positions and combined
night rain/combat/lights/mirror at normal and reduced budgets. This uses software
Vulkan for correctness, not evidence of Android frame rate or battery savings.
An additional 35-second render-load probe, after shader warmup at a reduced
desktop resolution, reached all three budget reductions while retaining all
99 combat cores. The settings screen was also checked with 30 FPS selected.

The existing benchmark now records `render_budget`, pool `effects` diagnostics
and active `workload` alongside frame/process/physics/GPU times, hardware,
pickup and combat data. Physical Android review still needs sustained laps at
30/60 FPS on target devices, including mirror on/off, weather transitions,
thermal load, memory/loading cost, battery use and corner visibility at speed.
