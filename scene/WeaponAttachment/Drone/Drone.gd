extends Node2D

@export var rotation_speed: float = 3.0    # Kelajuan dron pusing keliling player
@export var orbit_radius: float = 20.0     # Jarak rapat dron dengan Player
@export var detection_range: float = 250.0  # Julat jarak untuk serang musuh
@export var bullet_scene: PackedScene      # Fail Bullet.tscn di Inspector

# === 🔥 EXPORT COOLDOWN TIMER (Boleh ubah terus dari Inspector) ===
@export_group("Weapon Settings")
@export var shoot_cooldown: float = 2.0    # Set 2.0 untuk 2 saat, 0.5 untuk setengah saat
@export var kos_tenaga_tembakan: float = 6.0  # tenaga player dipakai setiap tembakan

# === LAYER CONFIGURATION ===
@export_group("Collision Layers Setup")
@export_flags_2d_physics var layers_that_block: int = 2  
@export_flags_2d_physics var layers_for_enemies: int = 1 

var target_player: CharacterBody2D = null
var current_enemy: Node2D = null
var angle: float = 0.0

# Pembolehubah dalaman untuk mengira masa bertenang
var cooldown_timer: float = 0.0

@onready var sprite = $Sprite2D 

func _ready():
	target_player = get_tree().get_first_node_in_group("Player")

func _physics_process(delta):
	if not is_instance_valid(target_player):
		var p_nodes = get_tree().get_nodes_in_group("Player")
		if not p_nodes.is_empty():
			target_player = p_nodes[0]
		return

	# Jika player mati, drone hilang dan berhenti berfungsi sehingga respawn
	if target_player.has_node("HealthComponent"):
		var hc = target_player.get_node("HealthComponent")
		if hc.get("is_dead"):
			visible = false
			return
	visible = true
		
	# 1. SET KEDUDUKAN ORBIT (Mengelilingi Player)
	angle += rotation_speed * delta
	var offset = Vector2(cos(angle), sin(angle)) * orbit_radius
	global_position = target_player.global_position + offset

	# 2. URUS KIRAAN MASA COOLDOWN (Tolak masa setiap frame secara mutlak)
	if cooldown_timer > 0:
		cooldown_timer -= delta

	# 3. CARI MUSUH TERDEKAT
	_find_closest_enemy()

	# 4. KUNCI SASARAN & TEMBAK AUTOMATIK (Sekatan Cooldown Ketat)
	if is_instance_valid(current_enemy):
		look_at(current_enemy.global_position)
		
		# Dron HANYA boleh menembak jika masa menunggu sudah tamat (habis kira)
		if cooldown_timer <= 0:
			shoot_bullet()
			cooldown_timer = shoot_cooldown # Reset semula masa menunggu mengikut nilai Inspector
	else:
		rotation = angle

func _find_closest_enemy():
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	var closest_enemy: Node2D = null
	var shortest_distance: float = detection_range

	for enemy in all_enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dying"):
			var distance = target_player.global_position.distance_to(enemy.global_position)
			if distance < shortest_distance:
				# Semak laluan lurus bebas dinding dari pusat Player
				if _is_line_of_sight_clear(enemy):
					shortest_distance = distance
					closest_enemy = enemy

	current_enemy = closest_enemy

func _is_line_of_sight_clear(enemy: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var start_pos = target_player.global_position
	var query = PhysicsRayQueryParameters2D.create(start_pos, enemy.global_position)
	
	var exclude_list: Array[RID] = []
	if is_instance_valid(target_player):
		exclude_list.append(target_player.get_rid())
		
	if enemy.has_node("DetectionArea"):
		var enemy_area = enemy.get_node("DetectionArea")
		if enemy_area is Area2D:
			exclude_list.append(enemy_area.get_rid())
			
	query.exclude = exclude_list
	query.collision_mask = layers_that_block | layers_for_enemies
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider == enemy or (collider.get_parent() && collider.get_parent() == enemy):
			return true
		else:
			return false # Terhalang dinding
			
	return true

func shoot_bullet():
	if bullet_scene:
		# Tembakan memakai tenaga player
		if is_instance_valid(target_player):
			var tenaga = target_player.get_node_or_null("EnergyComponent")
			if tenaga and not tenaga.guna_tembakan(kos_tenaga_tembakan):
				return

		var bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position
		bullet.global_rotation = global_rotation
		# Peluru ikut julat drone ini: hilang bila sampai detection_range
		if "max_range" in bullet:
			bullet.max_range = detection_range
		_shake_drone_sprite()

func _shake_drone_sprite():
	if sprite:
		var shake_tween = create_tween()
		var shake_strength: float = 4.0 
		var rand_pos1 = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		var rand_pos2 = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		
		shake_tween.tween_property(sprite, "position", rand_pos1, 0.03)
		shake_tween.tween_property(sprite, "position", rand_pos2, 0.03)
		shake_tween.tween_property(sprite, "position", Vector2.ZERO, 0.03)
