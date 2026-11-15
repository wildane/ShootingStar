extends Node
class_name AstroAntaramuka

var astro: CharacterBody2D  # Rujukan kepada Astro2 utama

# ==========================================================
# KAWALAN PAPAN KEKUNCI (WASD)
# Berfungsi dalam kedua-dua state (Base & Angkasa).
# Joystick sentuh KEKAL diutamakan: kalau jari sedang menekan,
# WASD diabaikan sepenuhnya untuk state itu.
# ==========================================================
@export_group("Papan Kekunci (WASD)")
@export var papan_kekunci_aktif: bool = true

func arah_papan_kekunci() -> Vector2:
	if not papan_kekunci_aktif:
		return Vector2.ZERO

	var arah := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		arah.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		arah.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		arah.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		arah.y += 1.0

	if arah == Vector2.ZERO:
		return Vector2.ZERO
	return arah.normalized()

# Gabungkan joystick sentuh dengan WASD. Sentuhan menang bila aktif.
func arah_gabungan(arah_joystick: Vector2) -> Vector2:
	if arah_joystick.length() > 0.01:
		return arah_joystick
	return arah_papan_kekunci()

func masuk_state() -> void:
	pass

func keluar_state() -> void:
	pass

func kendalikan_input(_event: InputEvent) -> void:
	pass

func kemas_kini_fizik(_delta: float) -> void:
	pass
