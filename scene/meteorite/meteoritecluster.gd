# ==========================================================
# FAIL: meteoritecluster.gd (Versi Penuh Bersatu - Bebas Ralat)
# ==========================================================
extends Area2D

# Kelajuan perlahan mengikut kod base asal anda
var speed: float = 0.03
var rotation_speed: float = 0.03
var direction: Vector2 = Vector2.RIGHT
var max_radius: float = 300.0

# Menggunakan kedudukan global untuk ketepatan 100%
var global_center_position: Vector2 = Vector2.ZERO

# Pembolehubah untuk Mekanik Perlombongan (Mining HP)
var hp: int = 5
var is_being_mined: bool = false
var mine_timer: float = 0.0

# 🔥 KUNCI PEMBAIKAN: Pembolehubah kelipan strobo wajib diisytiharkan di atas fail
var is_flashing_burst: bool = false
var burst_flash_timer: float = 0.0
var burst_duration_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D 
@onready var spark_vfx: CPUParticles2D = $SparkVFX 

func _ready() -> void:
	direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	rotation_speed = randf_range(-0.1, 0.1)
	
	# Menyambung isyarat perlanggaran
	body_entered.connect(_on_objek_masuk)
	body_exited.connect(_on_objek_keluar)
	area_entered.connect(_on_objek_masuk)
	area_exited.connect(_on_objek_keluar)
	
	if spark_vfx:
		spark_vfx.emitting = false
		spark_vfx.visible = false

func _process(delta: float) -> void:
	global_position += direction * speed * delta
	rotate(rotation_speed * delta)
	
	var jarak_dari_pusat = global_position.distance_to(global_center_position)
	
	if jarak_dari_pusat > max_radius:
		global_position = global_center_position + (global_position - global_center_position).normalized() * max_radius
		direction = (global_center_position - global_position).normalized()
		direction = (direction + Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))).normalized()

	if is_being_mined:
		mine_timer += delta
		if mine_timer >= 1.0:
			mine_timer = 0.0
			take_damage()
			start_burst_flash()
			
		if is_flashing_burst:
			burst_duration_timer += delta
			burst_flash_timer += delta
			
			if burst_flash_timer >= 0.05:
				burst_flash_timer = 0.0
				if sprite and sprite.modulate == Color.WHITE:
					sprite.modulate = Color(1.0, 0.0, 0.0, 0.3) 
					if spark_vfx: spark_vfx.visible = true 
				elif sprite:
					sprite.modulate = Color.WHITE 
					if spark_vfx: spark_vfx.visible = false 
			
			if burst_duration_timer >= 0.3:
				is_flashing_burst = false
				if sprite: sprite.modulate = Color.WHITE 
				if spark_vfx: spark_vfx.visible = true 
	else:
		if sprite and sprite.modulate != Color.WHITE:
			sprite.modulate = Color.WHITE
		mine_timer = 0.0
		is_flashing_burst = false
		if spark_vfx and spark_vfx.emitting:
			spark_vfx.emitting = false
			spark_vfx.visible = false

# 🔥 KUNCI PEMBAIKAN: Fungsi ini diletakkan semula dengan betul supaya baris bawah tidak error
func start_burst_flash() -> void:
	is_flashing_burst = true
	burst_flash_timer = 0.0
	burst_duration_timer = 0.0

func take_damage() -> void:
	hp -= 1
	print("MELOMBONG -> Baki HP Meteorite: ", hp)
	
	if hp <= 0:
		destroy()

func _on_objek_masuk(target: Node2D) -> void:
	if target.name == "Player" or target.is_in_group("Player") or target.name == "SpaceShip":
		if target.has_meta("batu_lombong_aktif"):
			var meteor_lain = target.get_meta("batu_lombong_aktif")
			if is_instance_valid(meteor_lain) and meteor_lain != self:
				return
		
		target.set_meta("batu_lombong_aktif", self)
			
		is_being_mined = true 
		take_damage() 
		start_burst_flash() 
		if spark_vfx:
			spark_vfx.emitting = true
			spark_vfx.visible = true

func _on_objek_keluar(target: Node2D) -> void:
	if target.name == "Player" or target.is_in_group("Player") or target.name == "SpaceShip":
		if target.has_meta("batu_lombong_aktif") and target.get_meta("batu_lombong_aktif") == self:
			target.remove_meta("batu_lombong_aktif")
			
		if is_being_mined:
			is_being_mined = false
			if spark_vfx:
				spark_vfx.emitting = false
				spark_vfx.visible = false

func destroy() -> void:
	print("Sistem Meteor: Meteor hancur! Mencari DropComponent...")
	
	# Mencari DropComponent di dalam nod anak meteorcluster
	var drop_comp = find_child("DropComponent", true, false)
	
	if drop_comp != null and drop_comp.has_method("trigger_drop"):
		drop_comp.trigger_drop()
	else:
		print("Sistem Meteor: AMARAN! Tiada DropComponent diletakkan sebagai anak di Inspector!")

	# Pembersihan metadata keselamatan
	var players = get_tree().get_nodes_in_group("Player")
	for p in players:
		if p.has_meta("batu_lombong_aktif") and p.get_meta("batu_lombong_aktif") == self:
			p.remove_meta("batu_lombong_aktif")
			
	var main_scene = get_tree().current_scene
	if main_scene:
		var spaceship = main_scene.find_child("SpaceShip", true, false)
		if spaceship and spaceship.has_meta("batu_lombong_aktif") and spaceship.get_meta("batu_lombong_aktif") == self:
			spaceship.remove_meta("batu_lombong_aktif")
			
		var player_node = main_scene.find_child("Player", true, false)
		if player_node and player_node.has_meta("batu_lombong_aktif") and player_node.get_meta("batu_lombong_aktif") == self:
			player_node.remove_meta("batu_lombong_aktif")
			
	queue_free()
