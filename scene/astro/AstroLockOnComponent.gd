extends Node
class_name LockOnComponent

var astro: CharacterBody2D = null
var target_mob: Node2D = null
var is_locked: bool = false

# ==========================================================
# EXPORTS (BOLEH LARAS DI INSPECTOR KOMPONEN)
# ==========================================================
@export_group("Tetapan Jarak")
@export var max_lock_distance: float = 450.0  # Jarak maksimum sebelum auto-unlock
@export var touch_sensitivity: float = 60.0    # Jejari sensitiviti sentuhan jari pada musuh

func setup(p_astro: CharacterBody2D) -> void:
	astro = p_astro

# Mengesan sentuhan jari dan mengira musuh terdekat dengan jari
func periksa_sentuhan(touch_position: Vector2) -> void:
	if not astro: return
	
	var world_touch_pos = astro.get_viewport().get_canvas_transform().affine_inverse() * touch_position
	
	# Imbasan Fizik
	var space_state = astro.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_touch_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	var closest_enemy: Node2D = null
	var shortest_distance: float = INF
	
	for result in results:
		var collider = result.collider
		if collider and collider is Node2D and collider.is_in_group("enemy"):
			var dist = collider.global_position.distance_to(world_touch_pos)
			if dist < shortest_distance:
				shortest_distance = dist
				closest_enemy = collider
				
	# Logik Tukar Sasaran & Buka Lock Manual
	if closest_enemy:
		# Semak jika jarak sentuhan jari tidak terlalu jauh dari titik tengah musuh
		if shortest_distance <= touch_sensitivity:
			if is_locked and target_mob == closest_enemy:
				buka_lock()
			else:
				kunci_target(closest_enemy)

func kunci_target(mob: Node2D) -> void:
	if target_mob and is_instance_valid(target_mob):
		target_mob.modulate = Color(1, 1, 1)
	
	is_locked = true
	target_mob = mob
	target_mob.modulate = Color(1, 0, 0) # Merah tanda terkunci
	print("Component -> Sasaran dikunci: ", mob.name)

func buka_lock() -> void:
	is_locked = false
	if target_mob and is_instance_valid(target_mob):
		target_mob.modulate = Color(1, 1, 1)
	target_mob = null
	print("Component -> Lock dibatalkan")

# Dipanggil oleh physics_process dalam State
func dapatkan_sudut_pandangan(joystick_dir: Vector2) -> Dictionary:
	var hasil = {"has_target": false, "angle": 0.0}
	if not astro: return hasil
	
	if is_locked and not is_instance_valid(target_mob):
		is_locked = false
		target_mob = null

	if is_locked and target_mob and is_instance_valid(target_mob):
		var jarak_ke_musuh = astro.global_position.distance_to(target_mob.global_position)
		if jarak_ke_musuh > max_lock_distance:
			buka_lock() # Terlalu jauh, auto lepas lock!
		elif not periksa_adakah_dalam_skrin(target_mob):
			buka_lock() # Keluar skrin, auto lepas lock!

	# Mengembalikan sudut berdasarkan status lock-on atau input joystick terkini
	if is_locked and target_mob and is_instance_valid(target_mob):
		var dir_to_mob = target_mob.global_position - astro.global_position
		hasil.angle = dir_to_mob.angle()
		hasil.has_target = true
	elif joystick_dir.length() > 0.01:
		hasil.angle = joystick_dir.angle()
		hasil.has_target = true
		
	return hasil

func periksa_adakah_dalam_skrin(objek: Node2D) -> bool:
	if not objek or not is_instance_valid(objek): return false
	var viewport_rect = astro.get_viewport().get_visible_rect()
	var screen_pos = objek.get_global_transform_with_canvas().origin
	var buffer: float = 20.0
	var skrin_berpadding = Rect2(
		viewport_rect.position.x - buffer,
		viewport_rect.position.y - buffer,
		viewport_rect.size.x + (buffer * 2),
		viewport_rect.size.y + (buffer * 2)
	)
	return skrin_berpadding.has_point(screen_pos)
