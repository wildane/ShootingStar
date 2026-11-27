extends StaticBody2D

# 🔴 Rujukan Nod Utama
@onready var sprite = get_node_or_null("Sprite2D")
@onready var area_penderia = get_node_or_null("Area2D")
const TemaPerabot := preload("res://scene/ui/TemaPerabot.gd")
const PowerGridRef := preload("res://scene/level_3/build_system/PowerInverter/PowerGrid.gd")
const REPAIR := preload("res://scene/level_3/build_system/RepairStruktur.gd")
const PANEL_REPAIR := preload("res://scene/level_3/build_system/PanelRepair.gd")

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
		"nama": "Light Drone",
		"item": "res://scene/WeaponAttachment/Drone/item/DroneRinganItem.tscn",
		"warna": Color(0.45, 0.95, 1.0),
		"keterangan": "Fast fire rate, short range. Good for clearing small swarms.",
		"statistik": {"range": 180, "dmg": 1, "tenaga": 0.2, "cooldown": 0.35},
		"bahan": [{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 5, "ikon": "res://scene/Item/0001BasicIronOre/Image_959.png"}],
	},
	{
		"id": "drone_sederhana",
		"nama": "Medium Drone",
		"item": "res://scene/WeaponAttachment/Drone/item/DroneSederhanaItem.tscn",
		"warna": Color.WHITE,
		"keterangan": "Balanced damage and range. A safe all-round pick.",
		"statistik": {"range": 130, "dmg": 2, "tenaga": 6, "cooldown": 1.4},
		"bahan": [
			{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 8, "ikon": "res://scene/Item/0001BasicIronOre/Image_959.png"},
			{"id": "item_0003", "nama": "Raw Silica", "kuantiti": 3, "ikon": "res://scene/Item/0003RawSilica/Image_495.png"},
		],
	},
	{
		"id": "drone_berat",
		"nama": "Heavy Drone",
		"item": "res://scene/WeaponAttachment/Drone/item/DroneBeratItem.tscn",
		"warna": Color(1.0, 0.65, 0.25),
		"keterangan": "Long range and heavy damage, but drains more energy.",
		"statistik": {"range": 320, "dmg": 3, "tenaga": 6, "cooldown": 3.0},
		"bahan": [
			{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 12, "ikon": "res://scene/Item/0001BasicIronOre/Image_959.png"},
			{"id": "item_0003", "nama": "Raw Silica", "kuantiti": 5, "ikon": "res://scene/Item/0003RawSilica/Image_495.png"},
			{"id": "item_0004", "nama": "Rock Anomaly (Geode)", "kuantiti": 2, "ikon": "res://scene/Item/0004Geode/Image_129.png"},
		],
	},
	{
		"id": "item_0014",
		"nama": "Magnetic Shield",
		"item": "res://scene/Item/0014MagneticShield/MagneticShield.tscn",
		"ikon_slot": "res://scene/Item/0014MagneticShield/Image_shield.png",
		"warna": Color(0.55, 0.95, 0.95),
		"keterangan": "Deflector plate built from cosmic scale, steel and husk slime. One craft yields 10 plates. Each plate absorbs one hit completely and is used up, so a full batch blocks 10 hits.",
		"statistik_teks": "Magnetic Shield  x10 per craft\n1 plate = 1 blocked hit",
		"nota_siap": "10 Magnetic Shields crafted!",
		"hasil": 10,
		"boleh_ulang": true,
		"bahan": [
			{"id": "item_0007", "nama": "Cosmic Scale", "kuantiti": 10, "ikon": "res://scene/Item/0007CosmicScale/Image_176.png"},
			{"id": "item_0009", "nama": "Steel", "kuantiti": 10, "ikon": "res://scene/Item/0009Steel/Image_steel.png"},
			{"id": "item_0008", "nama": "Husk Slime", "kuantiti": 10, "ikon": "res://scene/Item/0008HuskSlime/Image_husk_slime.png"},
		],
	},
]

# UI craft dron (semua di dalam menu Fabricator, tiada panel bertindih)
var _tajuk_menu: Control = null
var _baris_menu: Control = null
var _kotak_craft: VBoxContainer = null
var _senarai_kad: VBoxContainer = null
var _kad_dron: Array[Dictionary] = []
var _label_statistik: Label = null
var _label_keterangan: RichTextLabel = null
var _butang_craft: Button = null
# Panel baiki di atas kad resipi (kelihatan hanya bila fabricator rosak).
var _panel_repair = null
var _pilihan_craft: int = 0
var _cache_ikon: Dictionary = {}
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
		TemaPerabot.pasang(menu_ui)
		
	if butang_tutup: butang_tutup.pressed.connect(_on_butang_tutup_pressed)
	if butang_demolish: butang_demolish.pressed.connect(_on_butang_demolish_pressed)

	_kemas_kini_warna_visual()

	if boleh_craft_drone:
		_bina_ui_craft.call_deferred()
	PowerGridRef.daftar_perabot(self)

# 🔴 Sistem Pengurusan Kuasa Elektrik
func set_power_status(status_elektrik: bool, pembekal: Node2D = null) -> void:
	var pembekal_baru: Node2D = inverter_pembekal
	if status_elektrik:
		pembekal_baru = pembekal
	else:
		if inverter_pembekal == pembekal or pembekal == null:
			pembekal_baru = null
	if has_power == status_elektrik and inverter_pembekal == pembekal_baru:
		return
	has_power = status_elektrik
	inverter_pembekal = pembekal_baru
	_kemas_kini_warna_visual()
	# Butang craft kena ikut status kuasa semasa (menu mungkin tengah dibuka).
	# Hanya kemas kini bila status/pembekal betul-betul berubah supaya senarai
	# harga tak dibina semula setiap 0.15s inverter.
	_kemas_kini_craft()

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
# =========================
# Klik mouse pada PC
# =========================
# AstroStateMachine menandakan setiap klik kiri mouse sebagai "handled" dalam
# _unhandled_input, jadi physics picking Area2D dibatalkan dan input_event
# perabot tidak pernah dicetus pada PC. _input berjalan lebih awal, jadi klik
# dihantar ke pengendali sedia ada sebagai sentuhan maya.
func _input(event: InputEvent) -> void:
	var klik := event as InputEventMouseButton
	if klik == null or not klik.pressed or klik.button_index != MOUSE_BUTTON_LEFT:
		return
	if not player_dekat or area_penderia == null:
		return
	# Jangan rampas klik yang sepatutnya milik butang/panel UI.
	var kawalan := get_viewport().gui_get_hovered_control()
	if kawalan != null and kawalan.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return
	if not _klik_dalam_kawasan(klik.position):
		return
	var sentuhan := InputEventScreenTouch.new()
	sentuhan.index = 0
	sentuhan.position = klik.position
	sentuhan.pressed = true
	_on_area_input_event(get_viewport(), sentuhan, 0)
	get_viewport().set_input_as_handled()


# Zon klik perabot ikut CollisionShape2D pada Area2D, dengan sedikit toleransi.
func _klik_dalam_kawasan(pos_skrin: Vector2) -> bool:
	var titik: Vector2 = area_penderia.to_local(get_canvas_transform().affine_inverse() * pos_skrin)
	var ada_bentuk := false
	for anak in area_penderia.get_children():
		if anak is CollisionShape2D and anak.shape is RectangleShape2D:
			ada_bentuk = true
			var jejari: Vector2 = anak.shape.size * 0.5 + Vector2(2.0, 2.0)
			if Rect2(anak.position - jejari, jejari * 2.0).has_point(titik):
				return true
	if ada_bentuk:
		return false
	return titik.length() < 24.0


# =========================
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
				# Tiada menu depan - menu terus buka dengan senarai kad resipi.
				menu_ui.visible = true
				_kemas_kini_craft()
		get_viewport().set_input_as_handled()

# ==========================================================
# 🛠️ SISTEM CRAFT DRON
# ==========================================================
# Menu terus tunjuk kad resipi, kotak statistik + butang Craft,
# dan butang Close/Demolish di bawah sekali (tiada menu depan).
func _bina_ui_craft() -> void:
	if menu_ui == null or _kotak_craft != null:
		return
	var vbox = menu_ui.get_node_or_null("VBoxContainer")
	if vbox == null:
		return

	_tajuk_menu = vbox.get_child(0)
	_baris_menu = vbox.get_node_or_null("HBoxContainer")

	# Tajuk "Fabricator" duduk di atas sekali, kandungan disusun dari atas
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	if _tajuk_menu:
		_tajuk_menu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_bina_kandungan_craft(vbox)
	_bina_panel_repair(vbox)

	# Butang Close/Demolish sentiasa di bawah kad + butang Craft.
	if _baris_menu:
		vbox.move_child(_baris_menu, vbox.get_child_count() - 1)

	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_dikemaskini"):
		if not inv.inventory_dikemaskini.is_connected(_kemas_kini_craft):
			inv.inventory_dikemaskini.connect(_kemas_kini_craft)

	print("Fabricator: Butang craft sedia (", _semua_resipi().size(), " resipi)")


# Panel baiki: bahan repair + butang Repair di atas kad resipi.
func _bina_panel_repair(vbox: Node) -> void:
	if vbox == null or _panel_repair != null:
		return
	_panel_repair = PANEL_REPAIR.new()
	vbox.add_child(_panel_repair)
	vbox.move_child(_panel_repair, 1)
	_panel_repair.sediakan(self)
	_panel_repair.selesai_baiki.connect(_kemas_kini_craft)

# Kandungan craft: senarai kad resipi dron, kotak info, butang Craft
func _bina_kandungan_craft(vbox: Node) -> void:
	_kotak_craft = VBoxContainer.new()
	_kotak_craft.name = "KandunganCraftDron"
	_kotak_craft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kotak_craft.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kotak_craft.add_theme_constant_override("separation", 2)
	vbox.add_child(_kotak_craft)

	# --- BADAN: senarai kad resipi (gaya kad dapur) ---
	# Setiap dron satu kad: ikon dron + nama + ikon bahan dengan kiraan
	# "perlu/ada". Klik kad untuk pilih dron yang hendak dibuat.
	_senarai_kad = VBoxContainer.new()
	_senarai_kad.name = "SenaraiKad"
	_senarai_kad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_senarai_kad.add_theme_constant_override("separation", 2)
	_kotak_craft.add_child(_senarai_kad)

	var senarai := _semua_resipi()
	for i in senarai.size():
		_senarai_kad.add_child(_bina_kad(i, senarai[i]))

	# Kotak maklumat dron terpilih: stats + keterangan (boleh scroll).
	var kotak_info := PanelContainer.new()
	kotak_info.name = "KotakInfo"
	kotak_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kotak_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kotak_info.add_theme_stylebox_override("panel", _gaya_slot(false, false))
	_kotak_craft.add_child(kotak_info)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_bottom", 2)
	kotak_info.add_child(margin)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	margin.add_child(info)

	# Scroll untuk stats dan keterangan sahaja, supaya butang craft kekal
	# di bawah walaupun teks panjang.
	var skrol_info := ScrollContainer.new()
	skrol_info.name = "SkrolInfo"
	skrol_info.custom_minimum_size = Vector2(0, 56)
	skrol_info.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skrol_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skrol_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(skrol_info)

	var isi_info := VBoxContainer.new()
	isi_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	isi_info.add_theme_constant_override("separation", 1)
	skrol_info.add_child(isi_info)

	_label_statistik = Label.new()
	_label_statistik.add_theme_font_size_override("font_size", 7)
	_label_statistik.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_statistik.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_statistik.modulate = Color(0.75, 0.85, 1.0)
	isi_info.add_child(_label_statistik)

	_label_keterangan = RichTextLabel.new()
	_label_keterangan.name = "KeteranganDron"
	_label_keterangan.bbcode_enabled = false
	_label_keterangan.scroll_active = false
	_label_keterangan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_keterangan.fit_content = true
	_label_keterangan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_keterangan.add_theme_font_size_override("normal_font_size", 7)
	isi_info.add_child(_label_keterangan)

	_butang_craft = Button.new()
	_butang_craft.name = "ButangCraft"
	_butang_craft.custom_minimum_size = Vector2(0, 16)
	_butang_craft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_butang_craft.size_flags_vertical = Control.SIZE_SHRINK_END # sentiasa di bawah kotak
	_butang_craft.add_theme_font_size_override("font_size", 8)
	_butang_craft.pressed.connect(_on_butang_craft_pressed)
	_kotak_craft.add_child(_butang_craft)

	_pilih_craft(0)


# Satu kad resipi, susun atur ikut kad dapur: ikon hasil di kiri,
# nama di atas dan baris ikon bahan (perlu/ada) di bawah nama.
func _bina_kad(indeks: int, resipi: Dictionary) -> PanelContainer:
	var kad := PanelContainer.new()
	kad.name = "KadDron%d" % indeks
	kad.custom_minimum_size = Vector2(0, 30)
	kad.add_theme_stylebox_override("panel", _gaya_kad(indeks == _pilihan_craft))
	kad.gui_input.connect(_on_kad_diklik.bind(indeks))

	var baris := HBoxContainer.new()
	baris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	baris.add_theme_constant_override("separation", 3)
	kad.add_child(baris)

	# Ikon dron + kiraan yang sudah ada dalam beg (macam kad dapur).
	var wadah_ikon := Control.new()
	wadah_ikon.custom_minimum_size = Vector2(24, 20)
	wadah_ikon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	baris.add_child(wadah_ikon)

	var ikon_keluar := TextureRect.new()
	ikon_keluar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ikon_keluar.offset_left = 1.0
	ikon_keluar.offset_top = 1.0
	ikon_keluar.offset_right = -1.0
	ikon_keluar.offset_bottom = -1.0
	ikon_keluar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ikon_keluar.texture = _ikon_resipi(resipi)
	ikon_keluar.self_modulate = resipi["warna"]
	ikon_keluar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ikon_keluar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ikon_keluar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wadah_ikon.add_child(ikon_keluar)

	var kiraan := Label.new()
	kiraan.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	kiraan.offset_left = -14.0
	kiraan.offset_top = -10.0
	kiraan.offset_right = -1.0
	kiraan.offset_bottom = 1.0
	kiraan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kiraan.add_theme_font_size_override("font_size", 6)
	kiraan.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.07, 1))
	kiraan.add_theme_constant_override("outline_size", 2)
	kiraan.text = "0"
	kiraan.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wadah_ikon.add_child(kiraan)

	var maklumat := VBoxContainer.new()
	maklumat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	maklumat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	maklumat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	maklumat.add_theme_constant_override("separation", 1)
	baris.add_child(maklumat)

	var nama := Label.new()
	nama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nama.add_theme_font_size_override("font_size", 7)
	nama.text = str(resipi["nama"])
	maklumat.add_child(nama)

	var baris_bahan := HBoxContainer.new()
	baris_bahan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	baris_bahan.add_theme_constant_override("separation", 5)
	maklumat.add_child(baris_bahan)

	var slot_bahan: Array[Control] = []
	var ikon_bahan: Array[TextureRect] = []
	var label_bahan: Array[Label] = []
	var bahan: Array = resipi["bahan"]
	for j in 3:
		var wadah := VBoxContainer.new()
		wadah.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wadah.add_theme_constant_override("separation", 0)
		wadah.visible = j < bahan.size()
		baris_bahan.add_child(wadah)

		var ikon := TextureRect.new()
		ikon.custom_minimum_size = Vector2(10, 10)
		ikon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ikon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ikon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ikon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ikon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wadah.add_child(ikon)

		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 5)
		lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.07, 1))
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wadah.add_child(lbl)

		slot_bahan.append(wadah)
		ikon_bahan.append(ikon)
		label_bahan.append(lbl)

	_kad_dron.append({
		"panel": kad,
		"nama": nama,
		"ikon_keluar": ikon_keluar,
		"label_keluar": kiraan,
		"slot_bahan": slot_bahan,
		"ikon_bahan": ikon_bahan,
		"label_bahan": label_bahan,
	})
	return kad


# Klik kad untuk tukar dron yang hendak dibuat.
func _on_kad_diklik(event: InputEvent, indeks: int) -> void:
	var sentuhan: bool = event is InputEventScreenTouch and event.pressed
	var klik: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if not (sentuhan or klik):
		return
	_pilih_craft(indeks)


# Gaya kad resipi: latar gelap, bingkai cyan bila dipilih, hijau bila siap.
func _gaya_kad(dipilih: bool, sudah: bool = false) -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = Color(0.031, 0.082, 0.13, 0.95) if dipilih else Color(0.024, 0.062, 0.094, 0.9)
	if sudah:
		gaya.border_color = Color(0.45, 1.0, 0.55, 0.95)
	elif dipilih:
		gaya.border_color = Color(0.45, 0.92, 1, 0.95)
	else:
		gaya.border_color = Color(0.2, 0.4, 0.5, 0.55)
	gaya.set_border_width_all(1)
	gaya.set_corner_radius_all(3)
	gaya.set_content_margin_all(3.0)
	return gaya


# Kotak slot: bingkai nipis macam slot inventory
func _gaya_slot(terpilih: bool, sudah: bool) -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = Color(0.043, 0.10, 0.15, 0.92)
	gaya.set_corner_radius_all(2)
	gaya.set_border_width_all(1)
	if sudah:
		gaya.border_color = Color(0.45, 1.0, 0.55)
	elif terpilih:
		gaya.border_color = Color(0.5, 0.97, 1, 1)
	else:
		gaya.border_color = Color(0.36, 0.9, 1, 0.45)
	return gaya


# Pilih satu dron dalam grid -> kotak info di kanan bertukar
func _pilih_craft(i: int) -> void:
	if i < 0 or i >= _semua_resipi().size():
		return
	_pilihan_craft = i
	_kemas_kini_craft()


# Semua resipi dron dalam satu menu craft.
func _semua_resipi() -> Array[Dictionary]:
	var senarai: Array[Dictionary] = []
	senarai.append_array(resipi_dron)
	return senarai


func _bilangan_dalam_beg(id_item: String) -> int:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return 0
	return inv.bilangan_item(id_item)


func _sudah_punya(id_item: String) -> bool:
	return _bilangan_dalam_beg(id_item) > 0


# Resipi boleh diulang walaupun barangnya sudah ada (contoh: Magnetic Shield
# yang ditolak dari beg setiap kali menyerap serangan).
func _boleh_ulang(resipi: Dictionary) -> bool:
	return bool(resipi.get("boleh_ulang", false))


# Ikon slot dron guna fail imej resipi masing-masing.
func _ikon_resipi(resipi: Dictionary) -> Texture2D:
	return _muat_ikon(str(resipi.get("ikon_slot", IKON_DRON)))


# Simpan tekstur dalam cache supaya kad tak muat semula fail setiap kemas kini.
func _muat_ikon(laluan: String) -> Texture2D:
	if laluan == "":
		return null
	if _cache_ikon.has(laluan):
		return _cache_ikon[laluan]
	if not ResourceLoader.exists(laluan):
		return null
	var tekstur: Texture2D = load(laluan)
	_cache_ikon[laluan] = tekstur
	return tekstur


func _bahan_cukup(resipi: Dictionary) -> bool:
	for bahan in resipi["bahan"]:
		if _bilangan_dalam_beg(bahan["id"]) < int(bahan["kuantiti"]):
			return false
	return true


# Kemas kini kad resipi, kotak stats dan butang craft
func _kemas_kini_craft() -> void:
	if is_instance_valid(_panel_repair):
		_panel_repair.segarkan()
	if _kotak_craft == null or _kad_dron.is_empty():
		return

	var senarai := _semua_resipi()
	for i in _kad_dron.size():
		if i >= senarai.size():
			continue
		var kad: Dictionary = _kad_dron[i]
		var resipi: Dictionary = senarai[i]
		var sudah := _sudah_punya(str(resipi["id"])) and not _boleh_ulang(resipi)

		var panel: PanelContainer = kad["panel"]
		if panel:
			panel.add_theme_stylebox_override("panel", _gaya_kad(i == _pilihan_craft, sudah))
		var ikon_keluar: TextureRect = kad["ikon_keluar"]
		if ikon_keluar:
			ikon_keluar.self_modulate = Color(0.35, 1.0, 0.45) if sudah else resipi["warna"]
		var kiraan: Label = kad["label_keluar"]
		if kiraan:
			kiraan.text = str(_bilangan_dalam_beg(str(resipi["id"])))

		var bahan: Array = resipi["bahan"]
		for j in kad["slot_bahan"].size():
			var wadah: Control = kad["slot_bahan"][j]
			if j >= bahan.size():
				wadah.visible = false
				continue
			wadah.visible = true
			var data_bahan: Dictionary = bahan[j]
			var ikon: TextureRect = kad["ikon_bahan"][j]
			if ikon:
				ikon.texture = _muat_ikon(str(data_bahan.get("ikon", "")))
			var lbl: Label = kad["label_bahan"][j]
			if lbl:
				var ada := _bilangan_dalam_beg(str(data_bahan["id"]))
				var perlu := int(data_bahan["kuantiti"])
				lbl.text = "%d/%d" % [perlu, ada]
				lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55, 1.0) if ada >= perlu else Color(1.0, 0.45, 0.45, 1.0))

	if _pilihan_craft < 0 or _pilihan_craft >= senarai.size():
		return
	var resipi: Dictionary = senarai[_pilihan_craft]
	var sudah := _sudah_punya(str(resipi["id"])) and not _boleh_ulang(resipi)

	if _label_statistik:
		var teks_khas: String = str(resipi.get("statistik_teks", ""))
		if teks_khas != "":
			_label_statistik.text = teks_khas
		else:
			var stat: Dictionary = resipi.get("statistik", {})
			var dmg: String = str(int(stat.get("dmg", 0))) if int(stat.get("dmg", 0)) > 0 else "-"
			_label_statistik.text = "Range " + str(int(stat.get("range", 0))) + "  ·  DMG " + dmg + "  ·  Energy " + str(stat.get("tenaga", 0)) + "\nCooldown " + str(stat.get("cooldown", 0)) + "s"

	if _label_keterangan:
		_label_keterangan.text = str(resipi["keterangan"])

	if _butang_craft:
		if REPAIR.rosak(self):
			_butang_craft.text = "Damaged"
			_butang_craft.disabled = true
		elif sudah:
			_butang_craft.text = "Already crafted"
			_butang_craft.disabled = true
		elif not has_power:
			_butang_craft.text = "No power"
			_butang_craft.disabled = true
		elif _bahan_cukup(resipi):
			_butang_craft.text = "Craft"
			_butang_craft.disabled = false
		else:
			_butang_craft.text = "Not enough materials"
			_butang_craft.disabled = true


func _on_butang_craft_pressed() -> void:
	var senarai := _semua_resipi()
	if _pilihan_craft < 0 or _pilihan_craft >= senarai.size():
		return
	var resipi: Dictionary = senarai[_pilihan_craft]

	if REPAIR.rosak(self):
		_tulis_info("Repair the fabricator first")
		return

	if not _boleh_ulang(resipi) and _sudah_punya(resipi["id"]):
		_tulis_info(str(resipi["nama"]) + " is already crafted")
		return

	# Fabricator perlu kuasa dari inverter sebelum boleh craft
	if not has_power:
		_tulis_info("Fabricator has no power - connect it to a power inverter")
		return

	if not _bahan_cukup(resipi):
		_tulis_info("Not enough materials for " + str(resipi["nama"]))
		return

	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		print("Fabricator: InventoryManager tidak dijumpai!")
		return

	# 1. Potong bahan
	for bahan in resipi["bahan"]:
		inv.tolak_item(bahan["id"], int(bahan["kuantiti"]))

	# 2. Masukkan hasil ke dalam beg (dron membuka pilihan dron di HUD).
	# Resipi boleh tetapkan "hasil" untuk keluarkan lebih dari satu unit;
	# tambah_item hanya menambah 1 setiap panggilan, jadi ulang ikut jumlah.
	var jumlah_hasil: int = maxi(int(resipi.get("hasil", 1)), 1)
	var ikon_hasil: Texture2D = _ikon_resipi(resipi)
	for n in jumlah_hasil:
		inv.tambah_item({
			"id": resipi["id"],
			"nama": resipi["nama"],
			"ikon": ikon_hasil,
			"scene_path": resipi["item"],
		}, true)
	inv.kemas_kini_selepas_batch()

	_kemas_kini_craft()
	_tulis_info(str(resipi.get("nota_siap", str(resipi["nama"]) + " crafted! Select it from the drone button.")))
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
	if menu_ui: menu_ui.hide()

func _on_butang_tutup_pressed(): 
	_tutup_menu()

# Kos bina ikut Fabricator_Preview.tscn: 5 Basic Iron Ore.
func kos_bina() -> Array:
	return [
		{"id": "item_0001", "nama": "Basic Iron Ore", "ikon": load("res://scene/Item/0001BasicIronOre/Image_959.png"), "scene_path": "res://scene/Item/0001BasicIronOre/0001BasicIronOre.tscn", "diperlukan": 5},
	]

func _on_butang_demolish_pressed():
	print("Sistem Khas: Objek perabot telah dimusnahkan!")
	# Perabot yang rosak dirobohkan tanpa pulangan bahan langsung.
	if not REPAIR.rosak(self):
		BahanBinaan.pulangkan(self)
	player_dekat = false
	if sprite: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	PowerGridRef.nyahdaftar_perabot(self)
	queue_free()

func _exit_tree() -> void:
	PowerGridRef.nyahdaftar_perabot(self)
