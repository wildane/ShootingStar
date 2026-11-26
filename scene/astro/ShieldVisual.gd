extends Node2D

# ==========================================
# GELEMBUNG PERISAI MAGNETIK (BULAT + BERCahaya)
# ==========================================
# Node ini diurus oleh HealthComponent: dicipta sekali sebagai anak pemain,
# dipaparkan selagi masih ada Magnetic Shield dalam beg, dan berkilat setiap
# kali satu serangan diserap. Bentuknya bulatan bercahaya mengelilingi pemain,
# bukan ikon item yang berbentuk petak.

const WARNA_TERAS := Color(0.55, 1.0, 1.0, 1.0)
const WARNA_CAHAYA := Color(0.20, 0.80, 1.0, 1.0)
const SEGI_BULATAN := 64

# Jejari asas dalam piksel; HealthComponent menetapkannya ikut saiz sprite.
@export var jejari: float = 18.0

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

func _draw() -> void:
	var denyut := sin(_masa * 3.0) * 0.5 + 0.5
	var r := jejari * (1.0 + 0.04 * denyut) * (1.0 + 0.18 * _kilat)
	var a := (0.70 + 0.30 * denyut) * (1.0 + 1.2 * _kilat)

	# Isi lembut supaya bahagian dalam kelihatan seperti gelembung, bukan kosong.
	draw_circle(Vector2.ZERO, r, Color(WARNA_CAHAYA, 0.05 * a))

	# Lapisan cahaya di luar cincin (kian pudar) untuk kesan glow.
	for i in range(5):
		var jarak := r + 1.0 + float(i) * 1.4
		var alfa := (0.16 - 0.028 * float(i)) * a
		draw_arc(Vector2.ZERO, jarak, 0.0, TAU, SEGI_BULATAN, Color(WARNA_CAHAYA, alfa), 2.2, true)

	# Cincin teras yang tajam.
	draw_arc(Vector2.ZERO, r, 0.0, TAU, SEGI_BULATAN, Color(WARNA_TERAS, 0.85 * a), 1.4, true)

	# Kilauan berputar: sorotan cahaya yang bergerak mengelilingi gelembung.
	var mula := _masa * 2.0
	draw_arc(Vector2.ZERO, r, mula, mula + 0.7, 20, Color(WARNA_TERAS, 0.55 * a), 2.0, true)
