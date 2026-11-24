extends Node

# Kita ambil rujukan kepada tuan rumah
@onready var parent = get_parent()

func get_data() -> Dictionary:
	var data := {
		"scene_path": parent.scene_file_path, # Ambil path fail .tscn secara automatik
		"pos_x": parent.global_position.x,
		"pos_y": parent.global_position.y
	}
	# Objek yang ada HP/tenaga turut disimpan.
	if "hp" in parent:
		data["hp"] = parent.hp
	if "tenaga" in parent:
		data["tenaga"] = parent.tenaga
	# State tambahan khusus perabot (contoh: batch smelter yang belum siap).
	if parent.has_method("get_data_simpanan_tambahan"):
		var tambahan = parent.get_data_simpanan_tambahan()
		if tambahan is Dictionary:
			data.merge(tambahan, true)
	return data
