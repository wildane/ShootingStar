class_name HpBar
extends Control

## Bar status bergaya: kotak gelap bulat + ikon + isian berwarna + teks "3/5".
## Jenis: "hp" (ikon hati merah) dan "energi" (ikon kilat kuning, bar biru).
## Boleh papar teks tambahan di sebelah kanan dalam kotak (cth: "0.1/s").

const SAIZ_PEMAIN: Vector2 = Vector2(120.0, 17.0)
const FON_PEMAIN: int = 8
const SAIZ_MUSUH: Vector2 = Vector2(62.0, 12.0)
const FON_MUSUH: int = 6

const WARNA_SIHAT: Color = Color(0.42, 0.93, 0.52)
const WARNA_SEDERHANA: Color = Color(1.0, 0.78, 0.28)
const WARNA_KRITIKAL: Color = Color(1.0, 0.32, 0.32)
const WARNA_TENAGA_BAR: Color = Color(0.29, 0.62, 1.0)
const WARNA_LATAR: Color = Color(0.05, 0.07, 0.12, 0.72)
const WARNA_JIDAR: Color = Color(0.55, 0.78, 0.95, 0.55)
const WARNA_HATI: Color = Color(1.0, 0.24, 0.32)
const WARNA_KILAT: Color = Color(1.0, 0.85, 0.2)


## Ikon dilukis dengan kod supaya tak bergantung pada glyph fon.
class IkonBar:
	extends Control

	var jenis: String = "hp"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _lengkung_hati(pusat: Vector2, skala: float) -> PackedVector2Array:
		var titik := PackedVector2Array()
		var langkah := 40
		for i in langkah:
			var t := TAU * float(i) / float(langkah)
			var x := 16.0 * pow(sin(t), 3.0)
			var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
			titik.append(pusat + Vector2(x, -y) * skala)
		return titik

	func _lengkung_kilat(pusat: Vector2, skala: float) -> PackedVector2Array:
		var bentuk: Array[Vector2] = [
			Vector2(13, 2), Vector2(4, 14), Vector2(11, 14),
			Vector2(9, 22), Vector2(20, 10), Vector2(13, 10),
		]
		var titik := PackedVector2Array()
		for b in bentuk:
			titik.append(pusat + (b - Vector2(12, 12)) * skala)
		return titik

	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s <= 0.0:
			return
		var pusat := size * 0.5
		var skala := s / 26.0

		if jenis == "energi":
			var luar := PackedVector2Array()
			for p in _lengkung_kilat(pusat, skala * 1.18):
				luar.append(pusat + (p - pusat) * 1.18)
			draw_colored_polygon(luar, Color(0.06, 0.05, 0.01, 0.9))
			draw_colored_polygon(_lengkung_kilat(pusat, skala), WARNA_KILAT)
		else:
			draw_colored_polygon(_lengkung_hati(pusat, skala * 1.25), Color(0.08, 0.02, 0.03, 0.9))
			draw_colored_polygon(_lengkung_hati(pusat, skala), WARNA_HATI)


var saiz_bar: Vector2 = SAIZ_PEMAIN
var saiz_fon: int = FON_PEMAIN
var jenis: String = "hp"
var jidar: float = 3.5

var _panel: Panel
var _bar: ProgressBar
var _teks: Label
var _teks_kanan: Label
var _ikon: IkonBar
var _lebar_ikon: float = 0.0
var _kiri_kandungan: float = 0.0
var _kanan_semasa: String = ""
var _nisbah_semasa: float = -1.0
var _tween_bar: Tween = null
var _tween_kilat: Tween = null

## Cipta bar dengan saiz dan jenis yang ditetapkan (sebelum masuk tree).
static func cipta(p_saiz: Vector2, p_fon: int, p_jenis: String = "hp") -> HpBar:
	var b := HpBar.new()
	b.saiz_bar = p_saiz
	b.saiz_fon = p_fon
	b.jenis = p_jenis
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

	# Saiz & posisi ikon (dibuat selepas bar supaya dilukis di atasnya)
	_lebar_ikon = maxf(4.0, saiz_bar.y * 0.40)
	var tinggi_ikon := maxf(4.0, (saiz_bar.y - jidar * 2.0) * 0.64)
	var posisi_ikon := Vector2(jidar + 1.0, (saiz_bar.y - tinggi_ikon) * 0.5)
	_kiri_kandungan = posisi_ikon.x + _lebar_ikon + 2.0

	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.value = 1.0
	_bar.add_theme_stylebox_override("background", _gaya_trek())
	_bar.add_theme_stylebox_override("fill", _gaya_isian(_warna_untuk(1.0)))
	# Bar warna penuhkan seluruh kotak (di belakang ikon & teks)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar.offset_left = jidar
	_bar.offset_top = jidar - 1.0
	_bar.offset_right = -jidar
	_bar.offset_bottom = -jidar + 1.0
	_panel.add_child(_bar)

	# Ikon di sebelah kiri, di atas bar berwarna
	_ikon = IkonBar.new()
	_ikon.jenis = jenis
	_ikon.size = Vector2(_lebar_ikon, tinggi_ikon)
	_ikon.position = posisi_ikon
	_panel.add_child(_ikon)

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
	_teks.offset_left = _kiri_kandungan
	_panel.add_child(_teks)

	# Teks tambahan di sebelah kanan (cth kadar cas)
	_teks_kanan = Label.new()
	_teks_kanan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_teks_kanan.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_teks_kanan.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_teks_kanan.add_theme_font_size_override("font_size", maxi(6, saiz_fon - 1))
	_teks_kanan.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0, 1.0))
	_teks_kanan.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 1))
	_teks_kanan.add_theme_constant_override("outline_size", 3)
	_teks_kanan.text = ""
	_teks_kanan.visible = false
	_teks_kanan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_teks_kanan.offset_right = -jidar - 1.0
	_teks_kanan.offset_left = _kiri_kandungan
	_panel.add_child(_teks_kanan)

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
	if jenis == "energi":
		return WARNA_TENAGA_BAR
	if nisbah > 0.6:
		return WARNA_SIHAT
	elif nisbah > 0.3:
		return WARNA_SEDERHANA
	return WARNA_KRITIKAL

func _lebar_teks_kanan(teks: String) -> float:
	if teks == "":
		return 0.0
	var fon := _teks_kanan.get_theme_font("font")
	var saiz := _teks_kanan.get_theme_font_size("font_size")
	if fon == null:
		return 16.0
	return fon.get_string_size(teks, HORIZONTAL_ALIGNMENT_LEFT, -1, saiz).x + 3.0

## Kemas kini paparan bar. `kanan` (pilihan) ialah teks kecil di sebelah kanan.
func tetapkan(nisbah: float, teks: String, kanan: String = "") -> void:
	if _panel == null:
		_bina()
	if _teks == null:
		return

	if teks != _teks.text:
		_teks.text = teks

	if kanan != _kanan_semasa:
		_kanan_semasa = kanan
		_teks_kanan.text = kanan
		_teks_kanan.visible = kanan != ""
		var simpanan := _lebar_teks_kanan(kanan)
		# Hanya teks yang dibuat ruang; bar kekal penuh di belakang
		_teks.offset_right = -jidar - simpanan

	var nisbah_baru := clampf(nisbah, 0.0, 1.0)
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
