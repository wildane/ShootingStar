extends StaticBody2D

## Relau pelebur: 2 Basic Iron Ore + 1 Meteorite Ice -> 1 Steel,
## atau 5 Meteorite Ice -> 1 Bottle of Water + 1 Oxygen Can.
## Semasa melebur, sprite berdenyut warna relau dan ada cahaya api di mulut.
## Menu ada ikon bahan, pilihan kuantiti (batch) dan iklan terapung "+1".

@onready var sprite = get_node_or_null("Sprite2D")
@onready var area_penderia = get_node_or_null("Area2D")
const TemaPerabot := preload("res://scene/ui/TemaPerabot.gd")
const BulatanCraft := preload("res://scene/level_3/build_system/smelter/bulatan_craft.gd")
const PowerGridRef := preload("res://scene/level_3/build_system/PowerInverter/PowerGrid.gd")
const REPAIR := preload("res://scene/level_3/build_system/RepairStruktur.gd")
const PANEL_REPAIR := preload("res://scene/level_3/build_system/PanelRepair.gd")

@onready var menu_ui = get_node_or_null("CanvasLayer/Pusat/MenuUI")
@onready var butang_tutup = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/HBoxContainer/ButtonTutup")
@onready var butang_demolish = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/HBoxContainer/ButtonDemolish")
@onready var label_status = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Header/LabelStatus")
@onready var butang_lebur = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/ButangCraft")
# Rujukan nod bagi setiap kad resipi (KadSteel, KadAir). Kad yang diklik jadi
# resipi aktif; kad lain hanya tunjuk bahan + kiraan keluaran.
@onready var label_kuantiti = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/BarisKuantiti/LabelKuantiti")
@onready var label_maks = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/BarisKuantiti/LabelMaks")
@onready var butang_kurang = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/BarisKuantiti/ButangKurang")
@onready var butang_tambah = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/BarisKuantiti/ButangTambah")


const MASA_LEBUR: float = 3.0

# Animasi iklan terapung "+1": naik dengan laju tetap dan pudar licin sampai
# habis, jadi ia tidak nampak tersekat sebelum hilang.
const MASA_IKLAN: float = 0.65
const JARAK_IKLAN: float = 10.0
const IKLAN_Y_ASAL: float = -26.0
const IKLAN_MULA_PUDAR: float = 0.35

const ID_STEEL := "item_0009"
const LALUAN_STEEL := "res://scene/Item/0009Steel/Steel.tscn"
const IKON_STEEL := "res://scene/Item/0009Steel/Image_steel.png"
const ID_AIR := "item_0010"
const LALUAN_AIR := "res://scene/Item/0010BottleOfWater/BottleOfWater.tscn"
const IKON_AIR := "res://scene/Item/0010BottleOfWater/Image_water_bottle.png"
const ID_OKSIGEN := "item_0011"
const LALUAN_OKSIGEN := "res://scene/Item/0011OxygenCan/OxygenCan.tscn"
const IKON_OKSIGEN := "res://scene/Item/0011OxygenCan/Image_oxygen_can.png"
const LALUAN_BESI := "res://scene/Item/0001BasicIronOre/Image_959.png"
const LALUAN_AIS := "res://scene/Item/0002MeteoriteIce/Image_393.png"

const WARNA_CUKUP := Color(0.5, 0.95, 0.62, 1.0)
const WARNA_KURANG := Color(1.0, 0.44, 0.44, 1.0)
const WARNA_SEDANG := Color(0.72, 0.86, 0.95, 1.0)

# Senarai resipi relau. Setiap resipi ada bahan (yang ditolak dari beg untuk
# satu unit) dan keluaran (item yang dimasukkan ke beg setiap unit siap).
var senarai_resipi: Array[Dictionary] = [
	{
		"nama": "Steel",
		"bahan": [
			{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 2, "ikon": LALUAN_BESI},
			{"id": "item_0002", "nama": "Meteorite Ice", "kuantiti": 1, "ikon": LALUAN_AIS},
		],
		"keluaran": [
			{"id": ID_STEEL, "nama": "Steel", "kuantiti": 1, "ikon": IKON_STEEL, "scene_path": LALUAN_STEEL},
		],
	},
	{
		"nama": "Water + Oxygen",
		"bahan": [
			{"id": "item_0002", "nama": "Meteorite Ice", "kuantiti": 5, "ikon": LALUAN_AIS},
		],
		"keluaran": [
			{"id": ID_AIR, "nama": "Bottle of Water", "kuantiti": 1, "ikon": IKON_AIR, "scene_path": LALUAN_AIR},
			{"id": ID_OKSIGEN, "nama": "Oxygen Can", "kuantiti": 1, "ikon": IKON_OKSIGEN, "scene_path": LALUAN_OKSIGEN},
		],
	},
]
var resipi_semasa: int = 0
# Panel baiki di atas senarai resipi (kelihatan hanya bila relau rosak).
var _panel_repair = null
# Ikon dimuatkan sekali sahaja (laluan -> tekstur) dan diguna semula oleh menu,
# iklan terapung dan cincin kemajuan.
var _cache_ikon: Dictionary = {}
var kad_ui: Array[Dictionary] = []
# Kad yang bingkainya terakhir dicat semula (elak bina StyleBox setiap kemas kini).
var _bingkai_resipi: int = -1

@export_category("Sistem Kuasa")
@export var power_required: float = 200.0
var has_power: bool = false
var inverter_pembekal: Node2D = null

var player_dekat: bool = false
var masa_ketikan_terakhir: float = 0.0
const SELA_MASA_MINIMUM: float = 0.2

# UI tidak perlu dikemas kini setiap frame: teks Label/Button memaksa shaping
# fon + susun atur semula setiap kali. 20 Hz sudah cukup licin.
const SELA_UI: float = 0.05
var _ui_tick: float = 0.0

# Keadaan peleburan
var sedang_lebur: bool = false
# Pemain tekan Stop: unit yang sedang dilebur dihabiskan dahulu, kemudian batch
# berhenti. Kuasa terputus tidak guna flag ini (terus berhenti).
var _berhenti_selepas_unit: bool = false
var masa_berlalu: float = 0.0
var masa_hiasan: float = 0.0
var _cahaya: Sprite2D = null
var _skala_asal: Vector2 = Vector2(0.05, 0.05)

# Kelompok (batch) peleburan
var kuantiti_pilihan: int = 1
var _baki_batch: int = 0
var _jumlah_batch: int = 0
var _unit_selesai: int = 0

# Bekas iklan terapung "+1" (dalam dunia, jadi ia ikut kamera)
var _lapis_terapung: Node2D = null
var _iklan: HBoxContainer = null
var _iklan_ikon: TextureRect = null
var _iklan_teks: Label = null
var _iklan_masa: float = -1.0
var _iklan_x: float = 0.0
# Baris iklan yang menunggu giliran. Keluaran berbilang (air + oksigen)
# dipaparkan satu-satu, bukan sekali gus.
var _iklan_baris: Array[Dictionary] = []
# Cincin kemajuan di atas relau (ikon item + "1/7")
var _bulatan: Node2D = null
var _tekstur_steel: Texture2D = null

func _ready() -> void:
	add_to_group("Furniture")

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
	if butang_lebur: butang_lebur.pressed.connect(_on_butang_lebur_pressed)
	if butang_kurang: butang_kurang.pressed.connect(_on_kurang_pressed)
	if butang_tambah: butang_tambah.pressed.connect(_on_tambah_pressed)

	if sprite:
		_skala_asal = sprite.scale

	_sedia_kad()
	_pasang_ikon()
	_pasang_gaya_kad()
	_bina_cahaya()
	_bina_lapis_terapung()
	_bina_bulatan()
	_bina_panel_repair()
	_kemas_kini_ui()
	_kemas_kini_warna_visual()

	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_dikemaskini"):
		if not inv.inventory_dikemaskini.is_connected(_kemas_kini_ui):
			inv.inventory_dikemaskini.connect(_kemas_kini_ui)
	PowerGridRef.daftar_perabot(self)

# Kad resipi gelap + butang Craft yang menonjol (gaya senarai kad).
func _pasang_gaya_kad() -> void:
	# Panel menu ini lebih kecil: kurangkan padding bingkai supaya ruang lega.
	if menu_ui:
		var bingkai := (menu_ui.theme.get_stylebox("panel", "PanelContainer") as StyleBox).duplicate()
		if bingkai:
			bingkai.set_content_margin_all(4.0)
			menu_ui.add_theme_stylebox_override("panel", bingkai)

	_bingkai_resipi = -1
	_kemas_bingkai_kad()

	if butang_lebur:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.24, 0.64, 0.8, 1.0)
		normal.border_color = Color(0.72, 0.98, 1, 1)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(5)
		normal.set_content_margin_all(4.0)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.33, 0.78, 0.95, 1.0)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.16, 0.5, 0.65, 1.0)
		var disabled := normal.duplicate() as StyleBoxFlat
		disabled.bg_color = Color(0.09, 0.17, 0.22, 1.0)
		disabled.border_color = Color(0.28, 0.45, 0.53, 0.6)
		var fokus := normal.duplicate() as StyleBoxFlat
		fokus.draw_center = false
		fokus.bg_color = Color(0, 0, 0, 0)
		butang_lebur.add_theme_stylebox_override("normal", normal)
		butang_lebur.add_theme_stylebox_override("hover", hover)
		butang_lebur.add_theme_stylebox_override("pressed", pressed)
		butang_lebur.add_theme_stylebox_override("disabled", disabled)
		butang_lebur.add_theme_stylebox_override("focus", fokus)
		butang_lebur.add_theme_color_override("font_color", Color(0.02, 0.09, 0.13, 1))
		butang_lebur.add_theme_color_override("font_hover_color", Color(0.01, 0.05, 0.08, 1))
		butang_lebur.add_theme_color_override("font_pressed_color", Color(0.75, 0.95, 1, 1))
		butang_lebur.add_theme_color_override("font_disabled_color", Color(0.4, 0.52, 0.6, 1))

# Panel baiki: bahan repair + butang Repair di atas senarai resipi.
func _bina_panel_repair() -> void:
	if menu_ui == null:
		return
	var vbox := menu_ui.get_node_or_null("VBoxContainer")
	if vbox == null:
		return
	_panel_repair = PANEL_REPAIR.new()
	vbox.add_child(_panel_repair)
	vbox.move_child(_panel_repair, 1)
	_panel_repair.sediakan(self)
	_panel_repair.selesai_baiki.connect(_kemas_kini_ui)

# Cincin kemajuan kecil di atas relau, hanya nampak semasa melebur.
func _bina_bulatan() -> void:
	_bulatan = BulatanCraft.new()
	_bulatan.name = "BulatanCraft"
	_bulatan.position = Vector2(0, -34)
	_bulatan.tekstur = _tekstur_steel
	_bulatan.visible = false
	add_child(_bulatan)

# Ikon bahan/keluaran dimuatkan awal supaya menu nampak jelas (bukan teks kosong).
func _pasang_ikon() -> void:
	for resipi in senarai_resipi:
		for bahan in resipi["bahan"]:
			_muat_ikon(str(bahan["ikon"]))
		for produk in resipi["keluaran"]:
			_muat_ikon(str(produk["ikon"]))
	_tekstur_steel = _muat_ikon(IKON_STEEL)

func _muat_ikon(laluan: String) -> Texture2D:
	if _cache_ikon.has(laluan):
		return _cache_ikon[laluan]
	if not ResourceLoader.exists(laluan):
		return null
	var tekstur: Texture2D = load(laluan)
	_cache_ikon[laluan] = tekstur
	return tekstur

# Resipi yang sedang dipilih.
func _resipi() -> Dictionary:
	return senarai_resipi[clampi(resipi_semasa, 0, senarai_resipi.size() - 1)]

func _bahan_resipi() -> Array:
	return _resipi()["bahan"]

func _keluaran_resipi() -> Array:
	return _resipi()["keluaran"]

func _nama_keluaran() -> String:
	return str(_keluaran_resipi()[0]["nama"])

# Tukar resipi hanya bila relau menganggur; perubahan ini juga mengemas kini
# ikon bahan/keluaran pada menu.
func _pilih_resipi(indeks: int) -> void:
	if sedang_lebur:
		return
	indeks = clampi(indeks, 0, senarai_resipi.size() - 1)
	if indeks == resipi_semasa:
		return
	resipi_semasa = indeks
	kuantiti_pilihan = 1
	_reset_paparan_batch()
	_kemas_kini_ui()

# Cari nod dalam setiap kad resipi sekali sahaja (kad Steel dan kad Water +
# Oxygen dibina dalam scene, bukan dicipta semula setiap kemas kini).
func _sedia_kad() -> void:
	kad_ui = [
		_rujuk_kad("KadSteel"),
		_rujuk_kad("KadAir"),
	]
	for i in kad_ui.size():
		var panel: Control = kad_ui[i]["panel"]
		if panel:
			panel.gui_input.connect(_on_kad_input.bind(i))

func _rujuk_kad(nama_kad: String) -> Dictionary:
	var akar: String = "CanvasLayer/Pusat/MenuUI/VBoxContainer/SenaraiResipi/%s" % nama_kad
	return {
		"panel": get_node_or_null(akar),
		"nama": get_node_or_null(akar + "/HBox/Maklumat/NamaResipi"),
		"slot_bahan": [
			get_node_or_null(akar + "/HBox/Maklumat/Bahan/Bahan1"),
			get_node_or_null(akar + "/HBox/Maklumat/Bahan/Bahan2"),
		],
		"ikon_bahan": [
			get_node_or_null(akar + "/HBox/Maklumat/Bahan/Bahan1/IkonBahan1"),
			get_node_or_null(akar + "/HBox/Maklumat/Bahan/Bahan2/IkonBahan2"),
		],
		"label_bahan": [
			get_node_or_null(akar + "/HBox/Maklumat/Bahan/Bahan1/BilBahan1"),
			get_node_or_null(akar + "/HBox/Maklumat/Bahan/Bahan2/BilBahan2"),
		],
		"slot_keluaran": [
			get_node_or_null(akar + "/HBox/Kiri/IkonBekas/Slot1"),
			get_node_or_null(akar + "/HBox/Kiri/IkonBekas/Slot2"),
		],
		"ikon_keluaran": [
			get_node_or_null(akar + "/HBox/Kiri/IkonBekas/Slot1/IkonKeluaran"),
			get_node_or_null(akar + "/HBox/Kiri/IkonBekas/Slot2/IkonKeluaran2"),
		],
		"label_keluaran": [
			get_node_or_null(akar + "/HBox/Kiri/IkonBekas/Slot1/BilanganDimiliki"),
			get_node_or_null(akar + "/HBox/Kiri/IkonBekas/Slot2/BilanganDimiliki2"),
		],
		"kemajuan": get_node_or_null(akar + "/HBox/Kemajuan"),
	}

func _on_kad_input(event: InputEvent, indeks: int) -> void:
	var klik := event as InputEventMouseButton
	if klik == null or not klik.pressed or klik.button_index != MOUSE_BUTTON_LEFT:
		return
	_pilih_resipi(indeks)

# Gaya kad resipi: kad aktif ada bingkai cyan terang, kad lain malap.
func _gaya_kad(dipilih: bool) -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = Color(0.031, 0.082, 0.13, 0.95) if dipilih else Color(0.024, 0.062, 0.094, 0.9)
	gaya.border_color = Color(0.45, 0.92, 1, 0.95) if dipilih else Color(0.2, 0.4, 0.5, 0.55)
	gaya.set_border_width_all(1)
	gaya.set_corner_radius_all(3)
	gaya.set_content_margin_all(3.0)
	return gaya

func _kemas_bingkai_kad() -> void:
	if _bingkai_resipi == resipi_semasa:
		return
	_bingkai_resipi = resipi_semasa
	for i in kad_ui.size():
		var panel: PanelContainer = kad_ui[i]["panel"]
		if panel:
			panel.add_theme_stylebox_override("panel", _gaya_kad(i == resipi_semasa))

# Cahaya api di muncung relau (dibina dalam kod, tiada aset tambahan).
func _bina_cahaya() -> void:
	_cahaya = Sprite2D.new()
	_cahaya.name = "CahayaLebur"
	var gradien := Gradient.new()
	gradien.set_color(0, Color(1.0, 0.62, 0.22, 0.85))
	gradien.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	var tekstur := GradientTexture2D.new()
	tekstur.gradient = gradien
	tekstur.fill = GradientTexture2D.FILL_RADIAL
	tekstur.fill_from = Vector2(0.5, 0.5)
	tekstur.fill_to = Vector2(1.0, 0.5)
	tekstur.width = 64
	tekstur.height = 64
	_cahaya.texture = tekstur
	_cahaya.position = Vector2(0, -5)
	_cahaya.scale = Vector2(0.75, 0.75)
	_cahaya.visible = false
	add_child(_cahaya)
	move_child(_cahaya, 0)

# Bekas iklan terapung "+1 Steel". Ia anak Node2D dalam dunia supaya iklan
# kekal atas relau walaupun kamera/pemain bergerak.
func _bina_lapis_terapung() -> void:
	_lapis_terapung = Node2D.new()
	_lapis_terapung.name = "HudSmelterTerapung"
	_lapis_terapung.z_index = 100
	add_child(_lapis_terapung)

	# Iklan "+1" dibina SEKALI dan diguna semula. Membina Control baru
	# (HBox + ikon + Label) setiap unit menyebabkan lag singkat setiap kali
	# satu Steel siap, kerana setiap Control baru perlu layout + shaping teks.
	_iklan = HBoxContainer.new()
	_iklan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iklan.add_theme_constant_override("separation", 1)
	_iklan.visible = false
	_lapis_terapung.add_child(_iklan)

	_iklan_ikon = TextureRect.new()
	_iklan_ikon.texture = _tekstur_steel
	_iklan_ikon.custom_minimum_size = Vector2(7, 7)
	_iklan_ikon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_iklan_ikon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_iklan_ikon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_iklan.add_child(_iklan_ikon)

	_iklan_teks = Label.new()
	_iklan_teks.text = "+1"
	_iklan_teks.add_theme_font_size_override("font_size", 7)
	_iklan_teks.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))
	_iklan_teks.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.09, 0.95))
	_iklan_teks.add_theme_constant_override("outline_size", 3)
	_iklan.add_child(_iklan_teks)

# ==========================================================
# CRAFT
# ==========================================================
func _bilangan_dalam_beg(id_item: String) -> int:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return 0
	return inv.bilangan_item(id_item)

func _bahan_cukup(banyak: int = 1) -> bool:
	for bahan in _bahan_resipi():
		if _bilangan_dalam_beg(bahan["id"]) < int(bahan["kuantiti"]) * banyak:
			return false
	return true

# Berapa unit boleh dilebur dengan bahan dalam beg sekarang.
func _maks_unit() -> int:
	var maks: int = 99
	for bahan in _bahan_resipi():
		var perlu: int = maxi(1, int(bahan["kuantiti"]))
		maks = mini(maks, int(floor(float(_bilangan_dalam_beg(bahan["id"])) / float(perlu))))
	return maxi(0, maks)

func _on_kurang_pressed() -> void:
	if sedang_lebur:
		return
	kuantiti_pilihan = maxi(1, kuantiti_pilihan - 1)
	_reset_paparan_batch()
	_kemas_kini_ui()

func _on_tambah_pressed() -> void:
	if sedang_lebur:
		return
	kuantiti_pilihan = mini(maxi(1, _maks_unit()), kuantiti_pilihan + 1)
	_reset_paparan_batch()
	_kemas_kini_ui()

# ==========================================================
# SIMPAN / MUAT STATE LEBUR
# ==========================================================
# Bahan sudah ditolak dari beg semasa batch bermula, jadi batch yang belum
# siap perlu disimpan; tanpa ini steel yang masih tertunggak hilang selepas load.
func get_data_simpanan_tambahan() -> Dictionary:
	if not sedang_lebur or _baki_batch <= 0:
		return {}
	return {
		"smelter_resipi": resipi_semasa,
		"smelter_baki_batch": _baki_batch,
		"smelter_jumlah_batch": _jumlah_batch,
		"smelter_unit_selesai": _unit_selesai,
		"smelter_masa_berlalu": masa_berlalu,
	}

func pakai_data_simpanan_tambahan(data: Dictionary) -> void:
	var baki := int(data.get("smelter_baki_batch", 0))
	if baki <= 0:
		return
	# Resipi mesti dipulihkan dahulu: pengawal unit guna bahan/keluaran resipi ini.
	resipi_semasa = clampi(int(data.get("smelter_resipi", 0)), 0, senarai_resipi.size() - 1)
	_baki_batch = baki
	_jumlah_batch = maxi(baki, int(data.get("smelter_jumlah_batch", baki)))
	_unit_selesai = clampi(int(data.get("smelter_unit_selesai", 0)), 0, _jumlah_batch - baki)
	_mula_unit()
	# Sambung dari kemajuan tersimpan (tidak melebihi satu unit penuh).
	masa_berlalu = clampf(float(data.get("smelter_masa_berlalu", 0.0)), 0.0, MASA_LEBUR - 0.01)
	_kemas_progres(clampf(masa_berlalu / MASA_LEBUR, 0.0, 1.0))

# Pilihan kuantiti berubah: paparan kemajuan batch bermula semula.
func _reset_paparan_batch() -> void:
	if sedang_lebur:
		return
	_jumlah_batch = 0
	_unit_selesai = 0
	_kemas_progres()

func _on_butang_lebur_pressed() -> void:
	if sedang_lebur:
		# Butang bertukar jadi Stop semasa batch berjalan: unit yang sedang
		# dilebur dibiarkan siap dulu, batch berhenti selepas itu.
		if _berhenti_selepas_unit:
			return
		_berhenti_selepas_unit = true
		_kemas_kini_ui()
		return
	if REPAIR.rosak(self):
		return
	if not has_power:
		return
	var maks: int = _maks_unit()
	if maks <= 0:
		return
	kuantiti_pilihan = clampi(kuantiti_pilihan, 1, maks)
	# Simpan nilai dulu: tolak_item memancar isyarat inventori yang boleh
	# mengubah kuantiti_pilihan.
	var banyak: int = kuantiti_pilihan
	# Hanya unit pertama dibayar sekarang; unit seterusnya dibayar satu demi
	# satu selepas setiap unit siap.
	if not _tolak_bahan_satu_unit():
		return
	_jumlah_batch = banyak
	_baki_batch = banyak
	_unit_selesai = 0
	_mula_unit()

# Tolak bahan untuk SATU unit sahaja. Dipanggil bila batch bermula dan setiap
# kali satu unit siap, supaya bahan untuk 10 unit tidak ditolak sekaligus.
func _tolak_bahan_satu_unit() -> bool:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return false
	# Semak semua bahan dahulu supaya tiada tolakan separa.
	for bahan in _bahan_resipi():
		if inv.bilangan_item(bahan["id"]) < int(bahan["kuantiti"]):
			return false
	for bahan in _bahan_resipi():
		inv.tolak_item(bahan["id"], int(bahan["kuantiti"]))
	return true

func _mula_unit() -> void:
	sedang_lebur = true
	masa_berlalu = 0.0
	masa_hiasan = 0.0
	_ui_tick = SELA_UI
	if _cahaya:
		_cahaya.visible = true
	_kosongkan_bar_kad()
	_kemas_kini_ui()

# Animasi relau + kemajuan peleburan.
func _process(delta: float) -> void:
	_kemas_kini_iklan(delta)
	if not sedang_lebur:
		return
	masa_berlalu += delta
	masa_hiasan += delta
	var nisbah: float = clamp(masa_berlalu / MASA_LEBUR, 0.0, 1.0)
	_ui_tick += delta
	if _ui_tick >= SELA_UI:
		_ui_tick = 0.0
		_kemas_progres(nisbah)

	var denyut: float = (sin(masa_hiasan * 7.5) + 1.0) * 0.5
	if sprite:
		sprite.modulate = Color(1.0, 0.78 + 0.22 * denyut, 0.62 + 0.38 * denyut)
		sprite.scale = _skala_asal * (1.0 + 0.05 * denyut)
	if _cahaya:
		_cahaya.modulate.a = 0.55 + 0.45 * denyut
		_cahaya.scale = Vector2.ONE * (0.62 + 0.18 * denyut)

	if nisbah >= 1.0:
		_selesai_unit()

# Satu unit siap: masukkan semua keluaran resipi, iklan terapung, sambung unit
# seterusnya. Resipi air menghasilkan dua item serentak.
func _selesai_unit() -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		# senyap=true: jangan pancar isyarat inventori setiap unit (itu membina
		# semula UI semua perabot). Isyarat dipancar sekali bila batch habis.
		for produk in _keluaran_resipi():
			var ikon_produk: Texture2D = _muat_ikon(str(produk["ikon"]))
			for _i in int(produk.get("kuantiti", 1)):
				inv.tambah_item({
					"id": str(produk["id"]),
					"nama": str(produk["nama"]),
					"ikon": ikon_produk,
					"scene_path": str(produk["scene_path"]),
				}, true)
	_apung_hasil()
	_baki_batch -= 1
	_unit_selesai += 1
	_kosongkan_bar_kad()

	if _baki_batch > 0:
		# Stop diminta pemain: unit ini tetap dikira, batch tamat di sini.
		if _berhenti_selepas_unit:
			_baki_batch = 0
		# Bayar unit seterusnya sekarang (bukan di awal batch). Kalau bahan
		# tidak cukup lagi, batch berhenti di sini.
		elif _tolak_bahan_satu_unit():
			masa_berlalu = 0.0
			masa_hiasan = 0.0
			print("Smelter: 1 %s dihasilkan (%d/%d)" % [_nama_keluaran(), _unit_selesai, _jumlah_batch])
			_kemas_kini_ui()
			return
		_baki_batch = 0

	sedang_lebur = false
	masa_berlalu = 0.0
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = _skala_asal
	if _cahaya:
		_cahaya.visible = false
	if _berhenti_selepas_unit:
		_berhenti_selepas_unit = false
	print("Smelter: %d %s dihasilkan" % [_unit_selesai, _nama_keluaran()])
	# Batch habis: kemajuan terus kosong (0/1) dan Amount kembali ke 1.
	_jumlah_batch = 0
	_unit_selesai = 0
	kuantiti_pilihan = 1
	_kosongkan_bar_kad()
	_kemas_kini_ui()
	if inv:
		inv.kemas_kini_selepas_batch()

# Iklan terapung ikon keluaran + "+1" di atas relau, naik lalu pudar.
# Guna semula node yang sudah ada: tiada Control baru setiap unit.
# Setiap produk dalam resipi masuk baris giliran sendiri, jadi air + oksigen
# muncul bergilir ("+1 Bottle of Water", kemudian "+1 Oxygen Can").
func _apung_hasil() -> void:
	if _iklan == null:
		return
	for produk in _keluaran_resipi():
		_iklan_baris.append({
			"ikon": _muat_ikon(str(produk["ikon"])),
			"teks": "+%d %s" % [int(produk.get("kuantiti", 1)), str(produk["nama"])],
		})
	# Iklan yang masih naik biarkan habis dulu; baris baru menunggu giliran.
	if _iklan_masa >= 0.0:
		return
	_seterusnya_iklan()

# Papar baris iklan seterusnya (satu ikon + satu teks), atau sembunyikan iklan
# bila giliran habis.
func _seterusnya_iklan() -> void:
	if _iklan == null:
		return
	if _iklan_baris.is_empty():
		_iklan_masa = -1.0
		_iklan.visible = false
		return
	var baris: Dictionary = _iklan_baris.pop_front()
	var ikon: Texture2D = baris["ikon"]
	_iklan_ikon.texture = ikon
	_iklan_ikon.visible = ikon != null
	# Label hanya diukur semula bila teksnya berubah; teks sama tidak perlu
	# susun atur semula setiap unit.
	var teks: String = str(baris["teks"])
	if _iklan_teks.text != teks:
		_iklan_teks.text = teks
		_iklan.reset_size()
	_iklan_x = -_iklan.size.x * 0.5 + randf_range(-2.0, 2.0)
	_iklan_masa = 0.0
	_iklan.modulate.a = 1.0
	_iklan.position = Vector2(_iklan_x, IKLAN_Y_ASAL)
	_iklan.visible = true

# Animasi iklan dikira sendiri tiap frame (tanpa Tween): tiada Tween baru
# setiap unit, dan iklan terus naik sehingga pupus supaya tidak nampak
# tersekat pada penghujung pudar.
func _kemas_kini_iklan(delta: float) -> void:
	if _iklan_masa < 0.0:
		return
	_iklan_masa += delta
	var t: float = _iklan_masa / MASA_IKLAN
	if t >= 1.0:
		# Ada baris menunggu: terus papar yang seterusnya di kedudukan asal.
		if not _iklan_baris.is_empty():
			_seterusnya_iklan()
			return
		_iklan_masa = -1.0
		_iklan.modulate.a = 0.0
		_iklan.visible = false
		return
	_iklan.position = Vector2(_iklan_x, IKLAN_Y_ASAL - JARAK_IKLAN * t)
	var p: float = clampf((t - IKLAN_MULA_PUDAR) / (1.0 - IKLAN_MULA_PUDAR), 0.0, 1.0)
	_iklan.modulate.a = 1.0 - (p * p * (3.0 - 2.0 * p))

# Kemas kini menu: ikon + bilangan bahan, keluaran, status, pilihan kuantiti, butang.
func _kemas_kini_ui() -> void:
	if is_instance_valid(_panel_repair):
		_panel_repair.segarkan()
	var maks: int = _maks_unit()
	if not sedang_lebur:
		kuantiti_pilihan = clampi(kuantiti_pilihan, 1, maxi(1, maks))
	# Semasa batch berjalan, papar bahan yang masih perlu dibayar untuk baki
	# batch. Unit yang sedang dilebur sudah dibayar, jadi tolak satu unit.
	var unit_paparan: int = maxi(0, _baki_batch - 1) if sedang_lebur else kuantiti_pilihan

	# Semua kad dikemas kini; kad bukan terpilih papar keperluan satu unit.
	for i in kad_ui.size():
		_kemas_kini_kad(i, unit_paparan if i == resipi_semasa else 1)
	_kemas_bingkai_kad()
	if _bulatan:
		# Cincin di atas relau ikut ikon keluaran resipi yang dipilih.
		_bulatan.tekstur = _muat_ikon(str(_keluaran_resipi()[0]["ikon"]))

	if label_kuantiti:
		# Sama asas dengan paparan bahan: semasa lebur ia bilangan unit yang
		# tinggal, supaya kuantiti × resipi sepadan dengan nombor keperluan.
		label_kuantiti.text = str(unit_paparan)
	if label_maks:
		label_maks.text = "max %d" % maks
	if butang_kurang:
		butang_kurang.disabled = sedang_lebur or kuantiti_pilihan <= 1
	if butang_tambah:
		butang_tambah.disabled = sedang_lebur or kuantiti_pilihan >= maks

	if label_status:
		if REPAIR.rosak(self):
			label_status.text = "Damaged"
			label_status.add_theme_color_override("font_color", WARNA_KURANG)
		elif not has_power:
			label_status.text = "No power"
			label_status.add_theme_color_override("font_color", WARNA_KURANG)
		elif sedang_lebur:
			label_status.text = "Smelting %d/%d" % [_unit_selesai + 1, maxi(1, _jumlah_batch)]
			label_status.add_theme_color_override("font_color", WARNA_SEDANG)
		elif _bahan_cukup():
			label_status.text = "Ready"
			label_status.add_theme_color_override("font_color", WARNA_CUKUP)
		else:
			label_status.text = "Need materials"
			label_status.add_theme_color_override("font_color", WARNA_KURANG)

	if butang_lebur:
		if sedang_lebur:
			butang_lebur.text = "Stopping" if _berhenti_selepas_unit else "Stop"
			butang_lebur.disabled = _berhenti_selepas_unit
		else:
			butang_lebur.text = "Craft"
			butang_lebur.disabled = (not has_power) or (not _bahan_cukup()) or REPAIR.rosak(self)

	_kemas_progres()

# Cincin kemajuan di kanan kad: penuh untuk SATU unit, kemudian mula semula.
# Cincin hanya wujud secara visual semasa relau melebur; kad menganggur tiada
# cincin (teks kosong = lukis tiada apa-apa).
func _kemas_progres(nisbah: float = 0.0) -> void:
	var jumlah: int = maxi(1, _jumlah_batch if _jumlah_batch > 0 else kuantiti_pilihan)
	var teks: String = ""
	var nilai: float = 0.0
	if sedang_lebur:
		teks = "%d/%d" % [mini(_unit_selesai + 1, jumlah), jumlah]
		nilai = clampf(nisbah, 0.0, 1.0)

	# Hanya kad aktif tunjuk cincin, dan hanya semasa melebur.
	for i in kad_ui.size():
		var cincin = kad_ui[i]["kemajuan"]
		if cincin:
			if i == resipi_semasa:
				cincin.set_kemajuan(nilai, teks)
			else:
				cincin.set_kemajuan(0.0, "")
	if _bulatan:
		_bulatan.visible = sedang_lebur
		var teks_bulatan: String = teks if sedang_lebur else "0/%d" % kuantiti_pilihan
		_bulatan.set_kemajuan(nilai, teks_bulatan)

# Kosongkan cincin kemajuan semua kad (mula/henti unit).
func _kosongkan_bar_kad() -> void:
	for kad in kad_ui:
		var cincin = kad["kemajuan"]
		if cincin:
			cincin.set_kemajuan(0.0, "")

func _kemas_kini_kad(indeks: int, unit_paparan: int) -> void:
	if indeks < 0 or indeks >= kad_ui.size() or indeks >= senarai_resipi.size():
		return
	var kad: Dictionary = kad_ui[indeks]
	var resipi: Dictionary = senarai_resipi[indeks]
	var bahan: Array = resipi["bahan"]
	var keluaran: Array = resipi["keluaran"]

	for i in kad["slot_bahan"].size():
		var wadah_bahan: Control = kad["slot_bahan"][i]
		if wadah_bahan == null:
			continue
		if i >= bahan.size():
			wadah_bahan.visible = false
			continue
		wadah_bahan.visible = true
		var data_bahan: Dictionary = bahan[i]
		var ikon: Texture2D = _muat_ikon(str(data_bahan["ikon"]))
		if ikon and kad["ikon_bahan"][i]:
			kad["ikon_bahan"][i].texture = ikon
		_tulis_bilangan(
			kad["label_bahan"][i],
			_bilangan_dalam_beg(str(data_bahan["id"])),
			int(data_bahan["kuantiti"]) * unit_paparan,
			indeks == resipi_semasa
		)

	for i in kad["slot_keluaran"].size():
		var wadah_keluar: Control = kad["slot_keluaran"][i]
		if wadah_keluar == null:
			continue
		if i >= keluaran.size():
			wadah_keluar.visible = false
			continue
		wadah_keluar.visible = true
		var data_keluaran: Dictionary = keluaran[i]
		var ikon_keluar: Texture2D = _muat_ikon(str(data_keluaran["ikon"]))
		if ikon_keluar and kad["ikon_keluaran"][i]:
			kad["ikon_keluaran"][i].texture = ikon_keluar
		if kad["label_keluaran"][i]:
			kad["label_keluaran"][i].text = str(_bilangan_dalam_beg(str(data_keluaran["id"])))

	if kad["nama"]:
		kad["nama"].text = str(resipi["nama"])

func _tulis_bilangan(label: Label, ada: int, perlu: int, aktif: bool = true) -> void:
	if label == null:
		return
	# Format "perlu/dimiliki", cth. "5/352": keperluan unit yang dipilih dan
	# jumlah bahan yang ada dalam beg.
	label.text = "%d/%d" % [perlu, ada]
	if aktif and sedang_lebur:
		label.add_theme_color_override("font_color", WARNA_SEDANG)
	elif ada >= perlu:
		label.add_theme_color_override("font_color", WARNA_CUKUP)
	else:
		label.add_theme_color_override("font_color", WARNA_KURANG)

# ==========================================================
# SISTEM KUASA
# ==========================================================
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
	if not has_power and sedang_lebur:
		_henti_lebur_kerana_tiada_kuasa()
	_kemas_kini_warna_visual()
	_kemas_kini_ui()

func _henti_lebur_kerana_tiada_kuasa() -> void:
	_henti_batch()

# Hentikan batch semasa (kuasa terputus atau pemain tekan Stop). Bahan untuk
# unit yang sedang dilebur sudah dibayar dan tidak dikembalikan, sama seperti
# kehilangan kuasa.
func _henti_batch() -> void:
	sedang_lebur = false
	_berhenti_selepas_unit = false
	masa_berlalu = 0.0
	_baki_batch = 0
	_jumlah_batch = 0
	_unit_selesai = 0
	kuantiti_pilihan = 1
	_kosongkan_bar_kad()
	if _bulatan:
		_bulatan.visible = false
		_bulatan.set_kemajuan(0.0, "0/1")
	if sprite:
		sprite.scale = _skala_asal
	if _cahaya:
		_cahaya.visible = false
	_kemas_kini_warna_visual()
	_kemas_kini_ui()

func _kemas_kini_warna_visual() -> void:
	if not sprite:
		return
	if sedang_lebur:
		return # animasi lebur kawal warna
	if player_dekat:
		sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)
	elif has_power:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		sprite.modulate = Color(0.4, 0.4, 0.4, 1.0)

# ==========================================================
# PENDERIA & INPUT
# ==========================================================
func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_dekat = true
		_kemas_kini_warna_visual()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_dekat = false
		_kemas_kini_warna_visual()
		if menu_ui:
			menu_ui.hide()

func _input(event: InputEvent) -> void:
	var klik := event as InputEventMouseButton
	if klik == null or not klik.pressed or klik.button_index != MOUSE_BUTTON_LEFT:
		return
	if not player_dekat or area_penderia == null:
		return
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

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var ada_sentuhan = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if not ada_sentuhan or not player_dekat:
		return
	var masa_sekarang = Time.get_ticks_msec() / 1000.0
	if masa_sekarang - masa_ketikan_terakhir < SELA_MASA_MINIMUM:
		return
	masa_ketikan_terakhir = masa_sekarang
	if menu_ui:
		menu_ui.visible = not menu_ui.visible
		if menu_ui.visible:
			Sfx.mainkan("menu_relau", -7.0)
			_kemas_kini_ui()
	get_viewport().set_input_as_handled()

func _on_butang_tutup_pressed() -> void:
	if menu_ui:
		menu_ui.hide()

# Kos bina ikut Smelter_Preview.tscn: 6 Basic Iron Ore + 2 Raw Silica.
func kos_bina() -> Array:
	return [
		{"id": "item_0001", "nama": "Basic Iron Ore", "ikon": load("res://scene/Item/0001BasicIronOre/Image_959.png"), "scene_path": "res://scene/Item/0001BasicIronOre/0001BasicIronOre.tscn", "diperlukan": 6},
		{"id": "item_0003", "nama": "Raw Silica", "ikon": load("res://scene/Item/0003RawSilica/Image_495.png"), "scene_path": "res://scene/Item/0003RawSilica/0003RawSilica.tscn", "diperlukan": 2},
	]

func _on_butang_demolish_pressed() -> void:
	# Relau yang rosak dirobohkan tanpa pulangan bahan langsung.
	if not REPAIR.rosak(self):
		BahanBinaan.pulangkan(self)
	sedang_lebur = false
	player_dekat = false
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = _skala_asal
	PowerGridRef.nyahdaftar_perabot(self)
	# Bunyi roboh siap yang sama macam nyahbina tile: perabot runtuh berkecai.
	Sfx.mainkan_di("roboh_siap", global_position, -3.0)
	queue_free()

func _exit_tree() -> void:
	PowerGridRef.nyahdaftar_perabot(self)
