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
		"bahan": [{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 5}],
	},
	{
		"id": "drone_sederhana",
		"nama": "Drone Sederhana",
		"item": "res://scene/WeaponAttachment/Drone/item/DroneSederhanaItem.tscn",
		"warna": Color.WHITE,
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
		"bahan": [
			{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 12},
			{"id": "item_0003", "nama": "Raw Silica", "kuantiti": 5},
			{"id": "item_0004", "nama": "Rock Anomaly (Geode)", "kuantiti": 2},
		],
	},
]

var _baris_craft: HBoxContainer = null
var _butang_craft: Array[Button] = []

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
		_bina_senarai_craft.call_deferred()
	
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
		if menu_ui: menu_ui.hide() 

# 🔴 Input Klik / Sentuhan Objek
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	var ada_sentuhan = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if ada_sentuhan and player_dekat:
		var masa_sekarang = Time.get_ticks_msec() / 1000.0
		if masa_sekarang - masa_ketikan_terakhir < SELA_MASA_MINIMUM: return
		masa_ketikan_terakhir = masa_sekarang
		
		if menu_ui:
			menu_ui.visible = !menu_ui.visible
			if menu_ui.visible:
				_kemas_kini_butang_craft()
		get_viewport().set_input_as_handled()

# ==========================================================
# 🛠️ SISTEM CRAFT DRON
# ==========================================================
# Baris ikon dron di dalam menu Fabricator: tekan ikon = buat dron itu
func _bina_senarai_craft() -> void:
	if menu_ui == null or _baris_craft != null:
		return
	var vbox := menu_ui.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox == null:
		return

	# Beri ruang tambahan untuk baris craft (panel menu asal cukup untuk 2 butang)
	menu_ui.offset_top -= 22.0
	menu_ui.offset_bottom += 22.0
	menu_ui.custom_minimum_size.y += 44.0

	_baris_craft = HBoxContainer.new()
	_baris_craft.name = "CraftDron"
	_baris_craft.alignment = BoxContainer.ALIGNMENT_CENTER
	_baris_craft.add_theme_constant_override("separation", 4)
	vbox.add_child(_baris_craft)
	vbox.move_child(_baris_craft, 1) # bawah tajuk, atas butang Close/Demolish

	for i in resipi_dron.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(32, 32)
		b.flat = true
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.icon = load(IKON_DRON)
		b.tooltip_text = _teks_resipi(i)
		b.pressed.connect(_on_butang_craft_pressed.bind(i))
		_baris_craft.add_child(b)
		_butang_craft.append(b)

	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_dikemaskini"):
		if not inv.inventory_dikemaskini.is_connected(_kemas_kini_butang_craft):
			inv.inventory_dikemaskini.connect(_kemas_kini_butang_craft)

	_kemas_kini_butang_craft()
	print("Fabricator: Pemilih craft dron sedia (", resipi_dron.size(), " resipi)")


func _teks_resipi(i: int) -> String:
	var resipi: Dictionary = resipi_dron[i]
	var teks: String = "Buat " + str(resipi["nama"])
	for bahan in resipi["bahan"]:
		teks += "\n- " + str(bahan["nama"]) + " x" + str(int(bahan["kuantiti"]))
	return teks


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


func _kemas_kini_butang_craft() -> void:
	for i in _butang_craft.size():
		var b: Button = _butang_craft[i]
		if not is_instance_valid(b):
			continue
		var resipi: Dictionary = resipi_dron[i]
		var sudah := _sudah_punya(resipi["id"])
		if sudah:
			b.self_modulate = Color(0.35, 1.0, 0.45)
			b.disabled = true
		elif _bahan_cukup(resipi):
			b.self_modulate = resipi["warna"]
			b.disabled = false
		else:
			b.self_modulate = Color(0.45, 0.45, 0.45, 0.8)
			b.disabled = false # masih boleh tekan untuk lihat kekurangan bahan


func _on_butang_craft_pressed(i: int) -> void:
	if i < 0 or i >= resipi_dron.size():
		return
	var resipi: Dictionary = resipi_dron[i]

	if _sudah_punya(resipi["id"]):
		_tulis_info(str(resipi["nama"]) + " sudah dibuat")
		return

	if not _bahan_cukup(resipi):
		var kurang: Array[String] = []
		for bahan in resipi["bahan"]:
			var ada := _bilangan_dalam_beg(bahan["id"])
			if ada < int(bahan["kuantiti"]):
				kurang.append(str(bahan["nama"]) + " " + str(ada) + "/" + str(int(bahan["kuantiti"])))
		_tulis_info("Bahan tidak cukup:\n" + "\n".join(kurang))
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

	_kemas_kini_butang_craft()
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
func _on_butang_tutup_pressed(): 
	if menu_ui: menu_ui.hide()

func _on_butang_demolish_pressed():
	print("Sistem Khas: Objek perabot telah dimusnahkan!")
	player_dekat = false
	if sprite: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	queue_free()
	
	# Panggil save semula selepas musnah supaya ia hilang dari fail json
	await get_tree().process_frame
	if get_node_or_null("/root/SaveManager"):
		SaveManager.save_game()
