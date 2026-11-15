extends Area2D

@export_group("Spawner Settings")
@export var mob_scene: PackedScene 
@export var spawn_radius: float = 300.0:
	set(value):
		spawn_radius = value
		recalculate_min_max()
		update_editor_collision()
		queue_redraw()

# Boleh laras masa respawn (dalam saat) terus dari Inspector untuk setiap spawner
@export var respawn_time: float = 300.0 

@export_group("Laras Pembahagi (Formula)")
@export_range(1.0, 500.0, 0.5) var min_divider: float = 60.0:
	set(value):
		min_divider = value
		recalculate_min_max()

@export_range(1.0, 500.0, 0.5) var max_divider: float = 25.0:
	set(value):
		max_divider = value
		recalculate_min_max()

@export_group("Anggaran Bilangan Mob (Auto)")
@export var min_mobs: int = 1
@export var max_mobs: int = 3

@export var spawner_id: String = "spawner_1" 

var target_count: int = 0
var is_loaded_from_save: bool = false 

@onready var container: Node = $Container

func _ready() -> void:
	recalculate_min_max()
	update_editor_collision()
	
	if Engine.is_editor_hint():
		return
		
	if spawner_id == "" or spawner_id == "spawner_1":
		spawner_id = name
		
	await get_tree().process_frame
	
	if not is_loaded_from_save:
		target_count = randi_range(min_mobs, max_mobs)
		for i in range(target_count):
			spawn_mob()

func recalculate_min_max() -> void:
	var safe_min_div = max(1.0, min_divider)
	var safe_max_div = max(1.0, max_divider)
	
	min_mobs = clampi(int(spawn_radius / safe_min_div), 1, 100)
	max_mobs = clampi(int(spawn_radius / safe_max_div), 3, 300)
	
	notify_property_list_changed()

func update_editor_collision() -> void:
	for child in get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			child.shape = child.shape.duplicate()
			child.shape.radius = spawn_radius

func _draw() -> void:
	if Engine.is_editor_hint():
		var warna_isi = Color(0.2, 0.6, 1.0, 0.15)
		draw_circle(Vector2.ZERO, spawn_radius, warna_isi)
		
		var warna_garisan = Color(0.2, 0.6, 1.0, 0.4)
		draw_arc(Vector2.ZERO, spawn_radius, 0, TAU, 64, warna_garisan, 2.0)

func spawn_mob() -> void:
	if not mob_scene: return
	
	var mob = mob_scene.instantiate()
	var random_angle = randf() * TAU
	var random_distance = randf() * spawn_radius
	var spawn_pos = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	
	container.add_child(mob)
	mob.global_position = global_position + spawn_pos
	
	# 🔥 KUNCI PEMBAIKAN 1: Menggunakan tree_exiting untuk mengesan detik awal kematian mob
	if not mob.tree_exiting.is_connected(_on_mob_destroyed):
		mob.tree_exiting.connect(_on_mob_destroyed)

func _on_mob_destroyed() -> void:
	if Engine.is_editor_hint(): return
	
	# 🔥 KUNCI PEMBAIKAN 2: Tolak 1 secara manual merta agar hitungan RAM tepat semasa auto-save bertembung
	var current_count = max(0, container.get_child_count() - 1)
	
	# =========================================================================
	# 🔥 KUNCI AUTO-SAVE: Tunggu 1 frame (kalis lag) baru tulis fail JSON
	# =========================================================================
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("save_game"):
		save_manager.save_game()
		print("Mob Spawner: Mob mati -> Auto-save file JSON berjaya dicetuskan!")

	# KEKAL LOGIK RESPOND KOD ASAL ANDA: Menjalankan pemasa respawn offline/online
	if current_count > 0:
		await get_tree().create_timer(respawn_time).timeout
		if is_inside_tree() and container.get_child_count() < target_count:
			spawn_mob()
	else:
		target_count = randi_range(min_mobs, max_mobs)
		for i in range(target_count):
			await get_tree().create_timer(respawn_time).timeout
			if is_inside_tree() and container.get_child_count() < target_count:
				spawn_mob()

# --- SAVE/LOAD + KIRAAN MASA OFFLINE MOB ---

func dapatkan_data_save() -> Dictionary:
	var positions: Array = []
	for mob in container.get_children():
		# 🔥 KUNCI PEMBAIKAN 3: Menapis keluar mob yang sedang mati/dipadam daripada fail JSON
		if is_instance_valid(mob) and not mob.is_queued_for_deletion() and mob.is_inside_tree():
			positions.append({"x": mob.global_position.x, "y": mob.global_position.y})
	
	return {
		"target_count": target_count,
		"mob_positions": positions,
		"waktu_simpanan": Time.get_unix_time_from_system()
	}

func muat_data_save(data: Dictionary) -> void:
	is_loaded_from_save = true
	
	# Bersihkan mob lama yang sedia ada dalam container
	for child in container.get_children():
		child.queue_free()
		
	var positions = data.get("mob_positions", [])
	
	# =========================================================================
	# 🔥 LOGIK PEMOTONGAN MOB BERLEBIHAN (TERKINI)
	# =========================================================================
	# Jika jumlah posisi yang di-load melebihi max_mobs semasa, potong posisi lebihan itu
	if positions.size() > max_mobs:
		print("Spawner [", spawner_id, "]: Mob tersimpan (", positions.size(), ") melebihi had max (", max_mobs, "). Memotong mob lebihan...")
		positions = positions.slice(0, max_mobs) # Ambil setakat had max sahaja
		
	# Laras juga target_count supaya tidak melebihi had max_mobs yang baru
	target_count = clampi(int(data.get("target_count", 0)), min_mobs, max_mobs)
	
	var jumlah_hidup = positions.size()
	
	# Spawn mob berdasarkan senarai posisi yang telah ditapis
	for pos_dict in positions:
		var global_pos = Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0))
		if not mob_scene: continue
		var mob = mob_scene.instantiate()
		container.add_child(mob)
		mob.global_position = global_pos
		
		# 🔥 KUNCI PEMBAIKAN 4: Samakan tetapan isyarat semasa muat semula data simpanan
		if not mob.tree_exiting.is_connected(_on_mob_destroyed):
			mob.tree_exiting.connect(_on_mob_destroyed)
		
	# KIRAAN MASA OFFLINE UNTUK MOB
	if data.has("waktu_simpanan") and jumlah_hidup < target_count:
		var waktu_sekarang = Time.get_unix_time_from_system()
		var waktu_lepas = data.get("waktu_simpanan", waktu_sekarang)
		var beza_masa_saat = waktu_sekarang - waktu_lepas
		
		var kuota_respawn = int(beza_masa_saat / max(1.0, respawn_time))
		
		while container.get_child_count() < target_count and kuota_respawn > 0:
			spawn_mob()
			kuota_respawn -= 1
