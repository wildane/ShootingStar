extends StaticBody2D

const KESAN_TELEPORT := preload("res://scene/level_3/build_system/doorway/KesanTeleport.gd")

@onready var sprite := $Sprite2D
@onready var area := $Area2D

var player_in_range := false
var cooldown := 0.0
const COOLDOWN := 0.2

# Tetapkan koordinat statik kamu di sini
const OUTSIDE_POS := Vector2(144, 200)
const INSIDE_POS := Vector2(144, 128)


func _ready():
	# Robot pekerja cari pintu melalui group ini.
	add_to_group("Pintu")
	area.input_pickable = true
	area.body_entered.connect(_on_enter)
	area.body_exited.connect(_on_exit)
	area.input_event.connect(_on_input)


# =========================
# ENTER RANGE
# =========================
func _on_enter(body):
	if _ialah_pemain(body):
		player_in_range = true
		if sprite:
			sprite.modulate = Color(0.3, 1.0, 0.3) # GREEN


# =========================
# EXIT RANGE
# =========================
func _on_exit(body):
	if _ialah_pemain(body):
		player_in_range = false
		if sprite:
			sprite.modulate = Color(1, 1, 1)


# Robot pekerja juga CharacterBody2D, jadi klik pintu mesti kekal milik
# pemain sahaja. Tanpa semakan ini, klik pemain boleh teleport robot.
func _ialah_pemain(body) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	return body.is_in_group("Player") or body.name == "Player" or body.name == "SpaceShip"


# =========================
# KLIK MOUSE PADA PC
# =========================
# AstroStateMachine menukar setiap klik kiri mouse menjadi sentuhan maya dan
# menandakan event sebagai "handled" dalam _unhandled_input. Bila event sudah
# handled, physics picking untuk Area2D dibatalkan, jadi input_event pintu
# tidak pernah dicetus pada PC. Tangkap klik mouse di sini kerana _input
# berjalan sebelum _unhandled_input, kemudian hantar ke pengendali yang sama.
func _input(event: InputEvent) -> void:
	var klik := event as InputEventMouseButton
	if klik == null:
		return
	if not klik.pressed or klik.button_index != MOUSE_BUTTON_LEFT:
		return
	if not player_in_range or cooldown > 0:
		return
	# Jangan rampas klik yang sepatutnya milik butang/panel UI.
	var kawalan := get_viewport().gui_get_hovered_control()
	if kawalan != null and kawalan.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return
	if _klik_dalam_kawasan(event.position) and _get_player() != null:
		var sentuhan := InputEventScreenTouch.new()
		sentuhan.index = 0
		sentuhan.position = event.position
		sentuhan.pressed = true
		_on_input(get_viewport(), sentuhan, 0)
		get_viewport().set_input_as_handled()


# Zon klik pintu mengikut dua CollisionShape2D pada Area2D, dengan sedikit
# toleransi supaya hujung bucu sprite tetap boleh diklik.
func _klik_dalam_kawasan(pos_skrin: Vector2) -> bool:
	var titik := to_local(get_canvas_transform().affine_inverse() * pos_skrin)
	return Rect2(Vector2(-11.0, -41.0), Vector2(22.0, 45.0)).has_point(titik)


# =========================
# CLICK / TAP TO TELEPORT
# =========================
func _on_input(_viewport, event, _shape_idx):
	if not player_in_range:
		return

	if cooldown > 0:
		return

	var pressed := false

	if event is InputEventScreenTouch:
		pressed = event.pressed

	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if pressed:
		cooldown = COOLDOWN
		var player = _get_player()

		if player:
			# Ambil rujukan pusat State Machine milik pemain
			var sm = player.get_node_or_null("StateMachine")
			
			if player.global_position.y > global_position.y:
				_teleport_badan(player, INSIDE_POS)
				print("[DOOR] Pemain di luar, Teleport MASUK →", INSIDE_POS)
				
				# PEMBETULAN: Mengikut map anda, INSIDE_POS sepatutnya mengaktifkan MOD ANG KASA
				if sm:
					var state_angkasa = sm.get_node_or_null("AngkasaState")
					if state_angkasa:
						sm.tukar_state(state_angkasa)
			
			else:
				_teleport_badan(player, OUTSIDE_POS)
				print("[DOOR] Pemain di dalam, Teleport KELUAR →", OUTSIDE_POS)
				
				# PEMBETULAN: Mengikut map anda, OUTSIDE_POS sepatutnya mengaktifkan MOD BASE
				if sm:
					var state_base = sm.get_node_or_null("BaseState")
					if state_base:
						sm.tukar_state(state_base)


# =========================
# ROBOT LALU SENDIRI (tanpa klik pemain)
# =========================
# Dua sisi pintu ini. Sistem navigasi robot guna titik ini untuk menyambung
# laluan, jadi robot tahu pintu mana yang perlu dilalui.
func titik_pintasan() -> Array[Vector2]:
	return [INSIDE_POS, OUTSIDE_POS]


# Robot pekerja panggil fungsi ini bila ia sampai di pintu. Teleport
# mengikut sisi yang sama seperti klik pemain, jadi robot boleh masuk
# dan keluar kawasan walaupun pintu itu asalnya perlu diklik.
func lalu_automatik(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.global_position.y > global_position.y:
		_teleport_badan(body, INSIDE_POS)
	else:
		_teleport_badan(body, OUTSIDE_POS)


# =========================
# KESAN TELEPORT
# =========================
# Pindahkan badan ke titik teleport sambil memainkan animasi di kedua-dua
# hujung pintu: badan "hilang" di tempat lama, "muncul" di tempat baru.
func _teleport_badan(body: Node2D, pos_baru: Vector2) -> void:
	var pos_lama: Vector2 = body.global_position
	_main_kesan(body, pos_lama, false)
	Sfx.mainkan_di("teleport", pos_lama, -5.0)
	body.global_position = pos_baru
	_main_kesan(body, pos_baru, true)
	Sfx.mainkan_di("teleport", pos_baru, -10.0, 1.08)
	_kelip_badan(body)


func _main_kesan(body: Node2D, pada: Vector2, muncul: bool) -> void:
	var induk := body.get_parent()
	if induk == null or not is_instance_valid(induk):
		return
	var kesan := KESAN_TELEPORT.new()
	kesan.muncul = muncul
	induk.add_child(kesan)
	kesan.global_position = pada


# Kilau putih singkat pada badan sendiri supaya perpindahan terasa seperti
# teleport, bukan lompat terus. Modulate asal dipulihkan selepas itu.
func _kelip_badan(body: Node2D) -> void:
	var asal: Color = body.modulate
	body.modulate = Color(2.0, 2.0, 2.0, 0.35)
	var tw := body.create_tween()
	tw.tween_property(body, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.12)
	tw.tween_property(body, "modulate", asal, 0.2)


# =========================
# GET PLAYER IN AREA
# =========================
func _get_player():
	for body in area.get_overlapping_bodies():
		if _ialah_pemain(body):
			return body
	return null


func _process(delta):
	if cooldown > 0:
		cooldown -= delta
