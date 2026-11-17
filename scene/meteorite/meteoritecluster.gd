# ==========================================================
# FAIL: meteoritecluster.gd (Versi Penuh Bersatu - Bebas Ralat)
# ==========================================================
extends Area2D

const Bunyi = preload("res://audio/sfx.gd")  # kesan bunyi

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

# Retak yang muncul sikit-sikit bila HP berkurang
var hp_maks: int = 5
var _keretakan: Array[Sprite2D] = []

# Gegaran sikit masa sedang dilombong (dan sentakan kecil setiap ketukan)
var _gegar_kuat: float = 0.0
const GEGAR_LOMBONG: float = 0.35
const GEGAR_KETUKAN: float = 1.6
const GEGAR_REDUP: float = 4.0

# Kilat pendek setiap kali meteor dipukul (bukan strobo berulang)
var _kilat_timer: float = 0.0
const MASA_KILAT: float = 0.09
const WARNA_KILAT: Color = Color(1.8, 1.8, 1.8)

@onready var sprite: Sprite2D = $Sprite2D 
@onready var spark_vfx: CPUParticles2D = $SparkVFX 

func _ready() -> void:
	direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	rotation_speed = randf_range(-0.1, 0.1)
	
	hp_maks = hp
	_keretakan.clear()
	for nama in ["Crack1", "Crack2", "Crack3", "Crack4"]:
		var retak := get_node_or_null(nama) as Sprite2D
		if retak:
			retak.visible = false
			_keretakan.append(retak)
	
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
		_gegar_kuat = maxf(_gegar_kuat, GEGAR_LOMBONG)
		mine_timer += delta
		if mine_timer >= 1.0:
			mine_timer = 0.0
			take_damage()
	else:
		mine_timer = 0.0

	# Gegaran: offset rawak yang mengecil semula ke kedudukan asal
	_gegar_kuat = maxf(0.0, _gegar_kuat - delta * GEGAR_REDUP)
	_set_gegar(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _gegar_kuat)

	# Padam kilat selepas seketika
	if _kilat_timer > 0.0:
		_kilat_timer = max(0.0, _kilat_timer - delta)
		if _kilat_timer == 0.0:
			if sprite:
				sprite.modulate = Color.WHITE
			if spark_vfx and not is_being_mined:
				spark_vfx.emitting = false
				spark_vfx.visible = false

# Alih sprite meteor dan lapisan retak serentak supaya nampak bergegar.
func _set_gegar(ofset: Vector2) -> void:
	if sprite:
		sprite.position = ofset
	for retak in _keretakan:
		retak.position = ofset

# Retak ditambah satu lapis setiap kali HP berkurang.
func _kemas_kini_keretakan() -> void:
	var hilang := clampi(hp_maks - hp, 0, _keretakan.size())
	for i in _keretakan.size():
		_keretakan[i].visible = i < hilang

func _kilat() -> void:
	if sprite:
		sprite.modulate = WARNA_KILAT
	_kilat_timer = MASA_KILAT
	if spark_vfx:
		spark_vfx.emitting = true
		spark_vfx.visible = true

func take_damage() -> void:
	hp -= 1
	print("MELOMBONG -> Baki HP Meteorite: ", hp)
	
	_kemas_kini_keretakan()
	_kilat()
	_gegar_kuat = maxf(_gegar_kuat, GEGAR_KETUKAN)
	Bunyi.mainkan(self, "lombong", -6.0)
	
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
	
	# Peledakan serpihan sebelum hilang
	_serpihan_letup()
	
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

# Pecahan kecil terbang keluar bila batu hancur.
func _serpihan_letup() -> void:
	var ibu = get_parent()
	if ibu == null:
		return
	var bunga = CPUParticles2D.new()
	bunga.position = position
	bunga.amount = 12
	bunga.lifetime = 0.45
	bunga.one_shot = true
	bunga.explosiveness = 1.0
	bunga.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	bunga.emission_sphere_radius = 12.0
	bunga.direction = Vector2(0, -1)
	bunga.spread = 180.0
	bunga.gravity = Vector2.ZERO
	bunga.initial_velocity_min = 40.0
	bunga.initial_velocity_max = 90.0
	bunga.scale_amount_min = 0.4
	bunga.scale_amount_max = 1.0
	bunga.color = Color(0.42, 0.46, 0.55)
	ibu.add_child(bunga)
	bunga.emitting = true
	bunga.finished.connect(bunga.queue_free)
