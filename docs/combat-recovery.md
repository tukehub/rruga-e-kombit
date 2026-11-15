# Combat information, recovery and driving rewards

Combat uses the existing track-frame physics. `sim/combat_rules.gd` owns the
read-only readiness/target/utility queries used by both simulation and presentation;
these queries consume no random numbers and retain no race references.

## Threats and item readiness

The HUD shows incoming homing projectiles targeting the player within an estimated
four seconds and 240 track metres. It reports approach from ahead/behind and the
side, becomes urgent at 1.25 seconds, and shows how many threats are approaching.
Quiet cues repeat at most once per second, or every 0.4 seconds when urgent. A
shield predicted to last until arrival changes the warning to protected and
silences that cue. Estimates use projectile direction, speed, lifetime and closing
speed; they can change as cars accelerate. Finished, wrecked and respawn-protected
players have no incoming alarm. Track wrapping and reverse races use the same rules.

Selected-item hints identify a target and distance, a shielded target, free fire,
or the reason a target is unavailable. Homing shots require a live, reachable
target; target search also considers projectile flight lifetime/acceleration.
Respawn-protected or wrecked targets are excluded. Barge requires a rival inside
its 15-metre radius. Bolts and mines retain deliberate free fire/trap placement.

Empty inventory, race phase, spin/wreck, full-health repair, leading Shock, an
already active forward Nitro/shield, protected leader or existing storm all have
specific explanations. Disabled actions still accept a tap for this explanation
without firing or consuming the item. Feedback is throttled and wraps to two
visible lines above the steering side. New storms wait until existing domes end
and the leader's recovery/respawn protection expires. Reverse Nitro still consumes
the item to brake; it also cancels an active turbo.

Numeric seconds and bars show shield, Nitro/earned turbo, anti-chain recovery and
respawn protection. At 25% health or below, an explicit critical percentage and a
slow, subtle border pulse reinforce the health bar. The critical cue is limited
to once per eight seconds. Racing UI/cues stop during pause; the pause controls
remain interactive. Focus loss, finish and layout changes clear pending actions.

## Bounded disabling chains

The first unblocked disabling hit keeps its normal damage and effects and starts
a fixed **3.5-second recovery window**. Further hits during that window:

- Apply **65% of normal damage** and still can wreck the car.
- Cannot apply or refresh spin, stun, slowing, hop or lateral push.
- Cannot extend the recovery window.

The longest existing stun is 2.2 seconds, leaving a period to drive again before
another disabling attack can take effect. All racers use this policy. Shield and
the existing 2.5-second respawn invulnerability still block the hit completely;
wreck/respawn clear anti-chain state. Follow-up hit shake/flash/haptics are weaker
and limited to once per 0.35 seconds; their quieter impact cue is rate-limited.

## Inventory policy

The selected item has a cyan border and is protected from automatic replacement.
A short tap selects an item; tapping the selected item cycles existing inventory.
Holding any slot for **0.65 seconds** fills its progress line and explicitly
discards that exact item. One inventory finger owns the gesture; steering can
stay held with the other thumb. Dragging outside, cancellation, focus loss,
pause, resize or a changed inventory cancels an unfinished gesture. A queued
discard identifies the dictionary instance rather than an old slot index, and
cannot accidentally fire the item that shifts into its place.

With three slots occupied, collecting a useful, nonduplicate advertised road
item may replace an **unselected** repair at 97%+ health or Shock while leading.
Other reserves are preserved, including useful repair and temporarily active
shield/Nitro reserves. A replacement keeps the selected item/ammo and reports
the old and new items. Leadership is checked from live progress, so an overtake
before standings update immediately protects a now-useful Shock reserve.

The pickup director uses this same capacity policy. Full useful inventories get
no extra offer; a full inventory with an eligible blocked reserve can receive a
useful replacement opportunity. Storm supply also respects recovery/invulnerability.
Items remain shared, advertised and bounded by the existing pickup pool.

## Earned drift turbo

**100 metres of qualified forward drifting** banks one **1.25-second turbo**.
Charge persists between corners and hits, caps at one, and is spent using the
button beside inventory or keyboard **B**. Its side mirrors with the controls.
The button shows charge percentage and changes to TURBO when ready. Existing
fans are still awarded; no item slot is required or consumed.

Charging requires actual forward distance, manual brake/steer, established drift,
18+ m/s and no wall scraping, spin/stun, recovery, invulnerability, airtime or
active turbo. Distance is bounded by vehicle speed so curvature cannot amplify
it. Stationary steering and reversing earn nothing. An active turbo blocks spending
another earned boost while preserving charge. Bots follow the same rules. Earned
speed ends the director's boost drought without recording a road-item use.

## Verification and tuning

The native runner includes `combat_recovery.tscn` and `combat_ui.tscn` alongside
the existing 13 scenes. Scenarios cover real item use/denials, forecast warnings,
reversed/lap-seam targeting, a dense ten-second attack stream, respawn, shared
inventory/adaptive utility, identity-safe discard, actual two-pointer viewport
input, canceled/stale holds, fixed-tick latching, duration bars, critical health,
feedback/boost layout clearance and frame-rate-independent charge.

The benchmark's `combat` list reports softened follow-up hits, earned boosts used
and current charge per racer; existing `pickups` diagnostics remain available.
Mobile-renderer desktop screenshots check layout and readable feedback. Physical
phone playtesting is still needed for threat timing, sound levels, hold comfort,
boost frequency and competitive balance under sustained offense.
