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
	area.body_entered.connect(_on_enter)
	area.body_exited.connect(_on_exit)
	area.input_event.connect(_on_input)


# =========================
# ENTER RANGE
# =========================
func _on_enter(body):
	if body is CharacterBody2D:
		player_in_range = true
		if sprite:
			sprite.modulate = Color(0.3, 1.0, 0.3) # GREEN


# =========================
# EXIT RANGE
# =========================
func _on_exit(body):
	if body is CharacterBody2D:
		player_in_range = false
		if sprite:
			sprite.modulate = Color(1, 1, 1)


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
# GET PLAYER IN AREA
# =========================
func _get_player():
	for body in area.get_overlapping_bodies():
		if body is CharacterBody2D:
			return body
	return null


func _process(delta):
	if cooldown > 0:
		cooldown -= delta
