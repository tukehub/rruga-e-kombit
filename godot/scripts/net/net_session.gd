class_name NetSession
extends RefCounted
## One peer of an online race over ENet (plan 7.2). The host's phone is the
## hub: clients connect only to it, it relays their inputs and hashes to the
## others, and it decides the lobby, the start and who dropped. Everything is
## sent reliable and in order on one channel; a race needs every input.
##
## Not a Node: the owner calls poll() every frame and reads the events it
## returns. lockstep is set once the race starts.

const PORT := 47651
const MAX_PLAYERS := 6
const CHANNELS := 1

var is_host := false
var name := ""
var slot := -1
## Player names by slot, as the host last announced them.
var names: Array = []
## Each player's paint (a Data.CARS id) by slot.
var cars: Array = []
## This phone's paint, sent with HELLO.
var car := ""
## The race everyone agreed on (START), {} until then.
var config: Dictionary = {}
var lockstep: Lockstep
var started := false

var _enet: ENetConnection
var _server: ENetPacketPeer          # client: the connection to the host
var _peers: Dictionary = {}          # host: ENetPacketPeer -> slot
var _closed := false


## Opens a lobby on this phone. OK, or the bind error (port in use).
func host(p_name: String, port := PORT, p_car := "") -> Error:
	_enet = ENetConnection.new()
	var err := _enet.create_host_bound("*", port, MAX_PLAYERS - 1, CHANNELS)
	if err != OK:
		_enet = null
		return err
	is_host = true
	name = p_name
	slot = 0
	names = [p_name]
	car = p_car
	cars = [p_car]
	return OK


## Connects to a host's lobby at `address` (an IP or host name).
func join(p_name: String, address: String, port := PORT, p_car := "") -> Error:
	_enet = ENetConnection.new()
	var err := _enet.create_host(1, CHANNELS)
	if err != OK:
		_enet = null
		return err
	_server = _enet.connect_to_host(address, port, CHANNELS)
	if _server == null:
		_enet = null
		return ERR_CANT_CONNECT
	name = p_name
	car = p_car
	return OK


## Host only: starts the race for everyone in the lobby. `race` holds the
## agreed options (seed, laps, diff, bots, city, env...); humans come from
## the lobby.
func start(race: Dictionary) -> void:
	if not is_host or started:
		return
	config = race.duplicate(true)
	var humans := []
	for i in names.size():
		humans.append({"name": names[i], "car": cars[i] if i < cars.size() else ""})
	config["humans"] = humans
	_broadcast(NetProto.start(config))
	_begin()


## Pumps the network. Returns what happened, oldest first:
## {t: "joined"} (client got its slot), {t: "lobby"}, {t: "start"},
## {t: "left", slot}, {t: "refused", why}, {t: "closed"}.
func poll() -> Array:
	var out := []
	if _enet == null:
		return out
	while true:
		var ev: Array = _enet.service(0)
		var type := int(ev[0])
		if type == ENetConnection.EVENT_NONE or type == ENetConnection.EVENT_ERROR:
			break
		var peer: ENetPacketPeer = ev[1]
		match type:
			ENetConnection.EVENT_CONNECT:
				if not is_host:
					_send(_server, NetProto.hello(name, car))
			ENetConnection.EVENT_DISCONNECT:
				if is_host:
					_host_lost(peer, out)
				elif not _closed:
					_closed = true
					out.append({"t": "closed"})
			ENetConnection.EVENT_RECEIVE:
				var bytes := peer.get_packet()
				if is_host:
					_host_got(peer, bytes, out)
				else:
					_client_got(bytes, out)
	if lockstep != null:
		for msg in lockstep.outbox:
			if is_host:
				_broadcast(msg)
			else:
				_send(_server, msg)
		lockstep.outbox.clear()
	_enet.flush()
	return out


## Leaves: tells the others (ENet notices) and frees the socket.
func close() -> void:
	if _enet == null:
		return
	if _server != null:
		_server.peer_disconnect()
	for peer in _peers:
		(peer as ENetPacketPeer).peer_disconnect()
	_enet.flush()
	_enet.destroy()
	_enet = null
	_closed = true


func _begin() -> void:
	lockstep = Lockstep.new(names.size(), slot)
	started = true


# ------------------------------------------------------------------ host

func _host_got(peer: ENetPacketPeer, bytes: PackedByteArray, out: Array) -> void:
	var msg := NetProto.decode(bytes)
	if msg.is_empty():
		return
	match int(msg.type):
		NetProto.HELLO:
			var why := ""
			if started:
				why = "started"
			elif names.size() >= MAX_PLAYERS:
				why = "full"
			elif int(msg.get("version", -1)) != NetProto.VERSION:
				why = "version"
			if not why.is_empty():
				_send(peer, NetProto.refuse(why))
				peer.peer_disconnect_later()
				return
			var their_name := str(msg.get("name", ""))
			_peers[peer] = names.size()
			names.append(their_name)
			cars.append(str(msg.get("car", "")))
			_send(peer, NetProto.welcome(int(_peers[peer])))
			_broadcast(NetProto.lobby(names, cars))
			out.append({"t": "lobby"})
		NetProto.INPUT, NetProto.HASH:
			# Trust the connection, not the message, for who sent it.
			if not started or int(msg.slot) != int(_peers.get(peer, -1)):
				return
			lockstep.receive(msg)
			_broadcast(bytes, peer)


func _host_lost(peer: ENetPacketPeer, out: Array) -> void:
	if not _peers.has(peer):
		return
	var gone := int(_peers[peer])
	_peers.erase(peer)
	if started:
		var from_tick := lockstep.first_missing(gone)
		lockstep.drop(gone, from_tick)
		_broadcast(NetProto.leave(gone, from_tick))
		out.append({"t": "left", "slot": gone})
		return
	# In the lobby the slots close up: everyone after the leaver moves down.
	names.remove_at(gone)
	if gone < cars.size():
		cars.remove_at(gone)
	for p in _peers:
		if int(_peers[p]) > gone:
			_peers[p] = int(_peers[p]) - 1
			_send(p, NetProto.welcome(int(_peers[p])))
	_broadcast(NetProto.lobby(names, cars))
	out.append({"t": "left", "slot": gone})


# ------------------------------------------------------------------ client

func _client_got(bytes: PackedByteArray, out: Array) -> void:
	var msg := NetProto.decode(bytes)
	if msg.is_empty():
		return
	match int(msg.type):
		NetProto.WELCOME:
			var first := slot < 0
			slot = int(msg.slot)
			if first:
				out.append({"t": "joined"})
		NetProto.LOBBY:
			names = msg.get("names", [])
			cars = msg.get("cars", [])
			out.append({"t": "lobby"})
		NetProto.START:
			config = msg
			config.erase("type")
			names = config.humans.map(func(h: Dictionary) -> String: return str(h.name))
			cars = config.humans.map(func(h: Dictionary) -> String: return str(h.get("car", "")))
			_begin()
			out.append({"t": "start"})
		NetProto.INPUT, NetProto.HASH:
			if lockstep != null:
				lockstep.receive(msg)
		NetProto.LEAVE:
			if lockstep != null:
				lockstep.drop(int(msg.slot), int(msg.tick))
			out.append({"t": "left", "slot": int(msg.slot)})
		NetProto.REFUSE:
			out.append({"t": "refused", "why": str(msg.get("why", ""))})


# ------------------------------------------------------------------ sending

func _send(peer: ENetPacketPeer, bytes: PackedByteArray) -> void:
	if peer != null and peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
		peer.send(0, bytes, ENetPacketPeer.FLAG_RELIABLE)


func _broadcast(bytes: PackedByteArray, except: ENetPacketPeer = null) -> void:
	for peer in _peers:
		if peer != except:
			_send(peer, bytes)
