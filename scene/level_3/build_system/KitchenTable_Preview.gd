extends Node2D

@onready var sprite = $Sprite2D
@onready var area_penderia = $Area2D 

var boleh_pasang: bool = false

func _ready() -> void:
	z_index = 100 
	if sprite:
		sprite.modulate = Color(1.0, 0.3, 0.3, 0.5) # Mula dengan MERAH (Sistem Kitchen Table)

	if area_penderia:
		area_penderia.monitoring = true
		area_penderia.monitorable = false

func _physics_process(_delta: float) -> void:
	# _physics_process wajib digunakan supaya pengiraan saiz Scale dari Inspector 
	# disinkronasikan dengan tepat oleh enjin fizik Godot tanpa herotan.
	if mod_pembinaan_aktif():
		imbas_menggunakan_skala_inspector()

func mod_pembinaan_aktif() -> bool:
	# Memastikan imbasan hanya berjalan semasa mod bina Kitchen Table aktif
	return is_instance_valid(area_penderia)

func imbas_menggunakan_skala_inspector() -> void:
	# Ambil data objek yang bertindih (Godot automatik gandakan saiz ikut Scale Inspector)
	var semua_badan = area_penderia.get_overlapping_bodies()
	var semua_kawasan = area_penderia.get_overlapping_areas()

	var atas_lantai: bool = false
	var kena_halangan: bool = false

	# 1. CARI HALANGAN FIZIKAL (Dinding StaticBody2D / Player CharacterBody2D)
	for body in semua_badan:
		if not is_instance_valid(body): continue
		if body.get_collision_layer_value(1) or body.get_collision_layer_value(2):
			kena_halangan = true
			break

	# 2. CARI HALANGAN KAWASAN (Jika dinding ada Area2D juga di Layer 1 atau 2)
	if not kena_halangan:
		for area in semua_kawasan:
			if not is_instance_valid(area): continue
			if area.get_collision_layer_value(1) or area.get_collision_layer_value(2):
				kena_halangan = true
				break

	# 3. JIKA BERSIH HALANGAN, BARULAH SEMAK ZON LANTAI (Layer 3 atau 4)
	if not kena_halangan:
		for area in semua_kawasan:
			if not is_instance_valid(area): continue
			if area.get_collision_layer_value(3) or area.get_collision_layer_value(4):
				atas_lantai = true
				break

	# 4. KEPUTUSAN MUTLAK WARNA HOLOGRAM KITCHEN TABLE
	if kena_halangan:
		if sprite: sprite.modulate = Color(1.0, 0.3, 0.3, 0.5) # MERAH (Disekat)
		boleh_pasang = false
	elif atas_lantai:
		if sprite: sprite.modulate = Color(0.3, 1.0, 0.3, 0.5) # HIJAU (Boleh Pasang)
		boleh_pasang = true
	else:
		if sprite: sprite.modulate = Color(1.0, 0.3, 0.3, 0.5) # MERAH (Tiada Lantai)
		boleh_pasang = false
