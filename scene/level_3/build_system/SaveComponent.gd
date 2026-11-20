extends Node

# Kita ambil rujukan kepada tuan rumah
@onready var parent = get_parent()

func get_data() -> Dictionary:
	var data := {
		"scene_path": parent.scene_file_path, # Ambil path fail .tscn secara automatik
		"pos_x": parent.global_position.x,
		"pos_y": parent.global_position.y
	}
	# Objek yang ada HP/tenaga (contoh: robot pekerja) turut disimpan.
	if "hp" in parent:
		data["hp"] = parent.hp
	if "tenaga" in parent:
		data["tenaga"] = parent.tenaga
	return data
