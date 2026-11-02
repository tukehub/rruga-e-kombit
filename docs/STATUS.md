# Vortex — Tirana review build

The menu focuses on Tirana. The circuit follows OpenStreetMap vehicle streets in
an approximately 4.7 km closed loop near the requested landmarks; one-way traffic
rules are adapted for a closed race. Skanderbeg Square is represented by paving
on the terrain, and the landmarks are original simplified interpretations, not
photorealistic surveys. The most detailed trees are limited to the opening stretch.
The shared sports car is credited in `godot/assets/CREDITS.txt` and retains six
paint choices with identical handling.

The chase camera and car poses interpolate between simulation steps. Controls
include side pedals, forward/back fire, an optional cabin view and a toggleable
rear-view mirror. Menu transitions show loading feedback while the city is built.

Checks include fixed-step race simulations, city loading, race flow, touch
controls, OSM routing, side-road clearance and terrain-to-road clearance. Desktop
rendering verifies visual placement, but cannot establish Android performance.
Phone review should check smooth racing, the mirror on/off, the landmark views,
tree detail, loading feedback and touch controls. Other cities remain deferred.
