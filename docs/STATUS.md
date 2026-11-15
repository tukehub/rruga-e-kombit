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

Checks include fixed-step race simulations, city loading, race flow, touch
controls, OSM routing, side-road clearance and terrain-to-road clearance. Desktop
rendering verifies visual placement, but cannot establish Android performance.
Phone review should check smooth racing, the mirror on/off, the landmark views,
tree detail, loading feedback and touch controls. Other cities remain deferred.
