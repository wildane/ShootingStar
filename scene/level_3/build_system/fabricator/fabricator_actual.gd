extends StaticBody2D

# 🔴 Komponen Save
@onready var save_component = $SaveComponent 

# 🔴 Rujukan Nod Utama
@onready var sprite = get_node_or_null("Sprite2D")
@onready var area_penderia = get_node_or_null("Area2D")
@onready var menu_ui = get_node_or_null("CanvasLayer/MenuUI") 
@onready var butang_tutup = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonTutup")
@onready var butang_demolish = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonDemolish")

# 🔴 Tetapan Konfigurasi Dinamik
var player_dekat: bool = false
var masa_ketikan_terakhir: float = 0.0
const SELA_MASA_MINIMUM: float = 0.2  

@export var power_required: float = 20.0  
var has_power: bool = false               
var inverter_pembekal: Node2D = null

# ==========================================================
# 🛠️ CRAFT DRON (hanya untuk Fabricator, bukan Kitchen Table)
# ==========================================================
@export var boleh_craft_drone: bool = false

const IKON_DRON: String = "res://scene/WeaponAttachment/Drone/Image_836.png"

# Resipi dron: item yang dihasilkan + bahan yang dipotong dari beg.
# Ubah kuantiti di sini kalau nak laraskan kos.
var resipi_dron: Array[Dictionary] = [
	{
		"id": "drone_ringan",
		"nama": "Drone Ringan",
		"item": "res://scene/WeaponAttachment/Drone/item/DroneRinganItem.tscn",
		"warna": Color(0.45, 0.95, 1.0),
		"keterangan": "Dron pantas yang menembak kerap pada jarak dekat. Bagus untuk kawal kawanan musuh kecil.",
		"bahan": [{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 5}],
	},
	{
		"id": "drone_sederhana",
		"nama": "Drone Sederhana",
		"item": "res://scene/WeaponAttachment/Drone/item/DroneSederhanaItem.tscn",
		"warna": Color.WHITE,
		"keterangan": "Dron serdahana dengan tembakan seimbang. Pilihan selamat untuk mula meneroka.",
		"bahan": [
			{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 8},
			{"id": "item_0003", "nama": "Raw Silica", "kuantiti": 3},
		],
	},
	{
		"id": "drone_berat",
		"nama": "Drone Berat",
		"item": "res://scene/WeaponAttachment/Drone/item/DroneBeratItem.tscn",
		"warna": Color(1.0, 0.65, 0.25),
		"keterangan": "Dron berat yang menembak jarak jauh dengan kerosakan besar. Makan tenaga player lebih banyak.",
		"bahan": [
			{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 12},
			{"id": "item_0003", "nama": "Raw Silica", "kuantiti": 5},
			{"id": "item_0004", "nama": "Rock Anomaly (Geode)", "kuantiti": 2},
		],
	},
]

# UI craft dron (semua di dalam menu Fabricator, tiada panel bertindih)
var _butang_dron: Button = null
var _tajuk_menu: Control = null
var _baris_menu: Control = null
var _kotak_craft: VBoxContainer = null
var _grid_dron: GridContainer = null
var _slot_dron: Array[PanelContainer] = []
var _label_nama: Label = null
var _label_harga: Label = null
var _label_keterangan: Label = null
var _butang_craft: Button = null
var _pilihan_craft: int = 0
var _offset_asli: Rect2 = Rect2()


func _ready():
	# 1. Masuk group perabot
	add_to_group("Furniture") 

	# 2. Sediakan sambungan isyarat (signals)
	if area_penderia:
		area_penderia.input_pickable = true
		area_penderia.body_entered.connect(_on_body_entered)
		area_penderia.body_exited.connect(_on_body_exited)
		area_penderia.input_event.connect(_on_area_input_event)
		
	if menu_ui:
		menu_ui.hide()
		
	if butang_tutup: butang_tutup.pressed.connect(_on_butang_tutup_pressed)
	if butang_demolish: butang_demolish.pressed.connect(_on_butang_demolish_pressed)

	_kemas_kini_warna_visual()

	if boleh_craft_drone:
		_bina_ui_craft.call_deferred()
	
	# 🔥 AUTOMATIK: Cetus fungsi auto-save sebaik sahaja objek selesai di-spawn
	_auto_save_selepas_wujud()

# 🔒 Fungsi Dalaman: Menunggu pendaftaran group selesai sebelum melakukan save game
func _auto_save_selepas_wujud() -> void:
	# Tunggu 1 frame supaya engine Godot sempat daftarkan objek ini ke dalam group "Furniture"
	await get_tree().process_frame
	
	# Panggil SaveManager untuk kunci posisi perabot baharu ini ke dalam json
	if get_node_or_null("/root/SaveManager"):
		SaveManager.save_game()
		print("Sistem Perabot: Objek disahkan wujud dalam group. Automatik di-save!")

# 🔴 DIKEMASKINI: Hanya kumpul fail laluan objek dan kedudukan koordinat dunia sahaja (Bersih Tanpa Logik Kuasa)
func get_save_data() -> Dictionary:
	var data_perabot: Dictionary = {}
	if save_component and save_component.has_method("get_data"):
		data_perabot = save_component.get_data()
	
	# Set koordinat sahaja secara bersih mengikut keperluan SaveManager
	data_perabot["scene_path"] = scene_file_path  
	data_perabot["pos_x"] = global_position.x     
	data_perabot["pos_y"] = global_position.y     
	
	return data_perabot

# 🔴 Sistem Pengurusan Kuasa Elektrik
func set_power_status(status_elektrik: bool, pembekal: Node2D = null) -> void:
	has_power = status_elektrik
	if status_elektrik:
		inverter_pembekal = pembekal
	else:
		if inverter_pembekal == pembekal or pembekal == null:
			inverter_pembekal = null
	_kemas_kini_warna_visual()

# 🔴 Sistem Visual Feedback
func _kemas_kini_warna_visual() -> void:
	if not sprite: return
	if player_dekat: 
		sprite.modulate = Color(0.3, 1.0, 0.3, 1.0) 
	else:
		if has_power: 
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) 
		else: 
			sprite.modulate = Color(0.4, 0.4, 0.4, 1.0) 

# 🔴 Penderia Jarak Player
func _on_body_entered(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = true
		_kemas_kini_warna_visual() 

func _on_body_exited(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = false
		_kemas_kini_warna_visual() 
		_tutup_menu()

# 🔴 Input Klik / Sentuhan Objek
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	var ada_sentuhan = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if ada_sentuhan and player_dekat:
		var masa_sekarang = Time.get_ticks_msec() / 1000.0
		if masa_sekarang - masa_ketikan_terakhir < SELA_MASA_MINIMUM: return
		masa_ketikan_terakhir = masa_sekarang
		
		if menu_ui:
			if menu_ui.visible:
				_tutup_menu()
			else:
				_tutup_craft() # sentiasa mula dari menu utama
				menu_ui.visible = true
				_kemas_kini_craft()
		get_viewport().set_input_as_handled()

# ==========================================================
# 🛠️ SISTEM CRAFT DRON
# ==========================================================
# Menu utama: tajuk + satu ikon dron + butang Close/Demolish.
# Tekan ikon dron = kandungan menu bertukar jadi grid 3 dron (kiri)
# dan kotak keterangan + butang craft (kanan). Tak ada panel bertindih.
func _bina_ui_craft() -> void:
	if menu_ui == null or _butang_dron != null:
		return
	var vbox = menu_ui.get_node_or_null("VBoxContainer")
	if vbox == null:
		return

	_offset_asli = Rect2(menu_ui.offset_left, menu_ui.offset_top, menu_ui.offset_right, menu_ui.offset_bottom)

	_tajuk_menu = vbox.get_child(0)
	_baris_menu = vbox.get_node_or_null("HBoxContainer")

	_butang_dron = Button.new()
	_butang_dron.name = "ButangDron"
	_butang_dron.custom_minimum_size = Vector2(32, 32)
	_butang_dron.flat = true
	_butang_dron.expand_icon = true
	_butang_dron.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_butang_dron.icon = load(IKON_DRON)
	_butang_dron.self_modulate = Color(0.62, 0.66, 0.72, 0.95)
	_butang_dron.tooltip_text = "Buat dron"
	_butang_dron.pressed.connect(_buka_craft)
	vbox.add_child(_butang_dron)
	vbox.move_child(_butang_dron, 1) # bawah tajuk, atas butang Close/Demolish

	_bina_kandungan_craft(vbox)

	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_dikemaskini"):
		if not inv.inventory_dikemaskini.is_connected(_kemas_kini_craft):
			inv.inventory_dikemaskini.connect(_kemas_kini_craft)

	print("Fabricator: Butang craft dron sedia (", resipi_dron.size(), " resipi)")


# Kandungan craft: header (back + tajuk + tutup), grid slot dron, kotak info
func _bina_kandungan_craft(vbox: Node) -> void:
	_kotak_craft = VBoxContainer.new()
	_kotak_craft.name = "KandunganCraftDron"
	_kotak_craft.visible = false
	_kotak_craft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kotak_craft.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kotak_craft.add_theme_constant_override("separation", 2)
	vbox.add_child(_kotak_craft)

	# --- HEADER ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	_kotak_craft.add_child(header)

	var butang_back := Button.new()
	butang_back.text = "<"
	butang_back.add_theme_font_size_override("font_size", 10)
	butang_back.custom_minimum_size = Vector2(20, 18)
	butang_back.pressed.connect(_tutup_craft)
	header.add_child(butang_back)

	var tajuk := Label.new()
	tajuk.text = "Buat Dron"
	tajuk.add_theme_font_size_override("font_size", 11)
	tajuk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tajuk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tajuk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(tajuk)

	var butang_tutup_menu := Button.new()
	butang_tutup_menu.text = "X"
	butang_tutup_menu.add_theme_font_size_override("font_size", 9)
	butang_tutup_menu.custom_minimum_size = Vector2(20, 18)
	butang_tutup_menu.pressed.connect(_on_butang_tutup_pressed)
	header.add_child(butang_tutup_menu)

	# --- BADAN: grid kiri, kotak info kanan ---
	var badan := HBoxContainer.new()
	badan.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badan.add_theme_constant_override("separation", 6)
	_kotak_craft.add_child(badan)

	_grid_dron = GridContainer.new()
	_grid_dron.name = "GridDron"
	_grid_dron.columns = 2
	_grid_dron.add_theme_constant_override("h_separation", 4)
	_grid_dron.add_theme_constant_override("v_separation", 4)
	_grid_dron.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badan.add_child(_grid_dron)

	# Slot kotak (sama macam grid inventory): PanelContainer + butang ikon
	for i in resipi_dron.size():
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(38, 38)
		slot.add_theme_stylebox_override("panel", _gaya_slot(false, false))
		_grid_dron.add_child(slot)

		var b := Button.new()
		b.flat = true
		b.icon = load(IKON_DRON)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.self_modulate = resipi_dron[i]["warna"]
		b.tooltip_text = str(resipi_dron[i]["nama"])
		b.pressed.connect(_pilih_craft.bind(i))
		slot.add_child(b)

		_slot_dron.append(slot)

	# Kotak info kanan: nama, harga, keterangan, butang craft
	var kotak_info := PanelContainer.new()
	kotak_info.name = "KotakInfo"
	kotak_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kotak_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kotak_info.add_theme_stylebox_override("panel", _gaya_slot(false, false))
	badan.add_child(kotak_info)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	kotak_info.add_child(margin)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	margin.add_child(info)

	_label_nama = Label.new()
	_label_nama.add_theme_font_size_override("font_size", 10)
	info.add_child(_label_nama)

	_label_harga = Label.new()
	_label_harga.add_theme_font_size_override("font_size", 9)
	info.add_child(_label_harga)

	_label_keterangan = Label.new()
	_label_keterangan.add_theme_font_size_override("font_size", 9)
	_label_keterangan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_keterangan.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(_label_keterangan)

	_butang_craft = Button.new()
	_butang_craft.name = "ButangCraft"
	_butang_craft.add_theme_font_size_override("font_size", 10)
	_butang_craft.pressed.connect(_on_butang_craft_pressed)
	info.add_child(_butang_craft)

	_pilih_craft(0)


# Kotak slot: bingkai nipis macam slot inventory
func _gaya_slot(terpilih: bool, sudah: bool) -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = Color(0.10, 0.12, 0.16, 0.9)
	gaya.set_corner_radius_all(3)
	gaya.set_border_width_all(1)
	if sudah:
		gaya.border_color = Color(0.35, 1.0, 0.45)
	elif terpilih:
		gaya.border_color = Color.WHITE
	else:
		gaya.border_color = Color(0.35, 0.38, 0.45)
	return gaya


func _buka_craft() -> void:
	if _kotak_craft == null:
		return
	if _tajuk_menu: _tajuk_menu.visible = false
	if _baris_menu: _baris_menu.visible = false
	if _butang_dron: _butang_dron.visible = false
	_kotak_craft.visible = true
	# Besarkan menu sikit (masih dalam skrin 280 lebar) untuk grid + kotak info
	menu_ui.offset_left = -128.0
	menu_ui.offset_right = 128.0
	menu_ui.offset_top = -88.0
	menu_ui.offset_bottom = 88.0
	_kemas_kini_craft()


func _tutup_craft() -> void:
	if _kotak_craft == null:
		return
	_kotak_craft.visible = false
	if _tajuk_menu: _tajuk_menu.visible = true
	if _baris_menu: _baris_menu.visible = true
	if _butang_dron: _butang_dron.visible = true
	menu_ui.offset_left = _offset_asli.position.x
	menu_ui.offset_top = _offset_asli.position.y
	menu_ui.offset_right = _offset_asli.size.x
	menu_ui.offset_bottom = _offset_asli.size.y


# Pilih satu dron dalam grid -> kotak info di kanan bertukar
func _pilih_craft(i: int) -> void:
	if i < 0 or i >= resipi_dron.size():
		return
	_pilihan_craft = i
	_kemas_kini_craft()


func _bilangan_dalam_beg(id_item: String) -> int:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return 0
	return inv.bilangan_item(id_item)


func _sudah_punya(id_item: String) -> bool:
	return _bilangan_dalam_beg(id_item) > 0


func _bahan_cukup(resipi: Dictionary) -> bool:
	for bahan in resipi["bahan"]:
		if _bilangan_dalam_beg(bahan["id"]) < int(bahan["kuantiti"]):
			return false
	return true


# Kemas kini bingkai grid, kotak info dan butang craft
func _kemas_kini_craft() -> void:
	if _kotak_craft == null:
		return

	for i in _slot_dron.size():
		var slot: PanelContainer = _slot_dron[i]
		if not is_instance_valid(slot):
			continue
		var sudah := _sudah_punya(resipi_dron[i]["id"])
		slot.add_theme_stylebox_override("panel", _gaya_slot(i == _pilihan_craft, sudah))
		var isi := slot.get_child(0) as Button
		if isi:
			isi.self_modulate = Color(0.35, 1.0, 0.45) if sudah else resipi_dron[i]["warna"]
			isi.modulate = Color.WHITE if i == _pilihan_craft else Color(0.6, 0.6, 0.6, 0.9)

	if _pilihan_craft < 0 or _pilihan_craft >= resipi_dron.size():
		return
	var resipi: Dictionary = resipi_dron[_pilihan_craft]
	var sudah := _sudah_punya(resipi["id"])

	_label_nama.text = str(resipi["nama"])

	var teks_harga: String = ""
	for bahan in resipi["bahan"]:
		var ada := _bilangan_dalam_beg(bahan["id"])
		var perlu := int(bahan["kuantiti"])
		var tanda: String = "" if ada >= perlu else " (kurang)"
		teks_harga += str(bahan["nama"]) + " " + str(ada) + "/" + str(perlu) + tanda + "\n"
	_label_harga.text = teks_harga.strip_edges()
	_label_harga.modulate = Color(1.0, 0.55, 0.55) if not _bahan_cukup(resipi) and not sudah else Color.WHITE

	_label_keterangan.text = str(resipi["keterangan"])

	if sudah:
		_butang_craft.text = "Dah dibuat"
		_butang_craft.disabled = true
	elif _bahan_cukup(resipi):
		_butang_craft.text = "Buat"
		_butang_craft.disabled = false
	else:
		_butang_craft.text = "Bahan tak cukup"
		_butang_craft.disabled = true


func _on_butang_craft_pressed() -> void:
	if _pilihan_craft < 0 or _pilihan_craft >= resipi_dron.size():
		return
	var resipi: Dictionary = resipi_dron[_pilihan_craft]

	if _sudah_punya(resipi["id"]):
		_tulis_info(str(resipi["nama"]) + " sudah dibuat")
		return

	if not _bahan_cukup(resipi):
		_tulis_info("Bahan tidak cukup untuk " + str(resipi["nama"]))
		return

	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		print("Fabricator: InventoryManager tidak dijumpai!")
		return

	# 1. Potong bahan
	for bahan in resipi["bahan"]:
		inv.tolak_item(bahan["id"], int(bahan["kuantiti"]))

	# 2. Masukkan item dron ke dalam beg (ini yang membuka pilihan dron di HUD)
	inv.tambah_item({
		"id": resipi["id"],
		"nama": resipi["nama"],
		"ikon": load(IKON_DRON),
		"scene_path": resipi["item"],
	})

	_kemas_kini_craft()
	_tulis_info(str(resipi["nama"]) + " siap! Boleh dipilih pada butang dron.")
	print("Fabricator: ", resipi["nama"], " selesai dibuat")


func _tulis_info(teks: String) -> void:
	var adegan := get_tree().current_scene
	if adegan == null:
		return
	var lbl := adegan.find_child("InfoText", true, false) as Label
	if lbl == null:
		return
	lbl.text = teks
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(lbl) and lbl.text == teks:
		lbl.text = ""


# 🔴 Pengurusan Butang UI
func _tutup_menu() -> void:
	_tutup_craft()
	if menu_ui: menu_ui.hide()

func _on_butang_tutup_pressed(): 
	_tutup_menu()

func _on_butang_demolish_pressed():
	print("Sistem Khas: Objek perabot telah dimusnahkan!")
	player_dekat = false
	if sprite: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	queue_free()
	
	# Panggil save semula selepas musnah supaya ia hilang dari fail json
	await get_tree().process_frame
	if get_node_or_null("/root/SaveManager"):
		SaveManager.save_game()
