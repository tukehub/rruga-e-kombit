# Adaptive pickups

The race keeps its original shared three-lane pickup stations. Before an unseen
station is approached, a small simulation director chooses its contents using
the approaching racer's inventory, health, recent pickups and attacks, opponent
range, smoothed gap to the leader, and the next 140 metres of road.

The director supplies opportunities on the road. It does not grant items, replace
carried inventory, change car performance, or alter weapon damage. Bots can take
the same advertised items as the player.

## Context and variety

- A sustained gap of more than 3.5 estimated seconds enables comeback weighting;
  it clears below 2 seconds, with a 3-second smoothing time to prevent flicker.
- Missing nitro is favored after a 12-second drought, especially when trailing.
  Immediate boost opportunities require a straight or gentle road ahead.
- Nearby opponents favor bolts and barges; reachable opponents favor eagles.
  Distant catch-up can favor leader-targeting storm instead of short-range bolts.
- Low health favors repair; recent hits favor shields. Healthy racers get no
  repair bias, and leaders get no new leader-targeting storm.
- Held nitro, shield, repair and storm are excluded from new choices. Other
  duplicates and recently collected types get lower weights. Each replanned row
  offers three distinct item types with randomized lane positions.
- New storm supply is reserved for 24 seconds after one is planned or fired,
  and is suppressed during active storms or the leader's recent recovery.
  Existing advertised/carried storms remain available; this is a supply limit,
  not a new weapon-use cooldown.

## Opportunities within the next 100–200 metres

The original Tirana station spacing is approximately 393 metres, so probability
changes alone cannot fill short resource droughts. Two extra three-lane rows are
preallocated, hidden and reused. After a 6-second opening period, a moving player
with spare inventory capacity may receive one of these rows 190–200 metres ahead
when an existing useful pickup does not cover the next 100–200 metres.

One lane offers a context-appropriate recovery, defence, boost or comeback item;
the remaining choices use utility-weighted randomness. Offers require at least
12 seconds and 240 metres of forward progress between them. They never respawn
after collection, and unused rows return to the pool after being safely passed.
There are at most six extra pickups, independent of race duration.

This distance is a planning target, not a promise to spawn in an unsafe location.
The director skips close existing stations, positions beyond the finish, unsuitable
immediate boosts, and points already in view on nearby streets or tight turns.
It never changes the icon a racer is currently approaching. A useful item may
be taken by a rival, and a full inventory receives no additional offer.

## Visibility and timing

Planning runs at 4 Hz on the fixed simulation clock. Normal rows are replanned
at most once per lap, only while complete and outside the player's 185-metre
world-distance guard and bots' 85-metre perception guard. The player guard covers
the 155-metre badge range, camera offsets and neighboring lanes. All lanes of an
extra row activate and retire together; collecting one never rerolls its remaining
choices.

The pickup view binds nodes by stable pickup ID. It updates changed symbols,
pad colors, positions and active flags together, including recycled extra rows.
Normal pickups retain the established two-second respawn with stable contents.

## Reproduction and diagnostics

`Race` enables the director by default. Pass `"adaptive_pickups": false` in race
options to compare the original fixed random stations. Adaptive decisions use a
separate seeded RNG so they do not consume the AI/combat random stream.

`race.pickup_director.snapshot()` returns counts for offered and collected help,
actual player collections and uses, all-racer collections and uses, the race seed,
and the last 64 planning decisions. Recent per-car item history is limited to
three entries. These diagnostics are also included under `pickups` in the existing
benchmark report (`user://profile.json`). Nothing is sent to an external service.

Run the targeted scenario test:

```sh
godot --headless --path godot res://tests/adaptive_pickups.tscn
```

The native test runner includes it alongside the existing race/controls/geometry
checks. Scenarios cover contextual supply distributions, shared collection,
inventory and storm limits, cooldowns, visibility on returning roads, lap seams,
reversed races, RNG isolation, visual synchronization, and a complete real Tirana
race starting 400 metres behind. Physical-phone playtesting is still needed to
tune the final rates, perceived fairness, and usefulness of each opportunity.
