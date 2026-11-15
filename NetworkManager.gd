extends Node

var socket := WebSocketPeer.new()

var user_id := ""
var username := ""

signal world_update(players)
signal init_received(data)

var is_ready := false


func connect_server(url: String):
	print("[Network] Connecting:", url)
	socket.connect_to_url(url)


func send(data: Dictionary):

	if not is_ready:
		return

	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	socket.send_text(JSON.stringify(data))


func _process(delta):

	socket.poll()

	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not is_ready:
			is_ready = true
			print("[Network] READY ✔")

	while socket.get_available_packet_count() > 0:

		var msg = socket.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(msg)

		if typeof(data) != TYPE_DICTIONARY:
			continue

		if data.has("type") and data.type == "init":
			user_id = data.id
			init_received.emit(data)

		if data.has("type") and data.type == "world":
			if data.has("players"):
				world_update.emit(data.players)