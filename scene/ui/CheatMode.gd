extends Control

const IKON_TENGKORAK: Texture2D = preload("res://scene/ui/cheat_skull.svg")
const JARAK_POPUP_Y := 22.0

var aktif := false
# id_barang -> jadual drop penuh (Array[PackedScene]).
# Jadual dikumpul daripada setiap DropComponent yang pernah masuk tree,
# jadi cheat tidak bergantung pada musuh yang masih hidup di sebelah item.
var _jadual_drop: Dictionary = {}
# Cache data barang ikut resource_path supaya scene item tidak
# di-instantiate berulang kali setiap kali musuh baru muncul.
var _cache_data: Dictionary = {}
var _status: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Diletakkan di atas butang MENU yang berada di hujung bawah kanan.
	offset_left = -88.0
	offset_top = -114.0
	offset_right = -8.0
	offset_bottom = -56.0
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
	call_deferred("_imbas_jadual_drop")

func _togol() -> void:
	aktif = not aktif
	_kemas_status()

func _kemas_status() -> void:
	if is_instance_valid(_status):
		_status.text = "ON" if aktif else "OFF"
		_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55) if aktif else Color(1.0, 0.45, 0.45))

func _on_node_added(nod: Node) -> void:
	# Jadual drop didaftar walaupun cheat belum dihidupkan.
	if "drop_scenes" in nod:
		_daftar_jadual(nod)
	if not aktif or not (nod is Area2D) or not (nod is Node2D) or not ("id_barang" in nod):
		return
	# DropComponent queue_free() item itu serta-merta selepas spawn, jadi nod
	# tidak sah lagi bila deferred call berjalan. Ambil data yang perlu sekarang
	# dan hantar nilai ringkas sahaja.
	call_deferred("_ganjar_semua_drop", str(nod.get("id_barang")), (nod as Node2D).global_position)

# Imbas adegan semasa untuk DropComponent yang sudah wujud sebelum cheat
# menyambung isyarat node_added.
func _imbas_jadual_drop() -> void:
	for _cubaan in range(3):
		var adegan_semasa := get_tree().current_scene
		if adegan_semasa != null:
			var menunggu: Array[Node] = [adegan_semasa]
			while not menunggu.is_empty():
				var nod: Node = menunggu.pop_back()
				if "drop_scenes" in nod:
					_daftar_jadual(nod)
				menunggu.append_array(nod.get_children())
			return
		await get_tree().process_frame

func _daftar_jadual(komponen: Node) -> void:
	var jadual: Array[PackedScene] = []
	for adegan: PackedScene in komponen.get("drop_scenes"):
		if adegan != null:
			jadual.append(adegan)
	if jadual.is_empty():
		return
	for adegan in jadual:
		var data := _data_barang(adegan)
		var id := str(data.get("id", ""))
		if id.is_empty() or _jadual_drop.has(id):
			continue
		_jadual_drop[id] = jadual

func _ganjar_semua_drop(id_drop: String, pusat_drop: Vector2) -> void:
	if not aktif:
		return
	var jadual: Array = _jadual_drop.get(id_drop, [])
	if jadual.is_empty():
		var komponen := _cari_sumber_drop(pusat_drop, id_drop)
		if komponen == null:
			return
		jadual = komponen.get("drop_scenes")
	if jadual.is_empty():
		return
	var inventori := get_node_or_null("/root/InventoryManager")
	if inventori == null or not inventori.has_method("tambah_item"):
		return
	var adegan_semasa := get_tree().current_scene
	if adegan_semasa == null:
		return

	# Item dikredit terus ke inventori, animasi guna popup "+N" yang sama
	# seperti drop biasa (bukan terbang ke butang inventori).
	# Susun menegak supaya popup tidak bertindih bila banyak jenis item keluar.
	var ada_item := false
	var indeks_popup := 0
	for adegan in jadual:
		if not aktif or not is_instance_valid(inventori):
			break
		if adegan == null:
			continue
		var data := _data_barang(adegan)
		if data.is_empty():
			continue
		var bilangan := 9 if str(data.get("id")) == id_drop else 10
		for _i in range(bilangan):
			inventori.tambah_item(data.duplicate(), true)
		ada_item = true

		var ikon = data.get("ikon")
		var ikon_tekstur: Texture2D = ikon if ikon is Texture2D else null
		var ofset_popup := Vector2(0.0, -indeks_popup * JARAK_POPUP_Y)
		DropComponent.tunjuk_popup_terapung(ikon_tekstur, "+" + str(bilangan), pusat_drop + ofset_popup, self)
		indeks_popup += 1

	if ada_item and is_instance_valid(inventori) and inventori.has_method("kemas_kini_selepas_batch"):
		inventori.kemas_kini_selepas_batch()

# Fallback lama: cari DropComponent pada musuh yang masih ada di kedudukan
# item. Hanya digunakan kalau jadual id tersebut belum pernah didaftar.
func _cari_sumber_drop(pusat_drop: Vector2, id_drop: String) -> Node:
	for nama_kumpulan in ["enemy", "enemies"]:
		for musuh in get_tree().get_nodes_in_group(nama_kumpulan):
			if not is_instance_valid(musuh) or not (musuh is Node2D):
				continue
			if musuh.global_position.distance_to(pusat_drop) > 2.0:
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
	var kunci := adegan.resource_path
	if not kunci.is_empty() and _cache_data.has(kunci):
		var data_cache: Dictionary = _cache_data[kunci]
		return data_cache.duplicate()
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
	if not kunci.is_empty():
		_cache_data[kunci] = data.duplicate()
	return data
