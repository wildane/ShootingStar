extends Node2D

# ==========================================
# GELEMBUNG PERISAI MAGNETIK (RAPAT PADA BENTUK PEMAIN)
# ==========================================
# Node ini diurus oleh HealthComponent: dicipta sekali sebagai anak pemain,
# dipaparkan selagi masih ada Magnetic Shield dalam beg, dan berkilat setiap
# kali satu serangan diserap. Bentuknya elips bercahaya yang mengikut nisbah
# sprite pemain (kapal lebar dan rendah), bukan bulatan besar berlebih.

const WARNA_TERAS := Color(0.55, 1.0, 1.0, 1.0)
const WARNA_CAHAYA := Color(0.20, 0.80, 1.0, 1.0)
const SEGI_BULATAN := 40

# Jejari asas (piksel). HealthComponent menetapkannya ikut saiz sprite pemain.
@export var jejari_x: float = 14.0
@export var jejari_y: float = 10.0

var _masa: float = 0.0
var _kilat: float = 0.0

func _ready() -> void:
	# Mod tambah (additive) membuatkan cincin kelihatan bercahaya pada latar gelap.
	var bahan := CanvasItemMaterial.new()
	bahan.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = bahan
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	_masa += delta
	_kilat = maxf(_kilat - delta * 2.5, 0.0)
	queue_redraw()

# Dipanggil setiap kali serangan diserap: gelembung membesar dan menyala.
func kilat() -> void:
	_kilat = 1.0

# Titik-titik elips dengan jarak tambahan luar (untuk lapisan glow).
func _elips(jarak: float) -> PackedVector2Array:
	var titik := PackedVector2Array()
	for i in range(SEGI_BULATAN + 1):
		var sudut := TAU * float(i) / float(SEGI_BULATAN)
		titik.append(Vector2(
			cos(sudut) * (jejari_x + jarak),
			sin(sudut) * (jejari_y + jarak)
		))
	return titik

# Sebahagian elips (untuk kilauan cahaya yang berputar).
func _lengkok(mula: float, panjang: float) -> PackedVector2Array:
	var titik := PackedVector2Array()
	var langkah := 12
	for i in range(langkah + 1):
		var sudut := mula + panjang * (float(i) / float(langkah))
		titik.append(Vector2(cos(sudut) * jejari_x, sin(sudut) * jejari_y))
	return titik

func _draw() -> void:
	var denyut := sin(_masa * 3.0) * 0.5 + 0.5
	var r := 1.0 + 0.04 * denyut + 0.18 * _kilat
	var a := (0.70 + 0.30 * denyut) * (1.0 + 1.2 * _kilat)
	var rx := jejari_x * r
	var ry := jejari_y * r

	var teras := _elips(0.0)
	var asas := PackedVector2Array()
	for titik in teras:
		asas.append(Vector2(titik.x * (rx / jejari_x), titik.y * (ry / jejari_y)))
	asas[asas.size() - 1] = asas[0]

	# Isi lembut supaya bahagian dalam kelihatan seperti gelembung, bukan kosong.
	draw_colored_polygon(asas, Color(WARNA_CAHAYA, 0.05 * a))

	# Lapisan cahaya di luar cincin (kian pudar) untuk kesan glow.
	for i in range(3):
		var lapisan := _elips(0.8 + float(i) * 1.0)
		for j in range(lapisan.size()):
			lapisan[j] = Vector2(lapisan[j].x * (rx / jejari_x), lapisan[j].y * (ry / jejari_y))
		var alfa := (0.14 - 0.035 * float(i)) * a
		draw_polyline(lapisan, Color(WARNA_CAHAYA, alfa), 1.6, true)

	# Cincin teras yang tajam.
	draw_polyline(asas, Color(WARNA_TERAS, 0.85 * a), 1.2, true)

	# Kilauan berputar: sorotan cahaya yang bergerak mengelilingi gelembung.
	var mula := _masa * 2.0
	var sorot := _lengkok(mula, 0.7)
	for k in range(sorot.size()):
		sorot[k] = Vector2(sorot[k].x * (rx / jejari_x), sorot[k].y * (ry / jejari_y))
	draw_polyline(sorot, Color(WARNA_TERAS, 0.55 * a), 1.6, true)
