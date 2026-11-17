extends Node
## Plan 7.2: online races over real ENet sockets on this machine. The wire
## format, the lockstep bookkeeping (delay, stalls, desync detection), then a
## lobby of three phones (host + two clients) that race 20 s in lockstep with
## equal state hashes; one client drops mid-race, a bot takes its car on the
## same tick everywhere, and the two who stay remain in sync. Late joiners and
## wrong versions are refused.

const DT := 1.0 / 60.0

var failures := 0
var events := {}


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)


func _track() -> RaceTrack:
	var track := RaceTrack.new()
	track.build({"id": "tirane", "hw": 10.0, "pts": [[-700.0, 0.0, -700.0], [700.0, 0.0, -700.0], [700.0, 0.0, 700.0], [-700.0, 0.0, 700.0]]}, false)
	return track


## Polls every session until `done` is true or `ms` pass; records events.
func pump(sessions: Array, done: Callable, ms := 3000) -> bool:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		for s in sessions:
			for e in s.poll():
				if not events.has(s):
					events[s] = []
				events[s].append(e)
		if done.call():
			return true
		OS.delay_msec(1)
	return false


func got(s: NetSession, t: String) -> bool:
	return events.get(s, []).any(func(e: Dictionary) -> bool: return e.t == t)


func scripted(slot: int, tick: int) -> PackedByteArray:
	var c := CarState.Ctrl.new()
	c.steer = sin(tick * 0.02 + slot) * 0.7
	c.gas = (tick + slot * 7) % 97 != 0
	c.brake = (tick + slot * 11) % 131 == 0
	c.fire = (tick + slot * 13) % 211 == 0
	return c.pack([])


func _ready() -> void:
	# --- wire format
	var m := NetProto.decode(NetProto.input(3, 70000, PackedByteArray([1, 2, 3, 4])))
	check(m.type == NetProto.INPUT and m.slot == 3 and m.tick == 70000 and m.ctrl == PackedByteArray([1, 2, 3, 4]), "input messages round-trip")
	m = NetProto.decode(NetProto.hash_msg(2, 90, -1234567890123))
	check(m.type == NetProto.HASH and m.hash == -1234567890123 and m.tick == 90, "hash messages round-trip")
	m = NetProto.decode(NetProto.start({"seed": 5, "humans": [{"name": "Ana"}]}))
	check(m.type == NetProto.START and m.seed == 5 and m.humans[0].name == "Ana", "start messages round-trip")
	m = NetProto.decode(NetProto.leave(4, 1234))
	check(m.type == NetProto.LEAVE and m.slot == 4 and m.tick == 1234, "leave messages round-trip")
	check(NetProto.decode(PackedByteArray([NetProto.INPUT, 1])).is_empty() and NetProto.decode(PackedByteArray()).is_empty() and NetProto.decode(PackedByteArray([99, 1, 2])).is_empty(), "malformed messages are ignored")
	check(NetProto.input(0, 0, CarState.Ctrl.new().pack([])).size() == 10, "an input is 10 bytes on the wire")

	# --- lockstep bookkeeping, no sockets
	var a := Lockstep.new(2, 0)
	var b := Lockstep.new(2, 1)
	check(a.can_step(), "the first DELAY ticks need no input")
	for i in Lockstep.DELAY:
		a.submit(scripted(0, i))
		a.take()
	a.submit(scripted(0, Lockstep.DELAY))
	check(not a.can_step(), "after that, a missing input stalls")
	for msg in a.outbox:
		b.receive(NetProto.decode(msg))
	for i in Lockstep.DELAY + 1:
		b.submit(scripted(1, i))
		if b.can_step():
			b.take()
	for msg in b.outbox:
		a.receive(NetProto.decode(msg))
	check(a.can_step(), "it steps once the other input arrives")
	var x := Lockstep.new(2, 0)
	x.receive(NetProto.decode(NetProto.hash_msg(1, 30, 111)))
	x._note_hash(30, 0, 222)
	check(x.desync_tick == 30, "different hashes for a tick are a desync on that tick")
	var y := Lockstep.new(2, 0)
	y.receive(NetProto.decode(NetProto.hash_msg(1, 30, 111)))
	y._note_hash(30, 0, 111)
	check(y.desync_tick == -1 and y._hashes.is_empty(), "equal hashes settle and are forgotten")
	y.drop(1, 10)
	check(y.is_bot(1, 10) and not y.is_bot(1, 9), "a dropped slot turns bot from its tick")

	# --- a real lobby on this machine
	var port := 40000 + randi() % 20000
	var host := NetSession.new()
	var c1 := NetSession.new()
	var c2 := NetSession.new()
	check(host.host("Ana", port) == OK, "the host opens a lobby")
	check(c1.join("Ben", "127.0.0.1", port) == OK and c2.join("Cel", "127.0.0.1", port) == OK, "two phones join it")
	var all := [host, c1, c2]
	check(pump(all, func() -> bool: return c1.slot > 0 and c2.slot > 0 and host.names.size() == 3 and c1.names.size() == 3 and c2.names.size() == 3), "both get a slot and everyone sees the same lobby")
	check(host.names == c1.names and c1.names == c2.names and host.names[0] == "Ana" and c1.slot != c2.slot, "names by slot agree: %s" % [host.names])
	# A phone with another game version: a raw connection sending its own HELLO.
	var wrong := ENetConnection.new()
	wrong.create_host(1, NetSession.CHANNELS)
	var wrong_peer := wrong.connect_to_host("127.0.0.1", port, NetSession.CHANNELS)
	var refused := [false]
	var poll_wrong := func() -> bool:
		while true:
			var ev: Array = wrong.service(0)
			if int(ev[0]) == ENetConnection.EVENT_CONNECT:
				wrong_peer.send(0, NetProto._dict(NetProto.HELLO, {"name": "Old", "version": NetProto.VERSION + 1}), ENetPacketPeer.FLAG_RELIABLE)
			elif int(ev[0]) == ENetConnection.EVENT_RECEIVE:
				refused[0] = refused[0] or int(NetProto.decode(wrong_peer.get_packet()).get("type", 0)) == NetProto.REFUSE
			else:
				break
		return refused[0]
	check(pump(all, poll_wrong), "a different game version is refused")
	check(host.names.size() == 3 and c1.names.size() == 3, "and never takes a slot")
	wrong.destroy()

	host.start({"seed": 77, "laps": 2, "diff": 1, "bots": 2})
	check(pump(all, func() -> bool: return c1.started and c2.started), "the start reaches everyone")
	check(c1.config.seed == 77 and c2.config.humans.size() == 3 and c2.config.bots == 2, "with the host's settings and the lobby's humans")
	var late := NetSession.new()
	late.join("Dea", "127.0.0.1", port)
	check(pump(all + [late], func() -> bool: return got(late, "refused")), "a phone joining a running race is refused")
	late.close()

	var track := _track()
	var nets := []
	for s in all:
		var race := Race.new(track, NetRace.race_options(s.config))
		race.started = true
		nets.append(NetRace.new(race, s.lockstep))
	check(nets.all(func(n: NetRace) -> bool: return n.race.cars.size() == 5 and n.race.humans.size() == 3), "three humans and two bots on every phone")
	check(nets[1].local_car().name == c1.names[c1.slot] and nets[0].race.humans[0].name == "Ana", "each phone drives its own car")
	check(nets[0].race.state_hash() == nets[1].race.state_hash() and nets[1].race.state_hash() == nets[2].race.state_hash(), "every phone builds the same grid")

	# Race 20 s; client 2 leaves after 8 s.
	var target := 60 * 20
	var leave_at := 60 * 8
	var c2_gone := false
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		for i in all.size():
			var s: NetSession = all[i]
			if i == 2 and c2_gone:
				continue
			for e in s.poll():
				if not events.has(s):
					events[s] = []
				events[s].append(e)
			var n: NetRace = nets[i]
			for k in 4:
				if n.lockstep.tick >= target or (i == 2 and n.lockstep.tick >= leave_at):
					break
				if not n.step(scripted(s.slot, n.lockstep.tick + Lockstep.DELAY)):
					break
		if not c2_gone and nets[2].lockstep.tick >= leave_at:
			c2.close()
			c2_gone = true
		if nets[0].lockstep.tick >= target and nets[1].lockstep.tick >= target:
			break
	var h: NetRace = nets[0]
	var k1: NetRace = nets[1]
	check(h.lockstep.tick >= target and k1.lockstep.tick >= target, "the two who stayed finished 20 s (%d / %d ticks)" % [h.lockstep.tick, k1.lockstep.tick])
	check(h.lockstep.desync_tick < 0 and k1.lockstep.desync_tick < 0, "no desync reported (%d / %d)" % [h.lockstep.desync_tick, k1.lockstep.desync_tick])
	check(h.race.state_hash() == k1.race.state_hash(), "and their races are identical at the end")
	check(h.lockstep.gone.has(2) and k1.lockstep.gone.has(2) and int(h.lockstep.gone[2]) == int(k1.lockstep.gone[2]), "both turned the leaver's car into a bot on the same tick")
	check(int(h.lockstep.gone.get(2, 0)) >= leave_at and not h.race.humans[2].is_player, "no earlier than its last input")
	check(h.race.humans[2].progress > nets[2].race.humans[2].progress + 50.0, "and the bot kept driving it")
	check(got(host, "left") and got(c1, "left"), "everyone was told")
	print("net stalls host=%d client=%d" % [h.lockstep.stalls, k1.lockstep.stalls])

	host.close()
	c1.close()
	print("net_session: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
