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
## Lantai tidak berkolider (pemain terapung/berjalan di atasnya), dinding
## menyekat pemain, pintu terbuka automatik bila pemain hampir.

const SAIZ_SEL: int = 16
const JENIS_LANTAI: int = 0
const JENIS_DINDING: int = 1
const JENIS_PINTU: int = 2
const NAMA_JENIS: Array[String] = ["Floor", "Wall", "Door"]

# Layer 4 (nilai 8) = environment, sama seperti meteorit dan asteroid.
const LAYER_HALANGAN: int = 8
const JARAK_BUKA_PINTU: float = 22.0

# Dipakai oleh AstroStateMachine supaya tap semasa mod bina tidak
# menggerakkan pemain.
static var mod_aktif: bool = false

var _tile: Dictionary = {}        # Vector2i -> jenis
var _badan_pintu: Dictionary = {} # Vector2i -> StaticBody2D
var _pintu_dekat: Dictionary = {} # Vector2i -> bool

var _mod: int = -1
var _jari: int = -1
var _hantu: Vector2i = Vector2i.ZERO
var _ada_hantu: bool = false

var _butang: Array[Button] = []
var _label_status: Label

func _ready() -> void:
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
	for jenis in [JENIS_LANTAI, JENIS_DINDING, JENIS_PINTU]:
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
	_label_status.position = Vector2(6, 96 + 4 * 26 + 4)
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
	_label_status.text = NAMA_JENIS[jenis] + ": tap inside the asteroid"

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
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_letak_dari_skrin(event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		_gerak_hantu(event.position)

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
	if not boleh_bina(g):
		_label_status.text = "Can't build here: must be on the asteroid and touch your base"
		return false

	var jenis := _mod
	_tile[g] = jenis
	_bina_kolider(g, jenis)
	_label_status.text = NAMA_JENIS[jenis] + " placed"
	queue_redraw()
	return true

func boleh_bina(g: Vector2i) -> bool:
	if _tile.has(g):
		return false
	if not _atas_asteroid(_tengah_sel(g)):
		return false
	if _tile.is_empty():
		return true
	for arah in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if _tile.has(g + arah):
			return true
	return false

func _atas_asteroid(pos: Vector2) -> bool:
	for asteroid in get_tree().get_nodes_in_group("Asteroid"):
		if asteroid.has_method("boleh_bina_di") and asteroid.boleh_bina_di(pos):
			return true
	return false

func _bina_kolider(g: Vector2i, jenis: int) -> void:
	if jenis == JENIS_LANTAI:
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

# Pintu terbuka (kolider dimatikan) bila pemain berada dekat.
func _physics_process(_delta: float) -> void:
	if _badan_pintu.is_empty():
		return
	var pemain := get_tree().get_first_node_in_group("Player") as Node2D
	for g in _badan_pintu:
		var dekat: bool = pemain != null and is_instance_valid(pemain) \
			and pemain.global_position.distance_to(_tengah_sel(g)) <= JARAK_BUKA_PINTU
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
				draw_rect(rect, Color(0.07, 0.22, 0.30, 0.82))
				draw_rect(rect, Color(0.28, 0.66, 0.82, 0.55), false, 1.0)
			JENIS_DINDING:
				draw_rect(rect, Color(0.10, 0.17, 0.24, 0.95))
				draw_rect(rect, Color(0.45, 0.95, 1.0, 0.9), false, 2.0)
				draw_line(rect.position + Vector2(4, 4), rect.end - Vector2(4, 4),
					Color(0.3, 0.7, 0.85, 0.45), 1.0)
			JENIS_PINTU:
				if bool(_pintu_dekat.get(g, false)):
					draw_rect(rect, Color(0.2, 0.55, 0.65, 0.25))
					draw_rect(rect, Color(0.5, 1.0, 1.0, 0.45), false, 1.0)
				else:
					draw_rect(rect, Color(0.12, 0.30, 0.38, 0.95))
					draw_rect(rect, Color(0.55, 1.0, 1.0, 0.95), false, 2.0)
					draw_line(rect.position + Vector2(SAIZ_SEL * 0.5, 2),
						rect.position + Vector2(SAIZ_SEL * 0.5, SAIZ_SEL - 2),
						Color(0.05, 0.20, 0.28), 2.0)

	if _ada_hantu and _mod >= 0:
		var rect := Rect2(Vector2(_hantu) * SAIZ_SEL, saiz)
		var sah := boleh_bina(_hantu)
		var warna := Color(0.4, 1.0, 0.6, 0.30) if sah else Color(1.0, 0.35, 0.35, 0.30)
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
