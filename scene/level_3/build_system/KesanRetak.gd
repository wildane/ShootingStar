extends Node2D

## Retak visual pada perabot/struktur yang cedera kena serangan. Sama seperti
## BarHpStruktur: satu nod sahaja bagi setiap struktur, kekal sampai perabot
## dibaiki atau dimusnahkan. Retak dilukis secara prosedur (tiada aset imej),
## dan makin banyak HP hilang, makin banyak garis retak.

# Tanpa class_name: skrip ini dirujuk melalui preload sahaja supaya ia tetap
# berfungsi dalam ujian headless yang belum mendaftar cache kelas global.
const LALUAN_SKRIP: String = "res://scene/level_3/build_system/KesanRetak.gd"

const KUNCI_META: String = "kesan_retak"
const WARNA_GELAP: Color = Color(0.04, 0.03, 0.04, 0.85)
const WARNA_CERAH: Color = Color(0.9, 0.93, 1.0, 0.22)

## Saiz kawasan retak (ikut saiz sprite perabot).
var saiz: Vector2 = Vector2(24.0, 24.0)
## Bahagian HP yang sudah hilang (0.0 .. 1.0): tentukan berapa banyak retak.
var kadar: float = 0.5

static func papar(sasaran: Node2D, saiz_retak: Vector2, bahagian_rosak: float) -> void:
	if sasaran == null or not is_instance_valid(sasaran):
		return
	var retak: Node2D = null
	if sasaran.has_meta(KUNCI_META):
		var lama: Variant = sasaran.get_meta(KUNCI_META)
		if lama is Node2D and is_instance_valid(lama) and lama.get_script() == load(LALUAN_SKRIP):
			retak = lama
	if retak == null:
		retak = load(LALUAN_SKRIP).new()
		retak.name = "KesanRetak"
		retak.z_index = 49
		sasaran.add_child(retak)
		sasaran.set_meta(KUNCI_META, retak)
	retak.set("saiz", saiz_retak)
	retak.set("kadar", clampf(bahagian_rosak, 0.0, 1.0))
	retak.queue_redraw()

static func buang(sasaran: Node) -> void:
	if sasaran == null or not is_instance_valid(sasaran):
		return
	if not sasaran.has_meta(KUNCI_META):
		return
	var lama: Variant = sasaran.get_meta(KUNCI_META)
	sasaran.remove_meta(KUNCI_META)
	if lama is Node2D and is_instance_valid(lama):
		lama.queue_free()

func _draw() -> void:
	var setengah: Vector2 = saiz * 0.5
	var rng := RandomNumberGenerator.new()
	# Biji tetap ikut nod supaya bentuk retak tak berubah setiap kali redraw.
	rng.seed = int(get_instance_id())
	var garis: int = 2 + int(kadar * 3.0)
	for i in garis:
		var arah: float = rng.randf_range(0.0, TAU)
		var panjang: float = minf(saiz.x, saiz.y) * rng.randf_range(0.35, 0.6)
		var mula: Vector2 = Vector2(
			rng.randf_range(-setengah.x * 0.5, setengah.x * 0.5),
			rng.randf_range(-setengah.y * 0.5, setengah.y * 0.5))
		var hujung: Vector2 = mula + Vector2(cos(arah), sin(arah)) * panjang
		# Tiga segmen berketak-ketak supaya nampak macam retak, bukan garis lurus.
		var a: Vector2 = mula
		for j in 3:
			var b: Vector2 = a.lerp(hujung, 0.34)
			b += Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8))
			draw_line(a, b, WARNA_GELAP, 1.4)
			draw_line(a + Vector2(0.7, 0.7), b + Vector2(0.7, 0.7), WARNA_CERAH, 0.8)
			a = b
