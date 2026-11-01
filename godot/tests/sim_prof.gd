extends Node
## Quick profile: how long does track build + N sim steps take?

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var track := RaceTrack.load_city("tirane")
	print("track load: %d ms  %s" % [Time.get_ticks_msec() - t0, str(track.stats())])
	t0 = Time.get_ticks_msec()
	var race := Race.new(track, {"laps": 2, "diff": 1, "seed": 42, "no_player": true})
	race.started = true
	print("race init: %d ms" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()
	var dt := 1.0 / 60.0
	for i in 60:
		race.step(dt)
		race.take_events()
	print("60 steps: %d ms" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()
	for chunk in 80:
		var tc := Time.get_ticks_msec()
		for i in 300:
			race.step(dt)
			race.take_events()
		var lead := race.order[0]
		print("t=%5.1f  chunk %d ms  lead %s s=%.0f lap=%d v=%.1f  projs=%d mines=%d domes=%d" % [
			race.time, Time.get_ticks_msec() - tc, lead.name, lead.s, lead.lap, lead.v,
			race.projs.size(), race.mines.size(), race.domes.size()])
		if race.all_finished():
			break
	print("total: %d ms" % (Time.get_ticks_msec() - t0))
	for c in race.order:
		print("  P%d %-22s s=%.0f v=%.1f lap=%d hp=%.0f" % [c.place, c.name, c.s, c.v, c.lap, c.health])
	get_tree().quit(0)
