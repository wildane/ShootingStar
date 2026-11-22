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

# ==========================================================
# SAMBUNG KAWALAN SENTUH MERENTAS STATE
# State bertukar ketika jari masih menekan skrin. State baru mengambil
# semula jari itu sebagai joystick (dan sasaran click-to-move) supaya player
# terus bergerak tanpa perlu angkat jari dan tekan semula.
# ==========================================================
func warisi_kawalan_sentuh(julat_joystick: float, zon_mati: float) -> Dictionary:
	var hasil := {
		"ada": false,
		"id": -1,
		"pusat": Vector2.ZERO,
		"arah": Vector2.ZERO,
		"sentuhan": {},
		"sasaran_ada": false,
		"sasaran_pos": Vector2.ZERO,
	}
	if astro == null:
		return hasil

	var sm = astro.get_node_or_null("StateMachine")
	if sm == null:
		return hasil

	var sentuhan: Dictionary = sm.jari_tertekan.duplicate()
	hasil["sentuhan"] = sentuhan
	hasil["sasaran_ada"] = bool(sm.sasaran_lama_ada)
	hasil["sasaran_pos"] = sm.sasaran_lama_pos

	if sm.jari_joystick == -1 or not sentuhan.has(sm.jari_joystick):
		return hasil

	var id: int = sm.jari_joystick
	var posisi: Vector2 = sentuhan[id]
	var pusat: Vector2 = sm.pusat_jari.get(id, posisi)
	var julat: float = maxf(julat_joystick, 1.0)
	var delta: Vector2 = posisi - pusat
	if delta.length() > julat:
		delta = delta.limit_length(julat)
	var normalized: Vector2 = delta / julat

	hasil["ada"] = true
	hasil["id"] = id
	hasil["pusat"] = pusat
	hasil["arah"] = Vector2.ZERO if normalized.length() < zon_mati else normalized
	return hasil

# ==========================================================
# JET PACK (Zarah api di belakang SpriteAngkasa)
# Semasa sprite angkasa disembunyikan (dalam asteroid), zarah jet boleh
# "tersangkut" di tempat lama. Setiap kali state bertukar, jet dimatikan
# dan masa zarahnya di-reset supaya tiada api tertinggal di tempat lama.
# ==========================================================
func set_jet_aktif(hidup: bool) -> void:
	if astro == null:
		return
	var jet := astro.get_node_or_null("SpriteAngkasa/JetThruster") as CPUParticles2D
	if jet == null:
		return
	if hidup:
		jet.emitting = true
		return
	jet.emitting = false
	# restart() menghidupkan semula `emitting`, jadi ia dimatikan selepas ini.
	jet.restart()
	jet.emitting = false

func masuk_state() -> void:
	pass

func keluar_state() -> void:
	pass

func kendalikan_input(_event: InputEvent) -> void:
	pass

func kemas_kini_fizik(_delta: float) -> void:
	pass
