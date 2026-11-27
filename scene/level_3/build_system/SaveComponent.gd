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
	# Perabot belum ada properti HP sendiri: HP serangan husk disimpan sebagai
	# meta, jadi ia mesti ikut masuk data slot supaya tak reset bila load.
	if parent.has_meta("hp_serangan"):
		data["hp_serangan"] = int(parent.get_meta("hp_serangan"))
		if parent.has_meta("hp_sasaran_maks"):
			data["hp_sasaran_maks"] = int(parent.get_meta("hp_sasaran_maks"))
	# State tambahan khusus perabot (contoh: batch smelter yang belum siap).
	if parent.has_method("get_data_simpanan_tambahan"):
		var tambahan = parent.get_data_simpanan_tambahan()
		if tambahan is Dictionary:
			data.merge(tambahan, true)
	return data
