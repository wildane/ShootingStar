extends StaticBody2D

## Relau pelebur: 2 Basic Iron Ore + 1 Meteorite Ice -> 1 Steel.
## Semasa melebur, sprite berdenyut warna relau dan ada cahaya api di mulut.
## Menu ada ikon bahan, pilihan kuantiti (batch) dan iklan terapung "+1".

@onready var save_component = $SaveComponent
@onready var sprite = get_node_or_null("Sprite2D")
@onready var area_penderia = get_node_or_null("Area2D")
const TemaPerabot := preload("res://scene/ui/TemaPerabot.gd")
const BulatanCraft := preload("res://scene/level_3/build_system/smelter/bulatan_craft.gd")

@onready var menu_ui = get_node_or_null("CanvasLayer/Pusat/MenuUI")
@onready var butang_tutup = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/HBoxContainer/ButtonTutup")
@onready var butang_demolish = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/HBoxContainer/ButtonDemolish")
@onready var label_status = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Header/LabelStatus")
@onready var bar_progres = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Kad/HBox/Kiri/Progress")
@onready var label_progress = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Kad/HBox/Kiri/LabelProgress")
@onready var butang_lebur = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Kad/HBox/ButangCraft")
@onready var kad = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Kad")
@onready var label_bil_besi = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Kad/HBox/Maklumat/Bahan/Besi/BilBesi")
@onready var label_bil_ais = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Kad/HBox/Maklumat/Bahan/Ais/BilAis")
@onready var label_bil_keluaran = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Kad/HBox/Kiri/IkonBekas/BilanganDimiliki")
@onready var label_kuantiti = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/BarisKuantiti/LabelKuantiti")
@onready var label_maks = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/BarisKuantiti/LabelMaks")
@onready var butang_kurang = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/BarisKuantiti/ButangKurang")
@onready var butang_tambah = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/BarisKuantiti/ButangTambah")
@onready var ikon_besi = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Kad/HBox/Maklumat/Bahan/Besi/IkonBesi")
@onready var ikon_ais = get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/Kad/HBox/Maklumat/Bahan/Ais/IkonAis")

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
const LALUAN_BESI := "res://scene/Item/0001BasicIronOre/Image_959.png"
const LALUAN_AIS := "res://scene/Item/0002MeteoriteIce/Image_393.png"

const WARNA_CUKUP := Color(0.5, 0.95, 0.62, 1.0)
const WARNA_KURANG := Color(1.0, 0.44, 0.44, 1.0)
const WARNA_SEDANG := Color(0.72, 0.86, 0.95, 1.0)

# Resipi peleburan steel.
@export var resipi: Array[Dictionary] = [
	{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 2, "ikon": LALUAN_BESI},
	{"id": "item_0002", "nama": "Meteorite Ice", "kuantiti": 1, "ikon": LALUAN_AIS},
]

var player_dekat: bool = false
var masa_ketikan_terakhir: float = 0.0
const SELA_MASA_MINIMUM: float = 0.2

# UI tidak perlu dikemas kini setiap frame: teks Label/Button memaksa shaping
# fon + susun atur semula setiap kali. 20 Hz sudah cukup licin.
const SELA_UI: float = 0.05
var _ui_tick: float = 0.0

# Keadaan peleburan
var sedang_lebur: bool = false
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

	_pasang_ikon()
	_pasang_gaya_kad()
	_bina_cahaya()
	_bina_lapis_terapung()
	_bina_bulatan()
	_kemas_kini_ui()

	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_dikemaskini"):
		if not inv.inventory_dikemaskini.is_connected(_kemas_kini_ui):
			inv.inventory_dikemaskini.connect(_kemas_kini_ui)

# Kad resipi gelap + butang Craft yang menonjol (gaya senarai kad).
func _pasang_gaya_kad() -> void:
	# Panel menu ini lebih kecil: kurangkan padding bingkai supaya ruang lega.
	if menu_ui:
		var bingkai := (menu_ui.theme.get_stylebox("panel", "PanelContainer") as StyleBox).duplicate()
		if bingkai:
			bingkai.set_content_margin_all(4.0)
			menu_ui.add_theme_stylebox_override("panel", bingkai)

	if kad:
		var gaya := StyleBoxFlat.new()
		gaya.bg_color = Color(0.031, 0.082, 0.13, 0.95)
		gaya.border_color = Color(0.28, 0.55, 0.68, 0.7)
		gaya.set_border_width_all(1)
		gaya.set_corner_radius_all(3)
		gaya.set_content_margin_all(3.0)
		kad.add_theme_stylebox_override("panel", gaya)

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

# Cincin kemajuan kecil di atas relau, hanya nampak semasa melebur.
func _bina_bulatan() -> void:
	_bulatan = BulatanCraft.new()
	_bulatan.name = "BulatanCraft"
	_bulatan.position = Vector2(0, -34)
	_bulatan.tekstur = _tekstur_steel
	_bulatan.visible = false
	add_child(_bulatan)

# Ikon bahan dipasang dari fail PNG supaya menu nampak jelas (bukan teks kosong).
func _pasang_ikon() -> void:
	if ikon_besi and ResourceLoader.exists(LALUAN_BESI):
		ikon_besi.texture = load(LALUAN_BESI)
	if ikon_ais and ResourceLoader.exists(LALUAN_AIS):
		ikon_ais.texture = load(LALUAN_AIS)
	if ResourceLoader.exists(IKON_STEEL):
		_tekstur_steel = load(IKON_STEEL)

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

func get_save_data() -> Dictionary:
	var data_perabot: Dictionary = {}
	if save_component and save_component.has_method("get_data"):
		data_perabot = save_component.get_data()
	data_perabot["scene_path"] = scene_file_path
	data_perabot["pos_x"] = global_position.x
	data_perabot["pos_y"] = global_position.y
	return data_perabot

# ==========================================================
# CRAFT STEEL
# ==========================================================
func _bilangan_dalam_beg(id_item: String) -> int:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return 0
	return inv.bilangan_item(id_item)

func _bahan_cukup(banyak: int = 1) -> bool:
	for bahan in resipi:
		if _bilangan_dalam_beg(bahan["id"]) < int(bahan["kuantiti"]) * banyak:
			return false
	return true

# Berapa unit steel boleh dilebur dengan bahan dalam beg sekarang.
func _maks_unit() -> int:
	var maks: int = 99
	for bahan in resipi:
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

# Pilihan kuantiti berubah: paparan kemajuan batch bermula semula.
func _reset_paparan_batch() -> void:
	if sedang_lebur:
		return
	_jumlah_batch = 0
	_unit_selesai = 0
	_kemas_progres()

func _on_butang_lebur_pressed() -> void:
	if sedang_lebur:
		return
	var maks: int = _maks_unit()
	if maks <= 0:
		_tulis_info("Not enough materials for Steel")
		return
	kuantiti_pilihan = clampi(kuantiti_pilihan, 1, maks)
	# Simpan nilai dulu: tolak_item memancar isyarat inventori yang boleh
	# mengubah kuantiti_pilihan di tengah gelung.
	var banyak: int = kuantiti_pilihan
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return
	for bahan in resipi:
		inv.tolak_item(bahan["id"], int(bahan["kuantiti"]) * banyak)
	_jumlah_batch = banyak
	_baki_batch = banyak
	_unit_selesai = 0
	_mula_unit()

func _mula_unit() -> void:
	sedang_lebur = true
	masa_berlalu = 0.0
	masa_hiasan = 0.0
	_ui_tick = SELA_UI
	if _cahaya:
		_cahaya.visible = true
	if bar_progres:
		bar_progres.value = 0.0
	_kemas_kini_ui()
	if _jumlah_batch > 1:
		_tulis_info("Smelting Steel %d/%d..." % [_unit_selesai + 1, _jumlah_batch])
	else:
		_tulis_info("Smelting Steel...")

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
		if butang_lebur:
			butang_lebur.text = "%0.1fs" % max(0.0, MASA_LEBUR - masa_berlalu)

	var denyut: float = (sin(masa_hiasan * 7.5) + 1.0) * 0.5
	if sprite:
		sprite.modulate = Color(1.0, 0.78 + 0.22 * denyut, 0.62 + 0.38 * denyut)
		sprite.scale = _skala_asal * (1.0 + 0.05 * denyut)
	if _cahaya:
		_cahaya.modulate.a = 0.55 + 0.45 * denyut
		_cahaya.scale = Vector2.ONE * (0.62 + 0.18 * denyut)

	if nisbah >= 1.0:
		_selesai_unit()

# Satu unit steel siap: tambah item, iklan terapung, sambung unit seterusnya.
func _selesai_unit() -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		# senyap=true: jangan pancar isyarat inventori setiap unit (itu membina
		# semula UI semua perabot). Isyarat dipancar sekali bila batch habis.
		inv.tambah_item({
			"id": ID_STEEL,
			"nama": "Steel",
			"ikon": _tekstur_steel if _tekstur_steel else load(IKON_STEEL),
			"scene_path": LALUAN_STEEL,
		}, true)
	_apung_steel(1)
	_baki_batch -= 1
	_unit_selesai += 1
	if bar_progres:
		bar_progres.value = 0.0

	if _baki_batch > 0:
		masa_berlalu = 0.0
		masa_hiasan = 0.0
		print("Smelter: 1 Steel dihasilkan (%d/%d)" % [_unit_selesai, _jumlah_batch])
		_kemas_kini_ui()
		return

	sedang_lebur = false
	masa_berlalu = 0.0
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = _skala_asal
	if _cahaya:
		_cahaya.visible = false
	if _jumlah_batch > 1:
		_tulis_info("Steel produced! +%d" % _jumlah_batch)
	else:
		_tulis_info("Steel produced! +1")
	print("Smelter: %d Steel dihasilkan" % _jumlah_batch)
	# Batch habis: kemajuan terus kosong (0/1) dan Amount kembali ke 1.
	_jumlah_batch = 0
	_unit_selesai = 0
	kuantiti_pilihan = 1
	if bar_progres:
		bar_progres.value = 0.0
	_kemas_kini_ui()
	if inv:
		inv.kemas_kini_selepas_batch()

# Iklan terapung ikon steel + "+1" di atas relau, naik lalu pudar.
# Guna semula node yang sudah ada: tiada Control baru setiap unit.
func _apung_steel(banyak: int) -> void:
	if _iklan == null:
		return
	var teks: String = "+%d" % banyak
	# Label hanya diukur semula bila teksnya berubah; teks sama tidak perlu
	# susun atur semula setiap unit.
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
		_iklan_masa = -1.0
		_iklan.modulate.a = 0.0
		_iklan.visible = false
		return
	_iklan.position = Vector2(_iklan_x, IKLAN_Y_ASAL - JARAK_IKLAN * t)
	var p: float = clampf((t - IKLAN_MULA_PUDAR) / (1.0 - IKLAN_MULA_PUDAR), 0.0, 1.0)
	_iklan.modulate.a = 1.0 - (p * p * (3.0 - 2.0 * p))

# Kemas kini menu: ikon + bilangan bahan, status, pilihan kuantiti, butang.
func _kemas_kini_ui() -> void:
	var maks: int = _maks_unit()
	if not sedang_lebur:
		kuantiti_pilihan = clampi(kuantiti_pilihan, 1, maxi(1, maks))
	var perlu_besi: int = int(resipi[0]["kuantiti"]) * kuantiti_pilihan
	var perlu_ais: int = int(resipi[1]["kuantiti"]) * kuantiti_pilihan
	var ada_besi: int = _bilangan_dalam_beg(resipi[0]["id"])
	var ada_ais: int = _bilangan_dalam_beg(resipi[1]["id"])

	_tulis_bilangan(label_bil_besi, ada_besi, perlu_besi)
	_tulis_bilangan(label_bil_ais, ada_ais, perlu_ais)
	if label_bil_keluaran:
		label_bil_keluaran.text = str(_bilangan_dalam_beg(ID_STEEL))
	if label_kuantiti:
		label_kuantiti.text = str(kuantiti_pilihan)
	if label_maks:
		label_maks.text = "max %d" % maks
	if butang_kurang:
		butang_kurang.disabled = sedang_lebur or kuantiti_pilihan <= 1
	if butang_tambah:
		butang_tambah.disabled = sedang_lebur or kuantiti_pilihan >= maks

	if label_status:
		if sedang_lebur:
			label_status.text = "Smelting %d/%d" % [_unit_selesai + 1, maxi(1, _jumlah_batch)]
			label_status.add_theme_color_override("font_color", WARNA_SEDANG)
		elif _bahan_cukup():
			label_status.text = "Ready"
			label_status.add_theme_color_override("font_color", WARNA_CUKUP)
		else:
			label_status.text = "Need materials"
			label_status.add_theme_color_override("font_color", WARNA_KURANG)

	if butang_lebur and not sedang_lebur:
		butang_lebur.text = "Craft"
		butang_lebur.disabled = not _bahan_cukup()

	_kemas_progres()

# Bar kemajuan bawah ikon steel: "1/7" semasa unit pertama, naik sampai "7/7".
func _kemas_progres(nisbah: float = 0.0) -> void:
	var jumlah: int = maxi(1, _jumlah_batch if _jumlah_batch > 0 else kuantiti_pilihan)
	var teks: String = "0/%d" % kuantiti_pilihan
	var nilai: float = 0.0
	if sedang_lebur:
		teks = "%d/%d" % [mini(_unit_selesai + 1, jumlah), jumlah]
		# Bar/cincin untuk SATU item sahaja: penuh setiap unit, kemudian mula semula.
		nilai = clampf(nisbah, 0.0, 1.0)
	elif _jumlah_batch > 0 and _unit_selesai >= _jumlah_batch:
		teks = "%d/%d" % [_jumlah_batch, _jumlah_batch]
		nilai = 1.0

	if label_progress:
		label_progress.text = teks
	if bar_progres:
		bar_progres.value = nilai * 100.0
	if _bulatan:
		_bulatan.visible = sedang_lebur
		_bulatan.set_kemajuan(nilai, teks)

func _tulis_bilangan(label: Label, ada: int, perlu: int) -> void:
	if label == null:
		return
	label.text = str(perlu)
	if sedang_lebur:
		label.add_theme_color_override("font_color", WARNA_SEDANG)
	elif ada >= perlu:
		label.add_theme_color_override("font_color", WARNA_CUKUP)
	else:
		label.add_theme_color_override("font_color", WARNA_KURANG)

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

# ==========================================================
# PENDERIA & INPUT
# ==========================================================
func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_dekat = true
		if sprite:
			sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_dekat = false
		if not sedang_lebur and sprite:
			sprite.modulate = Color.WHITE
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
			_kemas_kini_ui()
	get_viewport().set_input_as_handled()

func _on_butang_tutup_pressed() -> void:
	if menu_ui:
		menu_ui.hide()

func _on_butang_demolish_pressed() -> void:
	sedang_lebur = false
	player_dekat = false
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = _skala_asal
	queue_free()
