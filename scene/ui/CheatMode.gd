extends Control

const IKON_TENGKORAK: Texture2D = preload("res://scene/ui/cheat_skull.svg")

var aktif := false
var _status: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -88.0
	offset_top = -66.0
	offset_right = -8.0
	offset_bottom = -8.0
	mouse_filter = Control.MOUSE_FILTER_PASS

	var susunan := VBoxContainer.new()
	susunan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	susunan.add_theme_constant_override("separation", 0)
	add_child(susunan)

	var tajuk := Label.new()
	tajuk.text = "CHEAT MODE"
	tajuk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tajuk.add_theme_font_size_override("font_size", 7)
	tajuk.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	susunan.add_child(tajuk)

	var butang := Button.new()
	butang.custom_minimum_size = Vector2(32.0, 32.0)
	butang.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	butang.icon = IKON_TENGKORAK
	butang.expand_icon = true
	butang.flat = true
	butang.focus_mode = Control.FOCUS_NONE
	butang.pressed.connect(_togol)
	susunan.add_child(butang)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 7)
	susunan.add_child(_status)
	_kemas_status()
	get_tree().node_added.connect(_on_node_added)

func _togol() -> void:
	aktif = not aktif
	_kemas_status()

func _kemas_status() -> void:
	if is_instance_valid(_status):
		_status.text = "ON" if aktif else "OFF"
		_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55) if aktif else Color(1.0, 0.45, 0.45))

func _on_node_added(nod: Node) -> void:
	if not aktif or not (nod is Area2D) or not ("id_barang" in nod):
		return
	var id_drop := str(nod.get("id_barang"))
	var komponen := _cari_sumber_drop(nod, id_drop)
	if komponen != null:
		var senarai_drop: Array = komponen.get("drop_scenes").duplicate()
		call_deferred("_ganjar_semua_drop", nod, id_drop, senarai_drop)

func _ganjar_semua_drop(item_drop: Node, id_drop: String, senarai_drop: Array) -> void:
	if not aktif or not is_instance_valid(item_drop):
		return
	var inventori := get_node_or_null("/root/InventoryManager")
	if inventori == null or not inventori.has_method("tambah_item"):
		return

	for adegan: PackedScene in senarai_drop:
		if adegan == null:
			continue
		var data := _data_barang(adegan)
		if data.is_empty():
			continue
		var bilangan := 9 if str(data.get("id")) == id_drop else 10
		_tambah_kuantiti(inventori, data, bilangan)
	inventori.inventory_dikemaskini.emit()
	SaveManager.save_game()

func _tambah_kuantiti(inventori: Node, data: Dictionary, kuantiti: int) -> void:
	for barang in inventori.senarai_barang:
		if str(barang.get("id", "")) == str(data.get("id", "")):
			barang["kuantiti"] = int(barang.get("kuantiti", 0)) + kuantiti
			return
	data["kuantiti"] = kuantiti
	inventori.senarai_barang.append(data)

func _cari_sumber_drop(item_drop: Node, id_drop: String) -> Node:
	for nama_kumpulan in ["enemy", "enemies"]:
		for musuh in get_tree().get_nodes_in_group(nama_kumpulan):
			if not is_instance_valid(musuh) or not (musuh is Node2D):
				continue
			if musuh.global_position.distance_to((item_drop as Node2D).global_position) > 2.0:
				continue
			var komponen := musuh.find_child("DropComponent", true, false)
			if komponen == null or not ("drop_scenes" in komponen):
				continue
			for adegan: PackedScene in komponen.get("drop_scenes"):
				var data := _data_barang(adegan)
				if str(data.get("id", "")) == id_drop:
					return komponen
	return null

func _data_barang(adegan: PackedScene) -> Dictionary:
	if adegan == null:
		return {}
	var contoh := adegan.instantiate()
	if contoh == null or not ("id_barang" in contoh):
		if is_instance_valid(contoh):
			contoh.free()
		return {}
	var data := {
		"id": str(contoh.get("id_barang")),
		"nama": str(contoh.get("nama_barang")),
		"ikon": contoh.get("ikon_barang"),
		"scene_path": adegan.resource_path,
	}
	contoh.free()
	return data
