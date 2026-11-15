extends CharacterBody2D

# --- EXPORTED CONFIGURATIONS ---
@export_group("Movement Speeds")
@export var wander_speed: float = 30.0       
@export var home_speed: float = 60.0          
@export var wander_change_time: float = 4.0  

@export_group("Boundary Settings")
@export var max_radius: float = 1500.0       
@export_group("Boundary Settings")
@export var home_arrival_radius: float = 50.0 

# --- INTERNAL VARIABLES ---
var global_center_position: Vector2 = Vector2.ZERO 
var current_speed: float = 30.0
var move_direction: Vector2 = Vector2.RIGHT
var wander_timer: float = 0.0
var target_player: Node2D = null

var is_inflated: bool = false
var is_returning_home: bool = false
var is_dying: bool = false 

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_comp: Node = $AttackComponent

func _ready() -> void:
	call_deferred("_lock_spawn_position")
	_pick_random_direction()

func _lock_spawn_position() -> void:
	global_center_position = global_position

func _physics_process(delta: float) -> void:
	if is_dying: return 

	# Ambil data visual daripada AttackComponent
	var check_norm_scale: Vector2 = attack_comp.get("normal_scale") if is_instance_valid(attack_comp) and attack_comp.get("normal_scale") != null else Vector2(1.0, 1.0)
	var check_inf_scale: Vector2 = attack_comp.get("inflated_scale") if is_instance_valid(attack_comp) and attack_comp.get("inflated_scale") != null else Vector2(3.0, 3.0)
	var check_puff_color: Color = attack_comp.get("puff_color") if is_instance_valid(attack_comp) and attack_comp.get("puff_color") != null else Color(1.0, 0.4, 0.4)
	
	var check_inf_speed: float = attack_comp.get("inflate_animation_speed") if is_instance_valid(attack_comp) and attack_comp.get("inflate_animation_speed") != null else 15.0
	var check_def_speed: float = attack_comp.get("deflate_animation_speed") if is_instance_valid(attack_comp) and attack_comp.get("deflate_animation_speed") != null else 4.0
	var check_det_radius: float = attack_comp.get("detection_radius") if is_instance_valid(attack_comp) and attack_comp.get("detection_radius") != null else 20.0

	# --- INTERPOLASI VISUAL SPRITE UTAMA ---
	if is_inflated:
		sprite.scale = sprite.scale.lerp(check_inf_scale, check_inf_speed * delta)
		sprite.modulate = sprite.modulate.lerp(check_puff_color, check_inf_speed * delta)
	else:
		sprite.scale = sprite.scale.lerp(check_norm_scale, check_def_speed * delta)
		sprite.modulate = sprite.modulate.lerp(Color.WHITE, check_def_speed * delta)

	var distance_from_spawn = global_position.distance_to(global_center_position)
	
	# --- STATE MACHINE PRIORITY ---
	if distance_from_spawn > max_radius:
		if not is_returning_home:
			is_returning_home = true
			is_inflated = false

	if is_returning_home:
		if distance_from_spawn < home_arrival_radius: 
			is_returning_home = false
			_pick_random_direction()

	# --- EXECUTE STATES ---
	if is_returning_home:
		var target_dir = (global_center_position - global_position).normalized()
		move_direction = lerp(move_direction, target_dir, 5.0 * delta).normalized()
		current_speed = home_speed 
	else:
		current_speed = wander_speed
		wander_timer += delta
		if wander_timer >= wander_change_time: 
			_pick_random_direction()

	# SEMAKAN JARAK MATEMATIK ANTI-LAG
	_semak_jarak_aktif_mutlak(check_det_radius)

	# INTEGRASI FIZIK GERAKAN
	velocity = move_direction * current_speed
	if move_and_slide() or is_on_wall():
		_handle_physics_bounce()

	if move_direction != Vector2.ZERO and not is_inflated:
		rotation = lerp_angle(rotation, move_direction.angle(), 4.0 * delta)

func _pick_random_direction() -> void:
	wander_timer = 0.0
	move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _handle_physics_bounce() -> void:
	var collision_count = get_slide_collision_count()
	if collision_count > 0:
		var collision = get_slide_collision(0)
		move_direction = move_direction.bounce(collision.get_normal()).normalized()
		wander_timer = 0.0

func _semak_jarak_aktif_mutlak(radius: float) -> void:
	var current_player = get_tree().get_first_node_in_group("Player")
	if current_player == null:
		current_player = get_tree().current_scene.find_child("SpaceShip", true, false)
	if current_player == null:
		current_player = get_tree().current_scene.find_child("Player", true, false)
		
	if is_instance_valid(current_player):
		var dist_sq = global_position.distance_squared_to(current_player.global_position)
		if dist_sq <= (radius * radius):
			if is_instance_valid(attack_comp):
				attack_comp.execute_bite_attack(current_player)
