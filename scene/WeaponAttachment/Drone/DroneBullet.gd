extends Area2D

@export var speed: float = 600.0  
@export var damage: float = 10.0  

# Jarak maksimum (ikut detection_range drone). Peluru hilang bila sampai,
# kena atau tak kena sasaran.
@export var max_range: float = 150.0

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
		var sumber_hp: Node = actual_enemy
		if actual_enemy.has_node("HealthComponent"):
			var hc = actual_enemy.get_node("HealthComponent")
			hc.take_damage(damage)
			sumber_hp = hc
		elif actual_enemy.has_method("take_damage"):
			actual_enemy.take_damage(damage)

		# Nombor damage terapung + paparan HP (cth: 3/4) di atas musuh
		DamageNumber.tunjuk(actual_enemy, actual_enemy.global_position, damage)

		var hp_sekarang: int = -1
		var hp_maks: int = -1
		if "hp" in sumber_hp and "max_hp" in sumber_hp:
			hp_sekarang = int(sumber_hp.hp)
			hp_maks = int(sumber_hp.max_hp)
		elif "hp" in actual_enemy and "max_hp" in actual_enemy:
			hp_sekarang = int(actual_enemy.hp)
			hp_maks = int(actual_enemy.max_hp)
		if hp_maks > 0:
			DamageNumber.tunjuk_hp(actual_enemy, hp_sekarang, hp_maks)
			
		print("Peluru tepat mengenai musuh: ", actual_enemy.name)
		queue_free()
