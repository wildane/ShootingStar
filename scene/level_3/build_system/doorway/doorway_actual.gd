extends StaticBody2D

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
			
			# 100% LOGIK ASAL KAMU (TIDAK DIUBAH SAMA SEKALI)
			if player.global_position.y > global_position.y:
				player.global_position = INSIDE_POS
				print("[DOOR] Pemain di luar, Teleport MASUK →", INSIDE_POS)
				
				# PEMBETULAN: Mengikut map anda, INSIDE_POS sepatutnya mengaktifkan MOD ANG KASA
				if sm:
					var state_angkasa = sm.get_node_or_null("AngkasaState")
					if state_angkasa:
						sm.tukar_state(state_angkasa)
			
			else:
				player.global_position = OUTSIDE_POS
				print("[DOOR] Pemain di dalam, Teleport KELUAR →", OUTSIDE_POS)
				
				# PEMBETULAN: Mengikut map anda, OUTSIDE_POS sepatutnya mengaktifkan MOD BASE
				if sm:
					var state_base = sm.get_node_or_null("BaseState")
					if state_base:
						sm.tukar_state(state_base)


# =========================
# ROBOT LALU SENDIRI (tanpa klik pemain)
# =========================
# Robot pekerja panggil fungsi ini bila ia sampai di pintu. Teleport
# mengikut sisi yang sama seperti klik pemain, jadi robot boleh masuk
# dan keluar kawasan walaupun pintu itu asalnya perlu diklik.
func lalu_automatik(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.global_position.y > global_position.y:
		body.global_position = INSIDE_POS
	else:
		body.global_position = OUTSIDE_POS


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
