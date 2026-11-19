extends Node2D

## Kesan visual bila sesiapa (pemain atau robot pekerja) teleport melalui pintu.
## Semua grafik dilukis dalam kod, tiada aset imej baru.
##
## doorway_actual.gd mainkan dua ketul kesan setiap kali teleport:
##   muncul = false -> di tempat asal, cincin mengecil masuk (badan "hilang")
##   muncul = true  -> di tempat baru, cincin merebak keluar (badan "muncul")
##
## Node ini hidup sendiri: selepas tempohnya habis ia queue_free(), jadi
## pemanggil tidak perlu simpan rujukan.

const TEMPOH_LENYAP: float = 0.28
const TEMPOH_MUNCUL: float = 0.42
const BILANGAN_PERCIKAN: int = 12    # bilangan percikan setiap ketul kesan
const JEJARI_MAKS: float = 24.0
const TINGGI_LAJUR: float = 26.0

@export var warna_utama: Color = Color(0.55, 0.95, 1.0)   # sian pucat
@export var warna_teras: Color = Color(1.0, 1.0, 1.0)     # putih kilau

var muncul: bool = true

var _masa: float = 0.0
var _tempoh: float = TEMPOH_MUNCUL
var _percikan: Array = []

func _ready() -> void:
	z_index = 40
	z_as_relative = false
	_tempoh = TEMPOH_MUNCUL if muncul else TEMPOH_LENYAP
	_sedia_percikan()
	queue_redraw()

func _process(delta: float) -> void:
	_masa += delta
	if _masa >= _tempoh:
		queue_free()
		return
	queue_redraw()

# Percikan kecil yang menyebar keluar dari pusat, arah rawak supaya setiap
# teleport nampak sedikit berbeza.
func _sedia_percikan() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in BILANGAN_PERCIKAN:
		var arah := Vector2.RIGHT.rotated(rng.randf() * TAU)
		_percikan.append({
			"arah": arah,
			"laju": rng.randf_range(0.75, 1.3),
			"saiz": rng.randf_range(0.7, 1.7),
		})

func _draw() -> void:
	var t: float = clampf(_masa / _tempoh, 0.0, 1.0)
	var kendur: float = (1.0 - t) * (1.0 - t)        # pudar cepat di hujung
	var kilau: float = pow(1.0 - t, 4.0)             # kilau teras paling singkat

	# 1) Percikan keluar
	for p in _percikan:
		var arah: Vector2 = p["arah"]
		var jarak: float = lerpf(4.0, JEJARI_MAKS * 1.15, t) * float(p["laju"])
		var saiz: float = float(p["saiz"]) * (1.0 - t) + 0.3
		draw_circle(arah * jarak, saiz, _warna(warna_utama, 0.9 * kendur))

	# 2) Cincin luar: merebak keluar bila muncul, mengecil masuk bila lenyap
	var jejari: float = lerpf(2.0, JEJARI_MAKS, t) if muncul else lerpf(JEJARI_MAKS, 2.0, t)
	draw_arc(
		Vector2.ZERO, jejari, 0.0, TAU, 32,
		_warna(warna_utama, 0.95 * kendur), 1.6, true
	)

	# 3) Cincin dalam yang ketinggalan sedikit -> rasa gelombang berganda
	var jejari2: float = jejari * 0.6
	draw_arc(
		Vector2.ZERO, jejari2, 0.0, TAU, 28,
		_warna(warna_teras, 0.75 * kendur), 1.0, true
	)

	# 4) Lajur cahaya menegak, menirus bila kesan hampir habis
	var tinggi: float = TINGGI_LAJUR * (0.35 + 0.65 * t)
	var lebar: float = 0.4 + 1.6 * (1.0 - t)
	draw_line(
		Vector2(0.0, -tinggi), Vector2(0.0, tinggi),
		_warna(warna_teras, 0.75 * kilau), lebar, true
	)

	# 5) Kilauan teras di pusat badan
	draw_circle(Vector2.ZERO, maxf(0.5, 7.0 * (1.0 - t)), _warna(warna_teras, 0.85 * kilau))


# Warna dengan alpha diganti tanpa mengubah warna asal.
func _warna(asas: Color, alpa: float) -> Color:
	return Color(asas.r, asas.g, asas.b, clampf(alpa, 0.0, 1.0))