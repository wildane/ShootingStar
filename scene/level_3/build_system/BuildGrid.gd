class_name BuildGrid
extends Node2D

## Sistem bina grid pangkalan: lantai, dinding dan pintu.
##
## Peraturan penempatan (mengikut keputusan reka bentuk projek):
## 1. Tile mesti berada di atas asteroid (group "Asteroid" + `boleh_bina_di`).
## 2. Tile pertama bebas di mana-mana dalam asteroid; tile seterusnya mesti
##    bersambung 4-jiran dengan tile sedia ada. Jadi tiada struktur terapung
##    dan tiada dinding terpencil di angkasa.
##
## Lantai tidak berkolider (pemain terapung/berjalan di atasnya), tetapi
## setiap lantai menjadi zon bina (layer 3) supaya perabot boleh diletak di
## atasnya. Dinding menyekat pemain, pintu terbuka automatik bila pemain
## hampir. Mod Erase membuang tile yang tersalah letak.

const SAIZ_SEL: int = 16
const JENIS_LANTAI: int = 0
const JENIS_DINDING: int = 1
const JENIS_PINTU: int = 2
const JENIS_ERASE: int = 3
const NAMA_JENIS: Array[String] = ["Floor", "Wall", "Door", "Erase"]

# Layer 4 (nilai 8) = environment, sama seperti meteorit dan asteroid.
const LAYER_HALANGAN: int = 8
# Layer 3 (nilai 4) = zon bina. Preview perabot hanya boleh dipasang bila
# ia bertindih dengan zon ini.
const LAYER_ZON_BINA: int = 4
const JARAK_BUKA_PINTU: float = 22.0

# Pembinaan / nyahbina: tile dirancang (hijau/merah) dahulu, kemudian dibina
# atau dinyahbina apabila pemain cukup dekat. Setiap tile kos 1 Basic Iron.
const JARAK_BINA: float = 28.0
const MASA_BINA: float = 0.9
const ID_BESI: String = "item_0001"
const NAMA_BESI: String = "Basic Iron Ore"
const IKON_BESI: String = "res://scene/Item/0001BasicIronOre/Image_959.png"
const LALUAN_BESI: String = "res://scene/Item/0001BasicIronOre/0001BasicIronOre.tscn"
const KOS_BESI: int = 1

# Aset tile: lantai, dinding dan pintu.
const TEKSTUR_LANTAI: Texture2D = preload("res://scene/level_3/build_system/tile_floor.png")
const TEKSTUR_DINDING: Texture2D = preload("res://scene/level_3/build_system/tile_wall_atlas.png")
# Atlas dinding 4x4 jubin 64px: indeks = bitmask jiran dinding (1=N, 2=E, 4=S, 8=W).
# Sisi yang tiada jiran dinding dilukis dengan rim, jadi lurus, belokan dan
# dinding dua ketebalan semuanya bercantum tanpa garis dalaman.
const SAIZ_JUBIN_DINDING: float = 64.0
const TEKSTUR_PINTU: Texture2D = preload("res://scene/level_3/build_system/tile_door.png")
const SKRIP_PINTU_GRID: Script = preload("res://scene/level_3/build_system/PintuGrid.gd")

# Dipakai oleh AstroStateMachine supaya tap semasa mod bina tidak
# menggerakkan pemain.
static var mod_aktif: bool = false

var _tile: Dictionary = {}        # Vector2i -> jenis (tile siap dibina)
var _badan_pintu: Dictionary = {} # Vector2i -> StaticBody2D
var _pintu_dekat: Dictionary = {} # Vector2i -> bool
var _zon_lantai: Dictionary = {}  # Vector2i -> Area2D (zon bina perabot)
var _paun_pintu: Dictionary = {}  # Vector2i -> PintuGrid (paun laluan robot)

# Tile dirancang (belum dibina) dan tanda nyahbina (belum dibuang).
var _rancang: Dictionary = {}     # Vector2i -> jenis
var _bina_kemajuan: Dictionary = {} # Vector2i -> float 0..1 (sedang dibina)
var _padam_tanda: Dictionary = {} # Vector2i -> true (ditanda untuk nyahbina)
var _padam_kemajuan: Dictionary = {} # Vector2i -> float 0..1 (sedang nyahbina)

var _mod: int = -1
var _jari: int = -1
var _hantu: Vector2i = Vector2i.ZERO
var _ada_hantu: bool = false

var _butang: Array[Button] = []
var _label_status: Label

func _ready() -> void:
	add_to_group("BuildGrid")
	mod_aktif = false
	_bina_hud()

func _exit_tree() -> void:
	mod_aktif = false

# ==========================================
# HUD: butang Floor / Wall / Door / X
# ==========================================
func _bina_hud() -> void:
	var kanvas := CanvasLayer.new()
	kanvas.name = "HudBinaGrid"
	kanvas.layer = 90
	add_child(kanvas)

	var lajur := VBoxContainer.new()
	lajur.position = Vector2(6, 96)
	lajur.add_theme_constant_override("separation", 4)
	kanvas.add_child(lajur)

	var tema := _tema_butang()
	for jenis in [JENIS_LANTAI, JENIS_DINDING, JENIS_PINTU, JENIS_ERASE]:
		var butang := Button.new()
		butang.text = NAMA_JENIS[jenis]
		butang.toggle_mode = true
		butang.focus_mode = Control.FOCUS_NONE
		butang.custom_minimum_size = Vector2(58, 22)
		butang.add_theme_font_size_override("font_size", 7)
		butang.theme = tema
		butang.pressed.connect(_pilih.bind(jenis))
		lajur.add_child(butang)
		_butang.append(butang)

	var batal := Button.new()
	batal.text = "Cancel"
	batal.focus_mode = Control.FOCUS_NONE
	batal.custom_minimum_size = Vector2(58, 22)
	batal.add_theme_font_size_override("font_size", 7)
	batal.theme = tema
	batal.pressed.connect(_batal)
	lajur.add_child(batal)

	_label_status = Label.new()
	_label_status.position = Vector2(6, lajur.position.y + lajur.get_child_count() * 26 + 4)
	_label_status.custom_minimum_size = Vector2(150, 0)
	_label_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_status.add_theme_font_size_override("font_size", 6)
	_label_status.add_theme_color_override("font_color", Color(0.72, 0.93, 1.0))
	kanvas.add_child(_label_status)

func _tema_butang() -> Theme:
	var tema := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.054, 0.145, 0.211, 0.92)
	normal.border_color = Color(0.36, 0.9, 1, 0.7)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(3.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.098, 0.278, 0.38, 0.96)
	hover.border_color = Color(0.5, 0.97, 1, 1)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.2, 0.55, 0.68, 1)
	pressed.border_color = Color(0.75, 1, 1, 1)
	tema.set_stylebox("normal", "Button", normal)
	tema.set_stylebox("hover", "Button", hover)
	tema.set_stylebox("pressed", "Button", pressed)
	tema.set_stylebox("focus", "Button", hover)
	tema.set_color("font_color", "Button", Color(0.85, 0.97, 1, 1))
	tema.set_color("font_pressed_color", "Button", Color(0.05, 0.12, 0.16, 1))
	return tema

# ==========================================
# MOD BINA
# ==========================================
func _pilih(jenis: int) -> void:
	if _mod == jenis:
		_batal()
		return
	_mod = jenis
	mod_aktif = true
	_ada_hantu = false
	for i in range(_butang.size()):
		_butang[i].set_pressed_no_signal(i == jenis)
	if jenis == JENIS_ERASE:
		_label_status.text = "Erase: tap a built tile to mark it. Go near to deconstruct and get 1 Iron back"
	else:
		_label_status.text = NAMA_JENIS[jenis] + ": tap to plan (1 Iron). Go near to build"

func _batal() -> void:
	_mod = -1
	mod_aktif = false
	_jari = -1
	_ada_hantu = false
	for butang in _butang:
		butang.set_pressed_no_signal(false)
	_label_status.text = ""
	queue_redraw()

# ==========================================
# INPUT: tap = letak, heret = gerak hantu
# ==========================================
func _unhandled_input(event: InputEvent) -> void:
	if _mod < 0:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _jari != -1:
				return
			_jari = event.index
			_letak_dari_skrin(event.position)
		elif event.index == _jari:
			_jari = -1
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		_gerak_hantu(event.position)
		if _mod == JENIS_ERASE:
			padam(_hantu)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_letak_dari_skrin(event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		_gerak_hantu(event.position)
		if _mod == JENIS_ERASE and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			padam(_hantu)

func _gerak_hantu(pos_skrin: Vector2) -> void:
	_hantu = _sel_dari_dunia(_skrin_ke_dunia(pos_skrin))
	_ada_hantu = true
	queue_redraw()

func _letak_dari_skrin(pos_skrin: Vector2) -> void:
	_hantu = _sel_dari_dunia(_skrin_ke_dunia(pos_skrin))
	_ada_hantu = true
	letak(_hantu)

# ==========================================
# PENEMPATAN TILE
# ==========================================
# Boleh dipanggil terus (ujian) tanpa input skrin.
func letak(g: Vector2i) -> bool:
	if _mod < 0:
		return false
	if _mod == JENIS_ERASE:
		return padam(g)
	if not boleh_bina(g):
		_label_status.text = "Can't build here: must be on the asteroid and touch your base"
		return false

	var jenis := _mod
	_rancang[g] = jenis
	_bina_kemajuan.erase(g)
	_label_status.text = NAMA_JENIS[jenis] + " planned (1 Iron)"
	queue_redraw()
	return true

# Buang tile (dan kolidernya) dari grid. Boleh dipanggil terus untuk ujian.
func padam(g: Vector2i) -> bool:
	# Batal rancangan: jika pembinaan sudah bermula, pulangkan bahan.
	if _rancang.has(g):
		var sedang_bina := _bina_kemajuan.has(g)
		_rancang.erase(g)
		_bina_kemajuan.erase(g)
		if sedang_bina:
			_pulangkan_besi()
			_label_status.text = "Plan cancelled (+1 Iron)"
		else:
			_label_status.text = "Plan cancelled"
		queue_redraw()
		return true
	# Tanda tile siap untuk nyahbina.
	if _tile.has(g):
		if _padam_tanda.has(g):
			_label_status.text = "Already marked for deconstruction"
			return false
		_padam_tanda[g] = true
		_padam_kemajuan.erase(g)
		_label_status.text = "Marked for deconstruction. Go near to recover 1 Iron"
		queue_redraw()
		return true
	_label_status.text = "Nothing to erase here"
	return false

# Buang semua tile: dipakai sebelum memuat semula grid dari fail simpanan.
func kosongkan() -> void:
	for g in _tile.keys().duplicate():
		_buang_tile(g)
	_tile.clear()
	_rancang.clear()
	_bina_kemajuan.clear()
	_padam_tanda.clear()
	_padam_kemajuan.clear()
	queue_redraw()

# Buang satu tile siap sahaja (tanpa sentuh teks status).
func _buang_tile(g: Vector2i) -> void:
	_tile.erase(g)
	_padam_tanda.erase(g)
	_padam_kemajuan.erase(g)
	var badan: StaticBody2D = _badan_pintu.get(g, null)
	if badan == null:
		badan = get_node_or_null("Grid_%d_%d" % [g.x, g.y]) as StaticBody2D
	if badan != null and is_instance_valid(badan):
		badan.queue_free()
	_badan_pintu.erase(g)
	_pintu_dekat.erase(g)
	var zon: Area2D = _zon_lantai.get(g, null)
	if zon != null and is_instance_valid(zon):
		zon.queue_free()
	_zon_lantai.erase(g)
	var paun = _paun_pintu.get(g, null)
	if paun != null and is_instance_valid(paun):
		paun.queue_free()
	_paun_pintu.erase(g)

# ==========================================
# SIMPAN / MUAT TILE
# ==========================================
# Semua tile siap dan rancangan disimpan sebagai senarai koordinat grid.
func dapatkan_data_save() -> Dictionary:
	var senarai: Array = []
	for g in _tile:
		senarai.append({"x": g.x, "y": g.y, "jenis": int(_tile[g])})
	var senarai_rancang: Array = []
	for g in _rancang:
		var entri: Dictionary = {"x": g.x, "y": g.y, "jenis": int(_rancang[g])}
		if _bina_kemajuan.has(g):
			entri["kemajuan"] = float(_bina_kemajuan[g])
		senarai_rancang.append(entri)
	var senarai_padam: Array = []
	for g in _padam_tanda:
		var entri_padam: Dictionary = {"x": g.x, "y": g.y}
		if _padam_kemajuan.has(g):
			entri_padam["kemajuan"] = float(_padam_kemajuan[g])
		senarai_padam.append(entri_padam)
	return {"tiles": senarai, "rancang": senarai_rancang, "padam_tanda": senarai_padam}

# Bina semula tile dari fail simpanan. Grid dikosongkan dahulu supaya tiada
# tile berganda kalau fungsi ini dipanggil dua kali.
func muat_data_save(data: Dictionary) -> void:
	kosongkan()
	var senarai: Array = data.get("tiles", [])
	for item in senarai:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var jenis := int(item.get("jenis", JENIS_LANTAI))
		if jenis < JENIS_LANTAI or jenis > JENIS_PINTU:
			continue
		var g := Vector2i(int(item.get("x", 0)), int(item.get("y", 0)))
		_tile[g] = jenis
		_bina_kolider(g, jenis)
	# Pulihkan tanda nyahbina (hanya untuk tile siap yang wujud).
	for item in data.get("padam_tanda", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var g := Vector2i(int(item.get("x", 0)), int(item.get("y", 0)))
		if _tile.has(g):
			_padam_tanda[g] = true
			if item.has("kemajuan"):
				_padam_kemajuan[g] = clampf(float(item.get("kemajuan", 0.0)), 0.0, 0.99)
	# Pulihkan rancangan (hanya sel kosong di atas asteroid).
	for item in data.get("rancang", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var jenis := int(item.get("jenis", JENIS_LANTAI))
		if jenis < JENIS_LANTAI or jenis > JENIS_PINTU:
			continue
		var g := Vector2i(int(item.get("x", 0)), int(item.get("y", 0)))
		if not _tile.has(g) and not _rancang.has(g):
			_rancang[g] = jenis
			if item.has("kemajuan"):
				_bina_kemajuan[g] = clampf(float(item.get("kemajuan", 0.0)), 0.0, 0.99)
	queue_redraw()

func boleh_bina(g: Vector2i) -> bool:
	if _tile.has(g) or _rancang.has(g):
		return false
	if not _atas_asteroid(_tengah_sel(g)):
		return false
	if _tile.is_empty() and _rancang.is_empty():
		return true
	for arah in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var jiran := g + arah
		if _tile.has(jiran) or _rancang.has(jiran):
			return true
	return false

func _atas_asteroid(pos: Vector2) -> bool:
	for asteroid in get_tree().get_nodes_in_group("Asteroid"):
		if asteroid.has_method("boleh_bina_di") and asteroid.boleh_bina_di(pos):
			return true
	return false

func _bina_kolider(g: Vector2i, jenis: int) -> void:
	if jenis == JENIS_LANTAI:
		_bina_zon_lantai(g)
		return
	var badan := StaticBody2D.new()
	badan.name = "Grid_%d_%d" % [g.x, g.y]
	badan.position = _tengah_sel(g)
	badan.collision_layer = LAYER_HALANGAN
	badan.collision_mask = 0
	var bentuk := CollisionShape2D.new()
	var segi := RectangleShape2D.new()
	segi.size = Vector2(SAIZ_SEL, SAIZ_SEL)
	bentuk.shape = segi
	badan.add_child(bentuk)
	add_child(badan)
	if jenis == JENIS_PINTU:
		_badan_pintu[g] = badan
		_bina_paun_pintu(g)

# Node navigasi pintu: sistem laluan robot menyambung kedua-dua belah pintu
# melalui titik_pintasan(), jadi robot boleh lalu dinding berpintu.
func _bina_paun_pintu(g: Vector2i) -> void:
	# Tanpa jenis: skrip PintuGrid menambah medan grid/sel pada node ini.
	var paun = SKRIP_PINTU_GRID.new()
	paun.name = "Pintu_%d_%d" % [g.x, g.y]
	paun.grid = self
	paun.sel = g
	paun.saiz_sel = float(SAIZ_SEL)
	paun.position = _tengah_sel(g)
	paun.add_to_group("PintuGrid")
	add_child(paun)
	_paun_pintu[g] = paun

# Paksi lintasan pintu: kalau dinding terletak di kiri/kanan pintu, robot
# melintas atas-bawah; kalau dinding di atas/bawah, robot melintas kiri-kanan.
func paksi_lintasan(g: Vector2i) -> Vector2:
	var dinding_kiri: bool = int(_tile.get(g + Vector2i(-1, 0), -1)) == JENIS_DINDING
	var dinding_kanan: bool = int(_tile.get(g + Vector2i(1, 0), -1)) == JENIS_DINDING
	var dinding_atas: bool = int(_tile.get(g + Vector2i(0, -1), -1)) == JENIS_DINDING
	var dinding_bawah: bool = int(_tile.get(g + Vector2i(0, 1), -1)) == JENIS_DINDING
	var sisi: bool = dinding_kiri or dinding_kanan
	var menegak: bool = dinding_atas or dinding_bawah
	if sisi and not menegak:
		return Vector2.DOWN
	return Vector2.RIGHT

# Lantai tiada kolider, tetapi ia menjadi zon bina (layer 3) supaya preview
# perabot menganggap sel ini sebagai lantai yang sah untuk membina.
func _bina_zon_lantai(g: Vector2i) -> void:
	var zon := Area2D.new()
	zon.name = "Lantai_%d_%d" % [g.x, g.y]
	zon.position = _tengah_sel(g)
	zon.collision_layer = LAYER_ZON_BINA
	zon.collision_mask = 0
	# Preview perabot mengimbas kawasan ini; zon tidak perlu mengimbas apa-apa.
	zon.monitoring = false
	zon.monitorable = true
	var bentuk := CollisionShape2D.new()
	var segi := RectangleShape2D.new()
	segi.size = Vector2(SAIZ_SEL, SAIZ_SEL)
	bentuk.shape = segi
	zon.add_child(bentuk)
	add_child(zon)
	_zon_lantai[g] = zon

# ==========================================
# PEMBINAAN / NYAHBINA BERASASKAN JARAK
# ==========================================
func _ada_besi() -> bool:
	var inv = get_node_or_null("/root/InventoryManager")
	return inv != null and inv.bilangan_item(ID_BESI) >= KOS_BESI

func _tolak_besi() -> bool:
	var inv = get_node_or_null("/root/InventoryManager")
	return inv != null and inv.tolak_item(ID_BESI, KOS_BESI)

func _pulangkan_besi() -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return
	var ikon_tex: Texture2D = null
	if ResourceLoader.exists(IKON_BESI):
		ikon_tex = load(IKON_BESI)
	inv.tambah_item({
		"id": ID_BESI,
		"nama": NAMA_BESI,
		"ikon": ikon_tex,
		"scene_path": LALUAN_BESI,
	})

func _pemain_dekat(g: Vector2i, pos_pemain: Vector2) -> bool:
	return pos_pemain.x < INF \
		and pos_pemain.distance_to(to_global(_tengah_sel(g))) <= JARAK_BINA

func _kemas_kini_pembinaan(delta: float, pos_pemain: Vector2) -> void:
	if _rancang.is_empty():
		return
	# Bina satu demi satu: jika ada binaan bermula, hanya sambung bila pemain dekat.
	var ada_bermula := not _bina_kemajuan.is_empty()
	var sasaran: Vector2i = Vector2i.ZERO
	var ada_sasaran := false
	var jarak_terbaik := INF
	var sudah_bermula := false

	for g in _rancang.keys():
		var bermula := _bina_kemajuan.has(g)
		if ada_bermula and not bermula:
			continue
		if not _pemain_dekat(g, pos_pemain):
			continue
		if bermula:
			sasaran = g
			ada_sasaran = true
			sudah_bermula = true
			break
		var jarak := pos_pemain.distance_to(to_global(_tengah_sel(g)))
		if jarak < jarak_terbaik:
			jarak_terbaik = jarak
			sasaran = g
			ada_sasaran = true

	if not ada_sasaran:
		# Tiada yang dalam jarak / binaan bermula sedang menunggu pemain kembali.
		return

	# Mula binaan: tolak bahan sekarang.
	if not sudah_bermula:
		if not _ada_besi():
			_label_status.text = "Need 1 Basic Iron to build " + NAMA_JENIS[int(_rancang[sasaran])]
			return
		if not _tolak_besi():
			return
		_bina_kemajuan[sasaran] = 0.0
		_label_status.text = "Constructing " + NAMA_JENIS[int(_rancang[sasaran])] + "..."

	_bina_kemajuan[sasaran] = float(_bina_kemajuan.get(sasaran, 0.0)) + delta / MASA_BINA
	queue_redraw()
	if float(_bina_kemajuan[sasaran]) < 1.0:
		return

	# Siap dibina: jadikan tile sebenar.
	var jenis := int(_rancang[sasaran])
	_rancang.erase(sasaran)
	_bina_kemajuan.erase(sasaran)
	_tile[sasaran] = jenis
	_bina_kolider(sasaran, jenis)
	_label_status.text = NAMA_JENIS[jenis] + " built"
	queue_redraw()

func _kemas_kini_nyahbina(delta: float, pos_pemain: Vector2) -> void:
	if _padam_tanda.is_empty():
		return
	var ada_bermula := not _padam_kemajuan.is_empty()
	var sasaran: Vector2i = Vector2i.ZERO
	var ada_sasaran := false
	var jarak_terbaik := INF
	var sudah_bermula := false

	for g in _padam_tanda.keys().duplicate():
		if not _tile.has(g):
			_padam_tanda.erase(g)
			_padam_kemajuan.erase(g)
			continue
		var bermula := _padam_kemajuan.has(g)
		if ada_bermula and not bermula:
			continue
		if not _pemain_dekat(g, pos_pemain):
			continue
		if bermula:
			sasaran = g
			ada_sasaran = true
			sudah_bermula = true
			break
		var jarak := pos_pemain.distance_to(to_global(_tengah_sel(g)))
		if jarak < jarak_terbaik:
			jarak_terbaik = jarak
			sasaran = g
			ada_sasaran = true

	if not ada_sasaran:
		return

	if not sudah_bermula:
		_padam_kemajuan[sasaran] = 0.0
		_label_status.text = "Deconstructing " + NAMA_JENIS[int(_tile[sasaran])] + "..."

	_padam_kemajuan[sasaran] = float(_padam_kemajuan.get(sasaran, 0.0)) + delta / MASA_BINA
	queue_redraw()
	if float(_padam_kemajuan[sasaran]) < 1.0:
		return

	# Siap nyahbina: buang tile dan pulangkan bahan.
	var jenis := int(_tile.get(sasaran, JENIS_LANTAI))
	_buang_tile(sasaran)
	_pulangkan_besi()
	_label_status.text = NAMA_JENIS[jenis] + " deconstructed (+1 Iron)"
	queue_redraw()

# Pintu terbuka (kolider dimatikan) bila pemain ATAU robot pekerja berada
# dekat. Tile dirancang dibina satu demi satu apabila pemain dekat; tile yang
# ditanda nyahbina dipadam satu demi satu dan bahan dipulangkan.
func _physics_process(delta: float) -> void:
	var pemain := get_tree().get_first_node_in_group("Player") as Node2D
	var pos_pemain := Vector2(INF, INF)
	if pemain != null and is_instance_valid(pemain):
		pos_pemain = pemain.global_position

	_kemas_kini_pembinaan(delta, pos_pemain)
	_kemas_kini_nyahbina(delta, pos_pemain)

	if _badan_pintu.is_empty():
		return
	var robot := get_tree().get_nodes_in_group("RobotPekerja")
	for g in _badan_pintu:
		var pusat := to_global(_tengah_sel(g))
		var dekat: bool = pos_pemain.x < INF \
			and pos_pemain.distance_to(pusat) <= JARAK_BUKA_PINTU
		if not dekat:
			for nod in robot:
				if nod is Node2D and is_instance_valid(nod) \
						and (nod as Node2D).global_position.distance_to(pusat) <= JARAK_BUKA_PINTU:
					dekat = true
					break
		if bool(_pintu_dekat.get(g, false)) == dekat:
			continue
		_pintu_dekat[g] = dekat
		var badan: StaticBody2D = _badan_pintu[g]
		badan.set_deferred("collision_layer", 0 if dekat else LAYER_HALANGAN)
		queue_redraw()

# ==========================================
# LUKISAN
# ==========================================
func _draw() -> void:
	var saiz := Vector2(SAIZ_SEL, SAIZ_SEL)
	for g in _tile:
		var rect := Rect2(Vector2(g) * SAIZ_SEL, saiz)
		match int(_tile[g]):
			JENIS_LANTAI:
				draw_texture_rect(TEKSTUR_LANTAI, rect, false, Color(1, 1, 1, 0.95))
				draw_rect(rect, Color(0.28, 0.66, 0.82, 0.22), false, 1.0)
			JENIS_DINDING:
				var topeng := _topeng_dinding(g)
				var jubin := Rect2(
					Vector2(float(topeng % 4), float(topeng / 4)) * SAIZ_JUBIN_DINDING,
					Vector2(SAIZ_JUBIN_DINDING, SAIZ_JUBIN_DINDING))
				draw_texture_rect_region(TEKSTUR_DINDING, rect, jubin)
			JENIS_PINTU:
				# Pintu dalam dinding menegak dipusing 90 darjah supaya bingkai
				# atas/bawahnya sejajar dengan arah dinding.
				var menegak: bool = _jiran_jenis(g, Vector2i(0, -1), JENIS_DINDING) \
					and _jiran_jenis(g, Vector2i(0, 1), JENIS_DINDING)
				var terbuka: bool = bool(_pintu_dekat.get(g, false))
				var warna := Color(0.6, 0.95, 1.0, 0.4) if terbuka else Color(1, 1, 1)
				if menegak:
					draw_set_transform(rect.get_center(), PI * 0.5, Vector2.ONE)
					draw_texture_rect(TEKSTUR_PINTU, Rect2(-saiz * 0.5, saiz), false, warna)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					draw_texture_rect(TEKSTUR_PINTU, rect, false, warna)
				if terbuka:
					draw_rect(rect, Color(0.5, 1.0, 1.0, 0.5), false, 1.0)

		# Tanda nyahbina: overlay merah + bar kemajuan.
		if _padam_tanda.has(g):
			var kemajuan := float(_padam_kemajuan.get(g, 0.0))
			draw_rect(rect, Color(1.0, 0.25, 0.2, 0.28))
			draw_rect(rect, Color(1.0, 0.35, 0.25, 0.9), false, 1.5)
			if kemajuan > 0.0:
				var isi := Rect2(rect.position.x + 1, rect.end.y - 4, (rect.size.x - 2) * clampf(kemajuan, 0.0, 1.0), 3)
				draw_rect(Rect2(rect.position.x + 1, rect.end.y - 4, rect.size.x - 2, 3), Color(0.15, 0.05, 0.05, 0.8))
				draw_rect(isi, Color(1.0, 0.45, 0.35, 0.95))

	# Tile dirancang (belum dibina): hijau + bar kemajuan pembinaan.
	for g in _rancang:
		var rect := Rect2(Vector2(g) * SAIZ_SEL, saiz)
		var jenis := int(_rancang[g])
		var kemajuan := float(_bina_kemajuan.get(g, 0.0))
		var alfa := 0.45 + kemajuan * 0.35
		match jenis:
			JENIS_LANTAI:
				draw_texture_rect(TEKSTUR_LANTAI, rect, false, Color(0.45, 1.0, 0.55, alfa))
			JENIS_DINDING:
				var topeng := _topeng_dinding_rancang(g)
				var jubin := Rect2(
					Vector2(float(topeng % 4), float(topeng / 4)) * SAIZ_JUBIN_DINDING,
					Vector2(SAIZ_JUBIN_DINDING, SAIZ_JUBIN_DINDING))
				draw_texture_rect_region(TEKSTUR_DINDING, rect, jubin, Color(0.45, 1.0, 0.55, alfa))
			JENIS_PINTU:
				var menegak: bool = _jiran_jenis_rancang_atau_bina(g, Vector2i(0, -1), JENIS_DINDING) \
					and _jiran_jenis_rancang_atau_bina(g, Vector2i(0, 1), JENIS_DINDING)
				var warna := Color(0.45, 1.0, 0.55, alfa)
				if menegak:
					draw_set_transform(rect.get_center(), PI * 0.5, Vector2.ONE)
					draw_texture_rect(TEKSTUR_PINTU, Rect2(-saiz * 0.5, saiz), false, warna)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					draw_texture_rect(TEKSTUR_PINTU, rect, false, warna)
		draw_rect(rect, Color(0.4, 1.0, 0.5, 0.85), false, 1.5)
		if kemajuan > 0.0:
			draw_rect(Rect2(rect.position.x + 1, rect.end.y - 4, rect.size.x - 2, 3), Color(0.05, 0.15, 0.05, 0.8))
			var isi := Rect2(rect.position.x + 1, rect.end.y - 4, (rect.size.x - 2) * clampf(kemajuan, 0.0, 1.0), 3)
			draw_rect(isi, Color(0.45, 1.0, 0.55, 0.95))

	if _ada_hantu and _mod >= 0:
		var rect := Rect2(Vector2(_hantu) * SAIZ_SEL, saiz)
		var sah: bool = _boleh_padam_hantu(_hantu) if _mod == JENIS_ERASE else boleh_bina(_hantu)
		var warna := Color(1.0, 0.42, 0.32, 0.35) if _mod == JENIS_ERASE and sah \
			else (Color(0.4, 1.0, 0.6, 0.30) if sah else Color(1.0, 0.35, 0.35, 0.30))
		draw_rect(rect, warna)
		draw_rect(rect, warna.lightened(0.4), false, 2.0)

# ==========================================
# UTILITI
# ==========================================
func _skrin_ke_dunia(pos_skrin: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos_skrin

func _sel_dari_dunia(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(SAIZ_SEL)), floori(pos.y / float(SAIZ_SEL)))

func _tengah_sel(g: Vector2i) -> Vector2:
	return Vector2(g) * SAIZ_SEL + Vector2(SAIZ_SEL, SAIZ_SEL) * 0.5

func _jiran_jenis(g: Vector2i, arah: Vector2i, jenis: int) -> bool:
	return int(_tile.get(g + arah, -1)) == jenis

func _jiran_jenis_rancang_atau_bina(g: Vector2i, arah: Vector2i, jenis: int) -> bool:
	var jiran := g + arah
	return int(_tile.get(jiran, -1)) == jenis or int(_rancang.get(jiran, -1)) == jenis

# Bitmask jiran dinding: pintu dan rancangan dinding/pintu dikira sebagai
# sambungan supaya rim tidak putus semasa merancang atau selepas dibina.
func _topeng_dinding(g: Vector2i) -> int:
	var topeng := 0
	var arah_bit := [
		[Vector2i(0, -1), 1],
		[Vector2i(1, 0), 2],
		[Vector2i(0, 1), 4],
		[Vector2i(-1, 0), 8],
	]
	for pasangan in arah_bit:
		var jiran := g + pasangan[0]
		var j: int = int(_tile.get(jiran, -1))
		if j == -1:
			j = int(_rancang.get(jiran, -1))
		if j == JENIS_DINDING or j == JENIS_PINTU:
			topeng |= int(pasangan[1])
	return topeng

func _topeng_dinding_rancang(g: Vector2i) -> int:
	return _topeng_dinding(g)

func _boleh_padam_hantu(g: Vector2i) -> bool:
	return _rancang.has(g) or (_tile.has(g) and not _padam_tanda.has(g))
