class_name HpBar
extends Control

## Bar HP bergaya: kotak gelap bulat + isian berwarna + teks "3/5".
## Dipakai oleh HUD pemain (atas skrin) dan penunjuk HP musuh (atas musuh).

const SAIZ_PEMAIN: Vector2 = Vector2(104.0, 17.0)
const FON_PEMAIN: int = 8
const SAIZ_MUSUH: Vector2 = Vector2(62.0, 12.0)
const FON_MUSUH: int = 6

const WARNA_SIHAT: Color = Color(0.42, 0.93, 0.52)
const WARNA_SEDERHANA: Color = Color(1.0, 0.78, 0.28)
const WARNA_KRITIKAL: Color = Color(1.0, 0.32, 0.32)
const WARNA_LATAR: Color = Color(0.05, 0.07, 0.12, 0.72)
const WARNA_JIDAR: Color = Color(0.55, 0.78, 0.95, 0.55)

var saiz_bar: Vector2 = SAIZ_PEMAIN
var saiz_fon: int = FON_PEMAIN
var jidar: float = 3.5

var _panel: Panel
var _bar: ProgressBar
var _teks: Label
var _nisbah_semasa: float = -1.0
var _tween_bar: Tween = null
var _tween_kilat: Tween = null

## Cipta bar dengan saiz yang ditetapkan (sebelum masuk tree).
static func cipta(p_saiz: Vector2, p_fon: int) -> HpBar:
	var b := HpBar.new()
	b.saiz_bar = p_saiz
	b.saiz_fon = p_fon
	b.jidar = maxf(2.0, round(p_saiz.y * 0.2))
	return b

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bina()

func _bina() -> void:
	custom_minimum_size = saiz_bar
	size = saiz_bar

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _gaya_panel())
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

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
	_bar.offset_left = jidar
	_bar.offset_top = jidar - 1.0
	_bar.offset_right = -jidar
	_bar.offset_bottom = -jidar + 1.0
	_panel.add_child(_bar)

	_teks = Label.new()
	_teks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_teks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_teks.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_teks.add_theme_font_size_override("font_size", saiz_fon)
	_teks.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_teks.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 1))
	_teks.add_theme_constant_override("outline_size", 3)
	_teks.text = "--/--"
	_teks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_teks)

func _gaya_panel() -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = WARNA_LATAR
	gaya.set_corner_radius_all(int(maxf(4.0, saiz_bar.y * 0.32)))
	gaya.set_border_width_all(1)
	gaya.border_color = WARNA_JIDAR
	gaya.shadow_color = Color(0, 0, 0, 0.45)
	gaya.shadow_size = 2
	gaya.shadow_offset = Vector2(0, 1)
	return gaya

func _gaya_trek() -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	gaya.set_corner_radius_all(int(maxf(2.0, saiz_bar.y * 0.18)))
	return gaya

func _gaya_isian(warna: Color) -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = warna
	gaya.set_corner_radius_all(int(maxf(2.0, saiz_bar.y * 0.18)))
	gaya.border_width_top = 1
	gaya.border_color = warna.lightened(0.35)
	return gaya

func _warna_untuk(nisbah: float) -> Color:
	if nisbah > 0.6:
		return WARNA_SIHAT
	elif nisbah > 0.3:
		return WARNA_SEDERHANA
	return WARNA_KRITIKAL

## Kemas kini paparan bar. Bila HP turun, kotak berkilat sekejap.
func tetapkan(nisbah: float, teks: String) -> void:
	if _teks == null:
		return

	var nisbah_baru := clampf(nisbah, 0.0, 1.0)
	if teks != _teks.text:
		_teks.text = teks

	if is_equal_approx(nisbah_baru, _nisbah_semasa):
		return

	if _nisbah_semasa >= 0.0 and nisbah_baru < _nisbah_semasa:
		_kilat()

	_nisbah_semasa = nisbah_baru
	_bar.add_theme_stylebox_override("fill", _gaya_isian(_warna_untuk(nisbah_baru)))

	if _tween_bar and _tween_bar.is_valid():
		_tween_bar.kill()
	_tween_bar = create_tween()
	_tween_bar.tween_property(_bar, "value", nisbah_baru, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _kilat() -> void:
	if _tween_kilat and _tween_kilat.is_valid():
		_tween_kilat.kill()
	_panel.modulate = Color(1.6, 1.6, 1.6, 1.0)
	_tween_kilat = create_tween()
	_tween_kilat.tween_property(_panel, "modulate", Color.WHITE, 0.22)
