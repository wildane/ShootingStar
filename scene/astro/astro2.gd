extends CharacterBody2D

@onready var camera: Camera2D = $Camera2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var target_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_sediakan_komponen_tenaga()
	await get_tree().process_frame
	target_pos = global_position
	
	# Aktifkan kamera tempatan secara terus untuk ujian
	if camera:
		camera.make_current()
		camera.enabled = true

## Tenaga pemain: dipakai untuk bergerak di angkasa dan untuk tembakan drone.
func _sediakan_komponen_tenaga() -> void:
	if get_node_or_null("EnergyComponent") != null:
		return
	var tenaga := Node.new()
	tenaga.name = "EnergyComponent"
	tenaga.set_script(load("res://scene/astro/EnergyComponent.gd"))
	add_child(tenaga)
