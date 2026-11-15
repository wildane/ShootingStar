extends Button

func _ready():
	# Connect signal terus dalam skrip ni
	pressed.connect(_on_pressed)

func _on_pressed():
	# Kita cari 'World' yang jadi parent kepada semua furniture
	# Gunakan get_tree().root atau get_parent() ikut struktur scene kau
	var world = get_tree().current_scene
	if world.has_method("save_world"):
		world.save_world()
