extends Node

# Kita ambil rujukan kepada tuan rumah
@onready var parent = get_parent()

func get_data() -> Dictionary:
	return {
		"scene_path": parent.scene_file_path, # Ambil path fail .tscn secara automatik
		"pos_x": parent.global_position.x,
		"pos_y": parent.global_position.y
	}
