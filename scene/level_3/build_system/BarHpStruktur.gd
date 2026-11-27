class_name BarHpStruktur
extends Node2D

## Bar HP kekal di atas struktur pangkalan (dinding/pintu/perabot) yang rosak
## akibat serangan husk. Ia TIDAK pudar, jadi selepas raid player boleh nampak
## struktur mana yang sudah cedera dan berapa baki HP-nya.
##
## Satu bar sahaja bagi setiap struktur: serangan seterusnya mengemas kini bar
## yang sama. Bar hidup sebagai anak kepada struktur itu sendiri, jadi ia
## hilang serta-merta bersama struktur apabila dirobohkan atau dimusnahkan.

const LEBAR: float = 22.0
const TINGGI: float = 4.0
const JARAK_ATAS: float = 15.0
const KUNCI_META: String = "bar_hp_struktur"

const SAIZ_TEKS: int = 6
const WARNA_TEKS: Color = Color(1.0, 1.0, 1.0, 0.95)

const WARNA_LATAR: Color = Color(0.04, 0.05, 0.08, 0.85)
const WARNA_PENUH: Color = Color(0.45, 1.0, 0.55)
const WARNA_SEDERHANA: Color = Color(1.0, 0.85, 0.35)
const WARNA_KRITIKAL: Color = Color(1.0, 0.42, 0.36)

var baki: int = 1
var maksimum: int = 1

var _sasaran: Node2D = null

# Tunjuk atau segarkan bar HP untuk sesuatu struktur.
static func papar(sasaran: Node2D, hp_baki: int, hp_maks: int) -> void:
	if sasaran == null or not is_instance_valid(sasaran):
		return

	var bar: BarHpStruktur = null
	if sasaran.has_meta(KUNCI_META):
		var lama: Variant = sasaran.get_meta(KUNCI_META)
		if lama is BarHpStruktur and is_instance_valid(lama):
			bar = lama

	if bar == null:
		bar = BarHpStruktur.new()
		bar.name = "BarHpStruktur"
		bar.z_index = 50
		# top_level: bar tak ikut putaran/skala struktur, cuma posisinya.
		bar.top_level = true
		sasaran.add_child(bar)
		sasaran.set_meta(KUNCI_META, bar)

	bar._sasaran = sasaran
	bar.tetapkan(hp_baki, hp_maks)

# Buang bar HP serta-merta (dipakai bila struktur dirobohkan/dimusnahkan).
static func buang(sasaran: Node) -> void:
	if sasaran == null or not is_instance_valid(sasaran):
		return
	if not sasaran.has_meta(KUNCI_META):
		return
	var lama: Variant = sasaran.get_meta(KUNCI_META)
	sasaran.remove_meta(KUNCI_META)
	if lama is BarHpStruktur and is_instance_valid(lama):
		lama.queue_free()

func tetapkan(hp_baki: int, hp_maks: int) -> void:
	baki = maxi(0, hp_baki)
	maksimum = maxi(1, hp_maks)
	if _sasaran != null and is_instance_valid(_sasaran):
		global_position = _sasaran.global_position
	queue_redraw()

func _process(_delta: float) -> void:
	if _sasaran != null and is_instance_valid(_sasaran):
		global_position = _sasaran.global_position

# Teks baki HP, contoh "1/2" (dipaparkan di tengah bar).
func teks_hp() -> String:
	return "%d/%d" % [baki, maksimum]

func _draw() -> void:
	var nisbah: float = clampf(float(baki) / float(maksimum), 0.0, 1.0)
	var y: float = -JARAK_ATAS - TINGGI
	# Bingkai gelap supaya bar jelas di atas asteroid yang terang.
	draw_rect(Rect2(-LEBAR * 0.5 - 1.0, y - 1.0, LEBAR + 2.0, TINGGI + 2.0), WARNA_LATAR)
	var warna: Color = WARNA_PENUH
	if nisbah <= 0.34:
		warna = WARNA_KRITIKAL
	elif nisbah <= 0.67:
		warna = WARNA_SEDERHANA
	if nisbah > 0.0:
		draw_rect(Rect2(-LEBAR * 0.5, y, LEBAR * nisbah, TINGGI), warna)

	# Baki HP kecil di tengah bar (saiz bar tak berubah).
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var teks := teks_hp()
	var saiz: Vector2 = font.get_string_size(teks, HORIZONTAL_ALIGNMENT_LEFT, -1, SAIZ_TEKS)
	var asas_y: float = y + TINGGI * 0.5 \
		+ (font.get_ascent(SAIZ_TEKS) - font.get_descent(SAIZ_TEKS)) * 0.5
	var pos_teks := Vector2(-saiz.x * 0.5, asas_y)
	# Garis luar gelap supaya angka masih jelas bila bar hijau terang.
	draw_string_outline(font, pos_teks, teks, HORIZONTAL_ALIGNMENT_LEFT, -1, SAIZ_TEKS, 2,
		Color(0.03, 0.04, 0.06, 0.9))
	draw_string(font, pos_teks, teks, HORIZONTAL_ALIGNMENT_LEFT, -1, SAIZ_TEKS, WARNA_TEKS)
