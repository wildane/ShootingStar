extends "res://scene/Mob/HuskLurker/HuskLurker.gd"

# ==========================================================
# HUSK LURKER RAIDER
#
# Sama seperti HuskLurker biasa (stat, AI, lendir) tetapi:
#   - badan hijau, lendir kuning (aset berasingan)
#   - mati tidak menjatuhkan apa-apa (scene tiada DropComponent)
#   - masa muncul: animasi teleport (sama seperti pintu) + bunyi
#     teleport, kemudian baru badan kelihatan dan mula bergerak
# ==========================================================

const KESAN_TELEPORT := preload("res://scene/level_3/build_system/doorway/KesanTeleport.gd")

## Tempoh animasi teleport sebelum badan benar-benar muncul.
@export var masa_teleport: float = 0.4

var _dalam_teleport: bool = false
var _layer_asal: int = 128
var _mask_asal: int = 11

func _ready() -> void:
	super._ready()
	_layer_asal = collision_layer
	_mask_asal = collision_mask
	# Badan belum wujud sehingga animasi teleport habis.
	_dalam_teleport = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	if sprite:
		sprite.visible = false
	# Spawner menetapkan posisi selepas add_child, jadi kesan teleport mesti
	# dimulakan selepas itu (deferred) supaya berlaku di tempat yang betul.
	call_deferred("_mula_teleport")

func _physics_process(delta: float) -> void:
	# Semasa berteleport raider belum wujud pada skrin: jangan bergerak,
	# jangan menembak, dan jangan boleh ditembak.
	if _dalam_teleport:
		return
	super._physics_process(delta)

# Kesan teleport + bunyi dimainkan dahulu, badan disembunyikan.
func _mula_teleport() -> void:
	_dalam_teleport = true
	set_physics_process(false)
	if sprite:
		sprite.visible = false
	collision_layer = 0
	collision_mask = 0

	var pusat: Vector2 = global_position
	_main_kesan(pusat)
	Sfx.mainkan_di("teleport", pusat, -5.0)
	print("Raider: teleport masuk di ", pusat)

	await get_tree().create_timer(masa_teleport).timeout
	if not is_instance_valid(self) or sedang_mati:
		return
	_keluar_dari_teleport()

func _main_kesan(pada: Vector2) -> void:
	var induk := get_parent()
	if induk == null or not is_instance_valid(induk):
		return
	var kesan := KESAN_TELEPORT.new()
	kesan.muncul = true
	induk.add_child(kesan)
	kesan.global_position = pada

# Badan muncul semula dengan kilau singkat, kemudian AI berjalan seperti biasa.
func _keluar_dari_teleport() -> void:
	_dalam_teleport = false
	collision_layer = _layer_asal
	collision_mask = _mask_asal
	# sprite.modulate dikawal oleh animasi HuskLurker setiap frame, jadi
	# kilau muncul cukup dengan menyembunyi/menunjukkan sprite.
	if sprite:
		sprite.visible = true
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		sprite.scale = skala_asas
	set_physics_process(true)
	print("Raider: muncul dan mula bergerak")
