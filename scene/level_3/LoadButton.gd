extends Button

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	var world = get_tree().current_scene
	if world.has_method("load_world"):
		world.load_world()
