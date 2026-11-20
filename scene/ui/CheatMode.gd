extends Control

const IKON_TENGKORAK: Texture2D = preload("res://scene/ui/cheat_skull.svg")
const JEJARI_TABURAN := 42.0
const MASA_PENERBANGAN := 0.6
# Bilangan visual dibina setiap frame. Membina semua item serentak
# memakan satu frame yang sangat panjang (fps drop).
const SPAWN_SETIAP_FRAME := 6

var aktif := false
# Bilangan visual yang belum selesai dikredit ke inventori.
var _baki_inventori := 0
var _status: Label
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
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

func _ganjar_semua_drop(item_drop: Node) -> void:
	if not aktif or not is_instance_valid(item_drop) or not item_drop.is_inside_tree():
		return
	var id_drop := str(item_drop.get("id_barang"))
	var komponen := _cari_sumber_drop(item_drop, id_drop)
	if komponen == null:
		return
	var inventori := get_node_or_null("/root/InventoryManager")
	if inventori == null or not inventori.has_method("tambah_item"):
		return
	var adegan_semasa := get_tree().current_scene
	if adegan_semasa == null:
		return

	var pusat_drop := (item_drop as Node2D).global_position
	var posisi_sasaran := _posisi_inventori(item_drop)

	# Kumpul semua item dahulu. Visual kemudian dibina sedikit demi sedikit
	# antara frame supaya satu frame tidak terpaksa instantiate puluhan item.
	var senarai: Array[Dictionary] = []
	for adegan: PackedScene in komponen.get("drop_scenes"):
		if adegan == null:
			continue
		var data := _data_barang(adegan)
		if data.is_empty():
			continue
		var bilangan := 9 if str(data.get("id")) == id_drop else 10
		for _i in range(bilangan):
			senarai.append({"adegan": adegan, "data": data.duplicate()})

	var dikira := 0
	for entri in senarai:
		if not aktif or not is_instance_valid(inventori):
			return
		_tayang_item(entri["adegan"], entri["data"], pusat_drop, posisi_sasaran, inventori, adegan_semasa)
		dikira += 1
		if dikira % SPAWN_SETIAP_FRAME == 0:
			await get_tree().process_frame

func _tayang_item(adegan: PackedScene, data: Dictionary, pusat_drop: Vector2, posisi_sasaran: Vector2, inventori: Node, induk: Node) -> void:
	var visual := adegan.instantiate() as Node2D
	if visual == null:
		inventori.tambah_item(data)
		return

	visual.set_meta("cheat_visual_item", true)
	# Matikan skrip/fizik visual SEBELUM masuk tree supaya ia tidak sempat
	# memproses apa-apa pada frame ia di-spawn.
	visual.set_process(false)
	visual.set_physics_process(false)
	if "monitoring" in visual:
		visual.set("monitoring", false)
		visual.set("monitorable", false)
	induk.add_child(visual)
	if visual.has_node("CollisionShape2D"):
		visual.get_node("CollisionShape2D").set_deferred("disabled", true)

	var sudut := _rng.randf_range(0.0, TAU)
	var jarak := _rng.randf_range(8.0, JEJARI_TABURAN)
	visual.global_position = pusat_drop + Vector2.from_angle(sudut) * jarak

	_baki_inventori += 1
	var tween := get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "global_position", posisi_sasaran, MASA_PENERBANGAN)
	tween.tween_property(visual, "scale", Vector2.ZERO, MASA_PENERBANGAN)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(inventori):
			# senyap: UI/simpanan dikemas kini sekali sahaja bila semua habis.
			inventori.tambah_item(data, true)
		if is_instance_valid(visual):
			visual.queue_free()
		_baki_inventori -= 1
		if _baki_inventori <= 0:
			_baki_inventori = 0
			if is_instance_valid(inventori) and inventori.has_method("kemas_kini_selepas_batch"):
				inventori.kemas_kini_selepas_batch()
	)

func _posisi_inventori(item_drop: Node) -> Vector2:
	var sasaran := (item_drop as Node2D).global_position
	var adegan_semasa := get_tree().current_scene
	if adegan_semasa == null:
		return sasaran

	var kanvas := adegan_semasa.find_child("CanvasLayer", true, false)
	var butang := kanvas.find_child("InventoryButton", true, false) as Control if kanvas else null
	if butang and butang.is_visible_in_tree():
		return (item_drop as Node2D).get_canvas_transform().affine_inverse() * (butang.global_position + butang.size / 2.0)

	var pemain := adegan_semasa.find_child("SpaceShip", true, false)
	if not pemain:
		pemain = adegan_semasa.find_child("Player", true, false)
	if pemain is Node2D:
		return pemain.global_position
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
