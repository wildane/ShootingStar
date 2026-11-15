extends Control

## HUD HP pemain kekal di bahagian atas skrin:
## kotak gelap bulat + bar berwarna + teks "7/10".

const SAIZ_PANEL: Vector2 = Vector2(132.0, 22.0)
const JIDAR_BAR: float = 4.0

const WARNA_SIHAT: Color = Color(0.42, 0.93, 0.52)
const WARNA_SEDERHANA: Color = Color(1.0, 0.78, 0.28)
const WARNA_KRITIKAL: Color = Color(1.0, 0.32, 0.32)
const WARNA_LATAR: Color = Color(0.05, 0.07, 0.12, 0.72)
const WARNA_JIDAR: Color = Color(0.55, 0.78, 0.95, 0.55)

var _panel: Panel
var _bar: ProgressBar
var _teks: Label

var _nisbah_semasa: float = -1.0
var _tween_bar: Tween = null
var _tween_kilat: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bina()

func _bina() -> void:
	var tengah := CenterContainer.new()
	tengah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tengah.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tengah)

	_panel = Panel.new()
	_panel.custom_minimum_size = SAIZ_PANEL
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _gaya_panel())
	tengah.add_child(_panel)

	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.value = 1.0
	_bar.add_theme_stylebox_override("background", _gaya_trek())
	_bar.add_theme_stylebox_override("fill", _gaya_isian(WARNA_SIHAT))
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar.offset_left = JIDAR_BAR
	_bar.offset_top = JIDAR_BAR - 1.0
	_bar.offset_right = -JIDAR_BAR
	_bar.offset_bottom = -JIDAR_BAR + 1.0
	_panel.add_child(_bar)

	_teks = Label.new()
	_teks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_teks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_teks.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_teks.add_theme_font_size_override("font_size", 9)
	_teks.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_teks.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 1))
	_teks.add_theme_constant_override("outline_size", 3)
	_teks.text = "--/--"
	_teks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_teks)

func _gaya_panel() -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = WARNA_LATAR
	gaya.set_corner_radius_all(7)
	gaya.set_border_width_all(1)
	gaya.border_color = WARNA_JIDAR
	gaya.shadow_color = Color(0, 0, 0, 0.45)
	gaya.shadow_size = 2
	gaya.shadow_offset = Vector2(0, 1)
	return gaya

func _gaya_trek() -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	gaya.set_corner_radius_all(4)
	return gaya

func _gaya_isian(warna: Color) -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = warna
	gaya.set_corner_radius_all(4)
	gaya.border_width_top = 1
	gaya.border_color = warna.lightened(0.35)
	return gaya

func _warna_untuk(nisbah: float) -> Color:
	if nisbah > 0.6:
		return WARNA_SIHAT
	elif nisbah > 0.3:
		return WARNA_SEDERHANA
	return WARNA_KRITIKAL

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		_set_nisbah(0.0, "--/--")
		return

	var hc: Node = player.get_node_or_null("HealthComponent")
	if hc == null or not ("hp" in hc) or not ("max_hp" in hc):
		_set_nisbah(0.0, "--/--")
		return

	var hp_sekarang: int = max(int(hc.hp), 0)
	var hp_maks: int = max(int(hc.max_hp), 1)
	var nisbah := clampf(float(hp_sekarang) / float(hp_maks), 0.0, 1.0)
	_set_nisbah(nisbah, "%d/%d" % [hp_sekarang, hp_maks])

func _set_nisbah(nisbah: float, teks: String) -> void:
	var berubah := not is_equal_approx(nisbah, _nisbah_semasa)
	if teks != _teks.text:
		_teks.text = teks

	if not berubah:
		return

	# Kilat lembut bila HP turun (kena damage)
	if _nisbah_semasa >= 0.0 and nisbah < _nisbah_semasa:
		_kilat()

	_nisbah_semasa = nisbah
	_bar.add_theme_stylebox_override("fill", _gaya_isian(_warna_untuk(nisbah)))

	if _tween_bar and _tween_bar.is_valid():
		_tween_bar.kill()
	_tween_bar = create_tween()
	_tween_bar.tween_property(_bar, "value", nisbah, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _kilat() -> void:
	if _tween_kilat and _tween_kilat.is_valid():
		_tween_kilat.kill()
	_panel.modulate = Color(1.6, 1.6, 1.6, 1.0)
	_tween_kilat = create_tween()
	_tween_kilat.tween_property(_panel, "modulate", Color.WHITE, 0.22)
