extends Area2D

@export var speed: float = 600.0  
@export var damage: float = 10.0  

# Jarak maksimum (ikut detection_range drone). Peluru hilang bila sampai,
# kena atau tak kena sasaran.
@export var max_range: float = 300.0

var is_direction_set: bool = false
var movement_direction: Vector2 = Vector2.RIGHT
var titik_mula: Vector2 = Vector2.ZERO

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_body_entered)
	top_level = true
	
	var visual = get_node_or_null("Sprite2D")
	if visual: visual.position = Vector2.ZERO
		
	var collision = get_node_or_null("CollisionShape2D")
	if collision: collision.position = Vector2.ZERO
	
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _physics_process(delta):
	if not is_direction_set:
		movement_direction = Vector2.RIGHT.rotated(global_rotation)
		# Simpan titik mula pada frame pertama (posisi sudah ditetapkan oleh drone)
		titik_mula = global_position
		is_direction_set = true

	global_position += movement_direction * speed * delta

	# Sampai had jarak drone: hilang, tak kira kena atau tidak
	if global_position.distance_to(titik_mula) >= max_range:
		queue_free()

func _on_body_entered(object):
	var actual_enemy = object
	if object is Area2D and object.get_parent():
		actual_enemy = object.get_parent()
		
	if actual_enemy.is_in_group("enemy"):
		# Mencarikan komponen nyawa yang telah diasingkan
		if actual_enemy.has_node("HealthComponent"):
			actual_enemy.get_node("HealthComponent").take_damage(damage)
		elif actual_enemy.has_method("take_damage"):
			actual_enemy.take_damage(damage)
			
		print("Peluru tepat mengenai musuh: ", actual_enemy.name)
		queue_free()
