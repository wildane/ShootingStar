class_name BarHpStruktur
extends Node2D

## Bar HP kecil di atas struktur pangkalan (dinding/pintu/perabot) yang baru
## kena serangan husk. Muncul serta-merta dengan baki HP semasa, kekal beberapa
## saat, kemudian pudar dan membebaskan dirinya sendiri.
##
## Satu bar sahaja bagi setiap struktur: serangan seterusnya mengemas kini bar
## yang sama (bukan bertindan). Bar hidup sebagai anak kepada induk struktur,
## jadi ia turut hilang bila strukturnya musnah.

const MASA_PAPAR: float = 3.0
const MASA_PUDAR: float = 0.8
const LEBAR: float = 22.0
const TINGGI: float = 4.0
const JARAK_ATAS: float = 15.0
const KUNCI_META: String = "bar_hp_struktur"

const WARNA_LATAR: Color = Color(0.04, 0.05, 0.08, 0.85)
const WARNA_PENUH: Color = Color(0.45, 1.0, 0.55)
const WARNA_SEDERHANA: Color = Color(1.0, 0.85, 0.35)
const WARNA_KRITIKAL: Color = Color(1.0, 0.42, 0.36)

var baki: int = 1
var maksimum: int = 1
## Struktur yang diikut bar ini (posisi dikemas kini tiap frame).
var sasaran: Node2D = null

var _masa: float = 0.0

# Tunjuk atau segarkan bar HP untuk sesuatu struktur.
# sasaran mesti Node2D yang sudah berada dalam scene.
static func papar(sasaran: Node2D, hp_baki: int, hp_maks: int) -> void:
	if sasaran == null or not is_instance_valid(sasaran):
		return

	var bar: BarHpStruktur = null
	if sasaran.has_meta(KUNCI_META):
		var lama: Variant = sasaran.get_meta(KUNCI_META)
		if lama is BarHpStruktur and is_instance_valid(lama):
			bar = lama

	if bar == null:
		var induk: Node = sasaran.get_parent()
		if induk == null:
			induk = sasaran
		bar = BarHpStruktur.new()
		bar.name = "BarHpStruktur"
		bar.z_index = 50
		induk.add_child(bar)
		sasaran.set_meta(KUNCI_META, bar)

	bar.sasaran = sasaran
	bar.tetapkan(hp_baki, hp_maks)

func tetapkan(hp_baki: int, hp_maks: int) -> void:
	baki = maxi(0, hp_baki)
	maksimum = maxi(1, hp_maks)
	_masa = 0.0
	modulate.a = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if sasaran != null:
		if not is_instance_valid(sasaran):
			queue_free()
			return
		global_position = sasaran.global_position

	_masa += delta
	if _masa > MASA_PAPAR:
		modulate.a = clampf(1.0 - (_masa - MASA_PAPAR) / MASA_PUDAR, 0.0, 1.0)
		if modulate.a <= 0.0:
			queue_free()

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
