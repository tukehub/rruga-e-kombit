# Vortex — Tirana review build

The menu focuses on Tirana. The circuit follows OpenStreetMap vehicle streets in
an approximately 4.7 km closed loop near the requested landmarks; one-way traffic
rules are adapted for a closed race. Skanderbeg Square is represented by paving
on the terrain, and the landmarks are original simplified interpretations, not
photorealistic surveys. The most detailed trees are limited to the opening stretch.
The shared sports car is credited in `godot/assets/CREDITS.txt` and retains six
paint choices with identical handling.

The chase camera and car poses interpolate between simulation steps. Automatic
gas, relative touch steering and a brake/item group support two-thumb racing;
manual pedals, mirrored placement, reach/size/opacity and calibrated tilt are
available in the menu and during pause. Item actions show context and readiness;
native safe areas protect the UI. [Control behavior and checks](mobile-controls.md).
An optional cabin view and rear-view mirror remain available. Menu transitions
show loading feedback while the city is built.

Daylight and daytime rain use lower ambient fill and preset exposure, with
restrained bloom and saturation. Wet asphalt stays darker and textured between
puddles. During the final 150 metres of the race, automatic corner braking and
the optional steering correction switch to the unassisted response; manual
braking remains available. Earlier laps retain the selected assistance.

Pickup stations now adapt unseen choices to inventory, health, nearby rivals,
recent combat and the road ahead. A bounded pool can add shared, one-shot help
190–200 metres ahead when useful supply is missing, with distance/time limits
and protection against visible item changes. [Behavior and diagnostics](adaptive-pickups.md).

Combat now shares readiness/target checks between firing and UI, warns about
incoming homing shots, and displays effect durations, recovery and critical
health. A fixed recovery window prevents repeated disabling attacks extending
control loss. Hold a slot to discard; full inventories may replace only an
unusable reserve while protecting the selected item. Clean drift distance earns
a banked short turbo beside inventory. [Rules and verification](combat-recovery.md).

Health now leaves persistent paint wear, cleared by repair or respawn. Terrain
shoulders, subdued road-edge materials and corner-specific chevrons establish
shared visual rules around the lap. The minimap adds matching turn/distance
guidance for normal and reverse races. Settings offer a battery-oriented 30 FPS
cap and sustained-load adaptation of rendering, rain, lights, optional effects
and mirror work. Combat visuals use fixed pools, including domes.
[Visual behavior, budgets and verification](visual-performance.md).

Phones render with Godot's Mobile renderer and desktop with Forward+. The
quality budget follows the renderer in use: ambient occlusion, screen-space
reflections, SDFGI, volumetric fog and soft sun shadows are desktop-only, and
street plus combat lights fit the Mobile renderer's eight omni lights per mesh.
Profile builds now pass the benchmark options where the game reads them
(they were ignored before) and can force either renderer for comparison;
neither build has been run on a phone yet.
[Renderer budgets](visual-performance.md#renderer).

Every text the player reads now comes from one string table
(`godot/scripts/data/strings_sq.gd`); scripts hold keys, and a test rejects
text written into a script, unknown keys and unused keys.

README graphics items 3.1 and 3.2 now add metallic clearcoat/flakes, budgeted
nearby rival headlights, fixed GPU pools for drift smoke, wet-wheel spray,
nitro exhaust and scrape sparks, and a peripheral speed post effect beneath
the HUD. Low quality and sustained pressure remove optional effects. Both
renderer paths have regression coverage; Mobile and Forward+ software Vulkan
captures exercise the shaders and production race integration. Physical phone
performance is still unmeasured. [Checkpoints and next work](section-3-progress.md).

Checks include fixed-step race simulations, city loading, race flow, touch
controls, OSM routing, side-road clearance and terrain-to-road clearance. Desktop
rendering verifies visual placement, but cannot establish Android performance.
Phone review should check smooth racing, the mirror on/off, the landmark views,
tree detail, loading feedback and touch controls.

Vlorë is now in the build, opened by four Tirana cup stars through the race
page's city picker, with an open-water bay (baked shore mask, one opaque wave
plane, sand beach and foam). Its route is still the old placeholder loop
around Flag Square; Lungomare, the Flamurtari stadium and the Independence
Museum need a new route and landmark work. The other four cities stay out of
the APK until their datasets are reworked.
