extends Control

const IKON_TENGKORAK: Texture2D = preload("res://scene/ui/cheat_skull.svg")
const MASA_TERBANG_CHEAT := 0.24

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
	if nod.has_meta("cheat_visual_item"):
		return
	call_deferred("_ganjar_semua_drop", nod)

func _ganjar_semua_drop(item_drop: Node2D) -> void:
	if not aktif or not is_instance_valid(item_drop) or not item_drop.is_inside_tree():
		return
	var id_drop := str(item_drop.get("id_barang"))
	var komponen := _cari_sumber_drop(item_drop, id_drop)
	if komponen == null:
		return
	var inventori := get_node_or_null("/root/InventoryManager")
	if inventori == null or not inventori.has_method("tambah_item"):
		return

	var senarai_drop: Array = komponen.get("drop_scenes").duplicate()
	var posisi_mula := item_drop.global_position
	var posisi_sasaran := _posisi_inventori(item_drop)
	for adegan: PackedScene in senarai_drop:
		if adegan == null:
			continue
		var data := _data_barang(adegan)
		if data.is_empty():
			continue
		var bilangan := 9 if str(data.get("id")) == id_drop else 10
		for _i in range(bilangan):
			if not aktif:
				return
			var item_baru := adegan.instantiate() as Node2D
			if item_baru == null:
				continue
			item_baru.set_meta("cheat_visual_item", true)
			var induk := get_tree().current_scene
			if induk == null:
				item_baru.free()
				return
			induk.add_child(item_baru)
			item_baru.global_position = posisi_mula
			if item_baru.has_node("CollisionShape2D"):
				item_baru.get_node("CollisionShape2D").set_deferred("disabled", true)
			item_baru.set_deferred("monitoring", false)
			item_baru.set_deferred("monitorable", false)
			item_baru.set_process(false)
			item_baru.set_physics_process(false)

			var tween := get_tree().create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(item_baru, "global_position", posisi_sasaran, MASA_TERBANG_CHEAT)
			tween.tween_property(item_baru, "scale", Vector2.ZERO, MASA_TERBANG_CHEAT)
			await tween.finished
			if is_instance_valid(item_baru):
				item_baru.queue_free()
			inventori.tambah_item(data.duplicate())

func _posisi_inventori(item_drop: Node2D) -> Vector2:
	var sasaran := item_drop.global_position
	var adegan_semasa := get_tree().current_scene
	if adegan_semasa == null:
		return sasaran

	var kanvas := adegan_semasa.find_child("CanvasLayer", true, false)
	var butang_inventori := kanvas.find_child("InventoryButton", true, false) as Control if kanvas else null
	if butang_inventori and butang_inventori.is_visible_in_tree():
		var posisi_skrin := butang_inventori.global_position + butang_inventori.size / 2.0
		return item_drop.get_canvas_transform().affine_inverse() * posisi_skrin

	var pemain := adegan_semasa.find_child("SpaceShip", true, false)
	if not pemain:
		pemain = adegan_semasa.find_child("Player", true, false)
	if pemain is Node2D:
		sasaran = pemain.global_position
	return sasaran

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
