extends CharacterBody2D

@onready var camera: Camera2D = $Camera2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var target_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	await get_tree().process_frame
	target_pos = global_position
	
	# Aktifkan kamera tempatan secara terus untuk ujian
	if camera:
		camera.make_current()
		camera.enabled = true
