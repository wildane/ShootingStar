extends CanvasLayer
class_name MapOverlay

# ==========================================================
# PETA PENUH SKRIN
# Dunia dilukis oleh kamera peta berasingan (bukan salinan scene),
# SceneTree dipause jadi pemain/musuh tidak bergerak. Peta boleh
# dizum (wheel / cubit) dan diseret. HUD permainan disembunyikan.
# ==========================================================

@export_group("Zoom Peta")
@export var zoom_awal: float = 0.6
@export var zoom_min: float = 0.25
@export var zoom_max: float = 2.5
@export var faktor_zoom: float = 1.15

@export_group("Had Seretan")
@export var had_peta: Rect2 = Rect2(-400.0, -400.0, 1200.0, 1200.0)

const WARNA_AKSEN: Color = Color("67cdeb")
const WARNA_TEKS: Color = Color("b9efff")

var _kamera_peta: Camera2D
var _kamera_pemain: Camera2D
var _hud: CanvasLayer
var _akar: Control
var _terbuka: bool = false
var _seret: bool = false
var _jari: Dictionary = {}
var _jarak_pinch: float = 0.0


func _init() -> void:
	name = "MapOverlay"
	layer = 10
	# Kekal aktif walaupun SceneTree dipause supaya zoom/seret/tutup berfungsi.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_bina_ui()


# ==========================================================
# UI
# ==========================================================
func _bina_ui() -> void:
	_akar = Control.new()
	_akar.name = "Akar"
	_akar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_akar.mouse_filter = Control.MOUSE_FILTER_STOP
	_akar.visible = false
	add_child(_akar)

	# Bingkai nipis di tepi skrin.
	var bingkai := Panel.new()
	bingkai.name = "Bingkai"
	bingkai.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bingkai.offset_left = 8.0
	bingkai.offset_top = 8.0
	bingkai.offset_right = -8.0
	bingkai.offset_bottom = -8.0
	bingkai.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gaya_bingkai := StyleBoxFlat.new()
	gaya_bingkai.draw_center = false
	gaya_bingkai.border_color = Color(WARNA_AKSEN, 0.55)
	gaya_bingkai.set_border_width_all(2)
	gaya_bingkai.set_corner_radius_all(6)
	bingkai.add_theme_stylebox_override("panel", gaya_bingkai)
	_akar.add_child(bingkai)

	# Bar atas: tajuk + butang tutup.
	var bar := PanelContainer.new()
	bar.name = "Bar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 16.0
	bar.offset_top = 16.0
	bar.offset_right = -16.0
	bar.offset_bottom = 52.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var gaya_bar := StyleBoxFlat.new()
	gaya_bar.bg_color = Color(0.03, 0.08, 0.12, 0.9)
	gaya_bar.set_corner_radius_all(6)
	gaya_bar.content_margin_left = 14.0
	gaya_bar.content_margin_right = 14.0
	gaya_bar.content_margin_top = 4.0
	gaya_bar.content_margin_bottom = 4.0
	bar.add_theme_stylebox_override("panel", gaya_bar)
	_akar.add_child(bar)

	var baris := HBoxContainer.new()
	baris.add_theme_constant_override("separation", 10)
	bar.add_child(baris)

	var tajuk := Label.new()
	tajuk.text = "PETA"
	tajuk.add_theme_font_size_override("font_size", 14)
	tajuk.add_theme_color_override("font_color", WARNA_TEKS)
	tajuk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	baris.add_child(tajuk)

	var jarak := Control.new()
	jarak.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	baris.add_child(jarak)

	var butang_tutup := Button.new()
	butang_tutup.name = "ButangTutup"
	butang_tutup.text = "TUTUP"
	butang_tutup.focus_mode = Control.FOCUS_NONE
	butang_tutup.add_theme_font_size_override("font_size", 12)
	butang_tutup.add_theme_color_override("font_color", WARNA_AKSEN)
	butang_tutup.pressed.connect(tutup)
	baris.add_child(butang_tutup)

	# Petunjuk kawalan di bawah.
	var petunjuk := Label.new()
	petunjuk.name = "Petunjuk"
	petunjuk.text = "Tatal / cubit untuk zoom  •  Seret untuk gerak  •  Esc untuk tutup"
	petunjuk.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	petunjuk.offset_left = 16.0
	petunjuk.offset_top = -40.0
	petunjuk.offset_right = -16.0
	petunjuk.offset_bottom = -14.0
	petunjuk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	petunjuk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	petunjuk.add_theme_font_size_override("font_size", 10)
	petunjuk.add_theme_color_override("font_color", Color(WARNA_TEKS.r, WARNA_TEKS.g, WARNA_TEKS.b, 0.85))
	petunjuk.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	petunjuk.add_theme_constant_override("shadow_offset_x", 1)
	petunjuk.add_theme_constant_override("shadow_offset_y", 1)
	petunjuk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_akar.add_child(petunjuk)


# ==========================================================
# BUKA / TUTUP
# ==========================================================
func terbuka() -> bool:
	return _terbuka


func buka(kamera_peta: Camera2D, kamera_pemain: Camera2D, hud: CanvasLayer, pusat: Vector2) -> void:
	if _terbuka:
		return
	if not is_instance_valid(kamera_peta) or not is_instance_valid(kamera_pemain):
		return
	_kamera_peta = kamera_peta
	_kamera_pemain = kamera_pemain
	_hud = hud
	_terbuka = true
	_akar.visible = true
	_kamera_peta.global_position = pusat
	_kamera_peta.zoom = Vector2(zoom_awal, zoom_awal)
	_kamera_peta.enabled = true
	_kamera_peta.make_current()
	_kemaskin_had()
	if is_instance_valid(_hud):
		_hud.visible = false
	# Bekukan permainan di belakang peta.
	get_tree().paused = true


func tutup() -> void:
	if not _terbuka:
		return
	_terbuka = false
	_akar.visible = false
	_seret = false
	_jari.clear()
	_jarak_pinch = 0.0
	get_tree().paused = false
	if is_instance_valid(_hud):
		_hud.visible = true
	# Pulangkan kamera pemain dahulu, baru matikan kamera peta.
	if is_instance_valid(_kamera_pemain) and _kamera_pemain.is_inside_tree():
		_kamera_pemain.make_current()
	if is_instance_valid(_kamera_peta):
		_kamera_peta.enabled = false


# ==========================================================
# KAWALAN PETA
# ==========================================================
func _input(event: InputEvent) -> void:
	if not _terbuka:
		return

	if event.is_action_pressed("ui_cancel"):
		tutup()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_seret = event.pressed
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(faktor_zoom)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / faktor_zoom)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _seret:
		_gerak(event.relative)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_jari[event.index] = event.position
		else:
			_jari.erase(event.index)
			if _jari.size() < 2:
				_jarak_pinch = 0.0
		return

	if event is InputEventScreenDrag:
		_jari[event.index] = event.position
		if _jari.size() >= 2:
			_pinch()
		elif _jari.size() == 1:
			_gerak(event.relative)


func _zoom(faktor: float) -> void:
	if not is_instance_valid(_kamera_peta):
		return
	var z: float = clampf(_kamera_peta.zoom.x * faktor, zoom_min, zoom_max)
	_kamera_peta.zoom = Vector2(z, z)


func _gerak(relative: Vector2) -> void:
	if not is_instance_valid(_kamera_peta):
		return
	_kamera_peta.global_position -= relative / _kamera_peta.zoom.x
	_kemaskin_had()


func _pinch() -> void:
	if not is_instance_valid(_kamera_peta):
		return
	var nilai: Array = _jari.values()
	if nilai.size() < 2:
		return
	var p1: Vector2 = nilai[0]
	var p2: Vector2 = nilai[1]
	var jarak: float = p1.distance_to(p2)
	if _jarak_pinch <= 0.0:
		_jarak_pinch = jarak
		return
	if jarak > 0.0:
		_zoom(jarak / _jarak_pinch)
	_jarak_pinch = jarak


func _kemaskin_had() -> void:
	if not is_instance_valid(_kamera_peta):
		return
	var pos: Vector2 = _kamera_peta.global_position
	pos.x = clampf(pos.x, had_peta.position.x, had_peta.end.x)
	pos.y = clampf(pos.y, had_peta.position.y, had_peta.end.y)
	_kamera_peta.global_position = pos
