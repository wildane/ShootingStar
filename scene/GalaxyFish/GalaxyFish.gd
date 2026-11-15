extends CharacterBody2D

# --- EXPORTED CONFIGURATIONS ---
@export_group("Movement Speeds")
@export var wander_speed: float = 30.0       
@export var flee_speed: float = 120.0        
@export var panic_speed_multiplier: float = 1.8 

@export_group("AI Parameters & Ranges")
@export var detection_radius: float = 150.0   
@export var flee_distance_target: float = 600.0 
@export var wander_change_time: float = 3.0  

@export_group("Boundary Settings")
@export var max_radius: float = 1500.0       
@export var custom_center_node: Node2D      

# --- INTERNAL VARIABLES ---
var global_center_position: Vector2 = Vector2.ZERO
var current_speed: float = 30.0
var move_direction: Vector2 = Vector2.RIGHT
var wander_timer: float = 0.0
var target_player: Node2D = null

var is_fleeing: bool = false
var is_panicking: bool = false
var panic_timer: float = 0.0

var flee_start_position: Vector2 = Vector2.ZERO
var is_braking: bool = false
var braking_timer: float = 0.0
var is_returning_home: bool = false
var is_dying: bool = false 

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_pick_random_direction()
	global_center_position = custom_center_node.global_position if is_instance_valid(custom_center_node) else global_position

func _physics_process(delta: float) -> void:
	if is_dying: return 
	
	target_player = get_tree().get_first_node_in_group("Player")
	
	if target_player == null:
		target_player = get_tree().current_scene.find_child("SpaceShip", true, false)
	if target_player == null:
		target_player = get_tree().current_scene.find_child("Player", true, false)

	var player_nearby: bool = false
	if is_instance_valid(target_player):
		var distance_to_player = global_position.distance_to(target_player.global_position)
		if distance_to_player <= detection_radius:
			player_nearby = true

	var distance_from_spawn = global_position.distance_to(global_center_position)
	
	# --- STATE MACHINE PRIORITY ---
	if player_nearby and not is_fleeing and not is_panicking:
		is_returning_home = false  
		is_fleeing = true
		flee_start_position = global_position
		# TUKAR: Ambil arah rawak (random) semasa mula flee
		_pick_random_direction()

	elif distance_from_spawn > max_radius and not is_returning_home and not player_nearby:
		is_returning_home = true
		is_fleeing = false
		is_braking = false
		is_panicking = false

	# --- EXECUTE STATES ---
	if is_returning_home:
		move_direction = lerp(move_direction, (global_center_position - global_position).normalized(), 5.0 * delta).normalized()
		current_speed = wander_speed
		if distance_from_spawn < 30.0: 
			is_returning_home = false
			_pick_random_direction()
			
	elif is_panicking:
		panic_timer -= delta
		current_speed = flee_speed * panic_speed_multiplier
		if panic_timer <= 0: is_panicking = false
		
	elif is_fleeing:
		current_speed = flee_speed
		if global_position.distance_to(flee_start_position) >= flee_distance_target:
			is_fleeing = false
			is_braking = true
			braking_timer = 1.0 
		# DIKEMAS KINI: Kod lama yang memaksa arah bertentangan pemain dibuang dari sini

	elif is_braking:
		braking_timer -= delta
		current_speed = lerp(wander_speed, flee_speed, clamp(braking_timer, 0.0, 1.0))
		if braking_timer <= 0.0:
			is_braking = false
			_pick_random_direction()
	else:
		current_speed = wander_speed
		wander_timer += delta
		if wander_timer >= wander_change_time: _pick_random_direction()

	# INTEGRASI FIZIK
	velocity = move_direction * current_speed
	if move_and_slide() or is_on_wall():
		_handle_physics_bounce()

	if move_direction != Vector2.ZERO:
		rotation = lerp_angle(rotation, move_direction.angle(), 8.0 * delta)

func _pick_random_direction() -> void:
	wander_timer = 0.0
	move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _handle_physics_bounce() -> void:
	var collision_count = get_slide_collision_count()
	if collision_count > 0:
		# DIKEMAS KINI: Kod tolak HP dibuang sepenuhnya.
		# Semua jenis perlanggaran (termasuk pemain) akan menyebabkan ikan melantun secara fizik.
		move_direction = move_direction.bounce(get_slide_collision(0).get_normal()).normalized()
		is_fleeing = false
		is_panicking = false
		is_braking = false
		wander_timer = 0.0

func trigger_panic_movement() -> void:
	is_panicking = true
	is_fleeing = false
	is_braking = false
	is_returning_home = false
	panic_timer = 1.5
	flee_start_position = global_position
	# TUKAR: Ambil arah rawak (random) semasa ikan panik (terkena damage dari sumber lain)
	_pick_random_direction()
