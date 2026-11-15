extends CharacterBody2D

# --- EXPORTED CONFIGURATIONS ---
@export_group("Movement Speeds")
@export var wander_speed: float = 40.0       
@export var chase_speed: float = 160.0        # Kelajuan piranha mengejar player
@export var home_speed: float = 80.0          # Kelajuan khas semasa pulang ke sarang
@export var frenzy_speed_multiplier: float = 1.5 

@export_group("AI Parameters & Ranges")
@export var detection_radius: float = 400.0   # Jarak piranha mula nampak & mula kejar player
@export var bite_radius: float = 50.0        # Piranha akan berhenti jika jarak kurang dari nilai ini
@export var wander_change_time: float = 3.0  

@export_group("Boundary Settings")
@export var max_radius: float = 2000.0       
@export var home_arrival_radius: float = 50.0 # Jarak sensitiviti piranha mengesan sarang
@export var custom_center_node: Node2D      

@export_group("Visual FX")
@export var chase_color: Color = Color(1.0, 0.5, 0.0) # Warna Jingga/Orange (Kekal solid)

# --- INTERNAL VARIABLES ---
var global_center_position: Vector2 = Vector2.ZERO 
var current_speed: float = 40.0
var move_direction: Vector2 = Vector2.RIGHT
var wander_timer: float = 0.0
var target_player: Node2D = null

var is_chasing: bool = false
var is_frenzy: bool = false
var frenzy_timer: float = 0.0

var is_returning_home: bool = false
var is_dying: bool = false 
var is_attacking_dash: bool = false           # Diperlukan oleh AttackComponent untuk menyekat fizik

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	call_deferred("_lock_spawn_position")
	_pick_random_direction()

func _lock_spawn_position() -> void:
	global_center_position = global_position

func _physics_process(delta: float) -> void:
	if is_dying: return 

	# Cari rujukan player di dalam group atau scene root
	target_player = get_tree().get_first_node_in_group("Player")
	if target_player == null:
		target_player = get_tree().current_scene.find_child("SpaceShip", true, false)
	if target_player == null:
		target_player = get_tree().current_scene.find_child("Player", true, false)

	# Kira jarak antara piranha dan player
	var player_in_detection_range: bool = false
	var distance_to_player: float = 999999.0
	
	if is_instance_valid(target_player):
		distance_to_player = global_position.distance_to(target_player.global_position)
		if distance_to_player <= detection_radius:
			player_in_detection_range = true

	var distance_from_spawn = global_position.distance_to(global_center_position)
	
	# --- STATE MACHINE PRIORITY ---
	
	# 1. Jika terkeluar dari max_radius, paksa balik sarang serta-merta
	if distance_from_spawn > max_radius:
		if not is_returning_home:
			is_returning_home = true
			is_chasing = false
			is_frenzy = false
			is_attacking_dash = false 
			set_collision_mask_value(1, true)
			sprite.modulate = Color.WHITE

	# 2. Jika sedang balik sarang, kunci state ini sehingga masuk ke dalam home_arrival_radius
	if is_returning_home:
		if distance_from_spawn < home_arrival_radius: 
			is_returning_home = false
			_pick_random_direction()

	# 3. Logik Mula Mengejar
	elif player_in_detection_range and not is_frenzy:
		if not is_chasing:
			is_chasing = true
			set_collision_mask_value(1, false)

	# --- 🌟 LOGIK PERTUKARAN WARNA JINGGA SEMASA CHASE / FRENZY 🌟 ---
	if is_chasing or is_frenzy:
		if sprite.modulate != chase_color:
			sprite.modulate = chase_color
	else:
		if sprite.modulate != Color.WHITE:
			sprite.modulate = Color.WHITE

	# --- EXECUTE STATES ---
	var force_stop: bool = false 
	
	# Sekat pergerakan mesin fizik sekiranya AttackComponent sedang mengawal posisi dash piranha
	if is_attacking_dash:
		return

	if is_frenzy:
		frenzy_timer -= delta
		current_speed = chase_speed * frenzy_speed_multiplier
		if is_instance_valid(target_player):
			var dir_to_player = (target_player.global_position - global_position).normalized()
			move_direction = lerp(move_direction, dir_to_player, 8.0 * delta).normalized()
			
			if distance_to_player <= bite_radius:
				_call_attack_component()
				
		if frenzy_timer <= 0: 
			is_frenzy = false
			if not is_instance_valid(target_player):
				set_collision_mask_value(1, true)
		
	elif is_chasing:
		if is_instance_valid(target_player):
			var dir_to_player = (target_player.global_position - global_position).normalized()
			
			if distance_to_player <= bite_radius:
				current_speed = 0.0
				move_direction = dir_to_player
				force_stop = true
				_call_attack_component()
			else:
				current_speed = chase_speed
				move_direction = lerp(move_direction, dir_to_player, 7.0 * delta).normalized()
		else:
			is_chasing = false
			set_collision_mask_value(1, true)
			_pick_random_direction()

	elif is_returning_home:
		var target_dir = (global_center_position - global_position).normalized()
		move_direction = lerp(move_direction, target_dir, 5.0 * delta).normalized()
		current_speed = home_speed 
			
	else:
		current_speed = wander_speed
		wander_timer += delta
		if wander_timer >= wander_change_time: 
			_pick_random_direction()

	# INTEGRASI FIZIK
	if force_stop:
		velocity = Vector2.ZERO 
	else:
		velocity = move_direction * current_speed
		if move_and_slide() or is_on_wall():
			_handle_physics_bounce()

	# Kemaskini sudut putaran sprite
	if move_direction != Vector2.ZERO and not force_stop:
		rotation = lerp_angle(rotation, move_direction.angle(), 8.0 * delta)

func _pick_random_direction() -> void:
	wander_timer = 0.0
	move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _handle_physics_bounce() -> void:
	var collision_count = get_slide_collision_count()
	if collision_count > 0:
		var collision = get_slide_collision(0)
		move_direction = move_direction.bounce(collision.get_normal()).normalized()
		wander_timer = 0.0

# Fungsi bantuan baharu untuk memanggil komponen serangan yang telah diasingkan
func _call_attack_component() -> void:
	if has_node("AttackComponent"):
		get_node("AttackComponent").execute_bite_attack(target_player)

func trigger_frenzy_movement() -> void:
	is_frenzy = true
	is_chasing = false
	is_returning_home = false
	frenzy_timer = 2.0
	set_collision_mask_value(1, false)
	_pick_random_direction()
