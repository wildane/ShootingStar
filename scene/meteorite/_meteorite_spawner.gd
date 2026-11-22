@tool
extends Area2D

@export_group("Spawner Settings")
@export var meteorite_scene: PackedScene
@export var spawn_radius: float = 300.0:
	set(value):
		spawn_radius = value
		recalculate_min_max()
		update_editor_collision()
		queue_redraw()

# Boleh laras masa respawn meteorit (dalam saat) terus dari Inspector
@export var respawn_time: float = 45.0 

# Kekalkan ID asal anda mengikut fail save JSON sedia ada
@export var spawner_id: String = "" 

var min_meteorites: int = 1
var max_meteorites: int = 3
var target_count: int = 0
var is_loaded_from_save: bool = false 

@onready var container: Node = $Container
@onready var respawn_timer: Timer = $Timer

func _ready() -> void:
	recalculate_min_max()
	update_editor_collision()
	
	if Engine.is_editor_hint():
		return
		
	if spawner_id == "" or spawner_id == "spawner_1":
		spawner_id = name
		
	# Tetapkan masa pemasa mengikut nilai pemboleh ubah export terbaharu
	respawn_timer.wait_time = respawn_time
	respawn_timer.one_shot = true
	if not respawn_timer.timeout.is_connected(_on_timer_timeout):
		respawn_timer.timeout.connect(_on_timer_timeout)
	
	await get_tree().process_frame
	
	if not is_loaded_from_save:
		target_count = randi_range(min_meteorites, max_meteorites)
		for i in range(target_count):
			spawn_meteorite_at_random()

func recalculate_min_max() -> void:
	min_meteorites = clampi(int(spawn_radius / 60.0), 1, 100)
	max_meteorites = clampi(int(spawn_radius / 25.0), 3, 300)

func update_editor_collision() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			if child.shape is CircleShape2D:
				child.shape = child.shape.duplicate()
				child.shape.radius = spawn_radius

func _draw() -> void:
	if Engine.is_editor_hint():
		var warna_isi = Color(0.2, 0.6, 1.0, 0.15)
		draw_circle(Vector2.ZERO, spawn_radius, warna_isi)
		var warna_garisan = Color(0.2, 0.6, 1.0, 0.4)
		draw_arc(Vector2.ZERO, spawn_radius, 0, TAU, 64, warna_garisan, 2.0)

func spawn_meteorite_at_random() -> void:
	if not meteorite_scene: return
	var random_angle = randf() * TAU
	var random_distance = randf() * spawn_radius
	var spawn_pos = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	spawn_meteorite_at_position(global_position + spawn_pos)

func spawn_meteorite_at_position(global_pos: Vector2) -> void:
	if not meteorite_scene: return
	var meteorite = meteorite_scene.instantiate()
	container.add_child(meteorite)
	meteorite.global_position = global_pos
	meteorite.global_center_position = global_position
	meteorite.max_radius = spawn_radius
	
	# Menggunakan tree_exiting supaya spawner mengesan kematian meteor dengan merta
	if not meteorite.tree_exiting.is_connected(_on_meteorite_destroyed):
		meteorite.tree_exiting.connect(_on_meteorite_destroyed)

func _on_meteorite_destroyed() -> void:
	if Engine.is_editor_hint(): return
	
	# Tolak 1 secara manual merta supaya hitungan tepat semasa auto-save bertembung
	var current_count = max(0, container.get_child_count() - 1)
	
	if current_count == 0:
		recalculate_min_max()
		target_count = randi_range(min_meteorites, max_meteorites)
	
	# Memastikan timer dikemas kini mengikut masa export terbaharu semasa start
	if current_count < target_count and respawn_timer.is_stopped():
		respawn_timer.start(respawn_time)

func _on_timer_timeout() -> void:
	if Engine.is_editor_hint(): return
	var current_count = container.get_child_count()
	
	if current_count < target_count:
		spawn_meteorite_at_random()
		
	if container.get_child_count() < target_count:
		respawn_timer.start(respawn_time)

# --- SAVE/LOAD + KIRAAN MASA OFFLINE METEORITE ---

func dapatkan_data_save() -> Dictionary:
	var positions: Array = []
	for meteorite in container.get_children():
		# Tapis keluar meteor yang sedang mati/dipadam daripada fail JSON
		if is_instance_valid(meteorite) and not meteorite.is_queued_for_deletion() and meteorite.is_inside_tree():
			positions.append({"x": meteorite.global_position.x, "y": meteorite.global_position.y})
	
	return {
		"target_count": target_count,
		"mob_positions": positions,
		"waktu_simpanan": Time.get_unix_time_from_system()
	}

func muat_data_save(data: Dictionary) -> void:
	is_loaded_from_save = true
	target_count = int(data.get("target_count", 0))
	
	for child in container.get_children():
		child.queue_free()
		
	var positions = data.get("mob_positions", [])
	var jumlah_hidup = positions.size()
	
	for pos_dict in positions:
		var global_pos = Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0))
		spawn_meteorite_at_position(global_pos)
		
	if data.has("waktu_simpanan") and jumlah_hidup < target_count:
		var waktu_sekarang = Time.get_unix_time_from_system()
		var waktu_lepas = data.get("waktu_simpanan", waktu_sekarang)
		var beza_masa_saat = waktu_sekarang - waktu_lepas
		
		# Membahagi mengikut nilai dinamik respawn_time dari Inspector
		var kuota_respawn = int(beza_masa_saat / max(1.0, respawn_time))
		
		while container.get_child_count() < target_count and kuota_respawn > 0:
			spawn_meteorite_at_random()
			kuota_respawn -= 1
			
	if container.get_child_count() < target_count:
		respawn_timer.start(respawn_time)
