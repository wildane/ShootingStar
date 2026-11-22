class_name Asteroid
extends Node2D

## Asteroid besar — BUKAN meteorit yang boleh dilombong. Ia cangkerang batu
## berongga dengan satu mulut gua, jadi pemain boleh terbang masuk ke ruang
## kosong di dalam dan membina pangkalan di situ.
##
## Semua semakan bentuk menggunakan poligon sebenar asteroid (bukan bulatan,
## silinder atau kotak), jadi kawasan bina dan pengesanan "di dalam asteroid"
## mengikut lekuk batu yang dilukis.

@export var jejari: float = 150.0
@export var bilangan_sisi: int = 28
## Tebal cangkerang batu. Ruang di dalamnya ialah kawasan pangkalan.
@export var ketebalan: float = 26.0
## Arah dan lebar mulut gua (darjah). Mulut inilah jalan masuk pemain.
@export var lubang_sudut_deg: float = -20.0
@export var lubang_lebar_deg: float = 56.0
@export var warna_batu: Color = Color(0.15, 0.18, 0.25, 1.0)
@export var warna_tepi: Color = Color(0.36, 0.72, 0.95, 0.55)
@export var warna_ruang: Color = Color(0.03, 0.05, 0.09, 1.0)
@export var warna_mulut: Color = Color(0.36, 0.85, 1.0, 0.75)
## Tukar state pemain (Base di dalam / Angkasa di luar) secara automatik.
@export var tukar_state_pemain: bool = true

var _poligon: PackedVector2Array = PackedVector2Array()
var _poligon_dalam: PackedVector2Array = PackedVector2Array()

var _pemain: Node2D = null
var _pemain_dalam: bool = false

func _ready() -> void:
	add_to_group("Asteroid")
	_bina_bentuk()

func _bina_bentuk() -> void:
	var lama := get_node_or_null("Badan")
	if lama:
		lama.queue_free()

	_poligon = PackedVector2Array()
	_poligon_dalam = PackedVector2Array()
	for i in range(bilangan_sisi):
		var sudut: float = TAU * float(i) / float(bilangan_sisi)
		# Sedikit tak seragam supaya nampak seperti batu, bukan bulatan sempurna.
		var r: float = jejari * (1.0 + 0.09 * sin(sudut * 3.0 + 0.7) + 0.05 * cos(sudut * 5.0))
		var r_dalam: float = maxf(r - ketebalan, jejari * 0.15)
		var arah := Vector2(cos(sudut), sin(sudut))
		_poligon.append(arah * r)
		_poligon_dalam.append(arah * r_dalam)

	var badan := StaticBody2D.new()
	badan.name = "Badan"
	# Layer 4 (nilai 8) = environment, sama seperti meteorit. Pemain
	# (collision_mask 10) berlanggar dengan layer ini.
	badan.collision_layer = 8
	badan.collision_mask = 0
	add_child(badan)

	# Cangkerang dibina sebagai kepingan antara dua sisi berturutan, kecuali
	# di mulut gua. Kepingan bersambung tepat pada bucu yang sama, jadi tidak
	# ada celah untuk pemain terlepas keluar.
	for i in range(bilangan_sisi):
		if _di_mulut(i):
			continue
		var j: int = (i + 1) % bilangan_sisi
		var bentuk := CollisionPolygon2D.new()
		bentuk.polygon = PackedVector2Array([
			_poligon[i], _poligon[j], _poligon_dalam[j], _poligon_dalam[i],
		])
		badan.add_child(bentuk)

	queue_redraw()

# Adakah kepingan cangkerang ke-i berada di kawasan mulut gua?
func _di_mulut(i: int) -> bool:
	var tengah_sisi: float = TAU * (float(i) + 0.5) / float(bilangan_sisi)
	var beza: float = absf(angle_difference(deg_to_rad(lubang_sudut_deg), tengah_sisi))
	return beza <= deg_to_rad(lubang_lebar_deg) * 0.5

func _draw() -> void:
	if _poligon.size() < 3:
		return

	# Batu cangkerang
	draw_colored_polygon(_poligon, warna_batu)
	# Ruang kosong di dalam (kawasan pangkalan)
	draw_colored_polygon(_poligon_dalam, warna_ruang)

	var tutup := _poligon.duplicate()
	tutup.append(_poligon[0])
	draw_polyline(tutup, warna_tepi, 3.0, true)
	draw_polyline(tutup, Color(0.55, 0.88, 1.0, 0.12), 9.0, true)

	var tutup_dalam := _poligon_dalam.duplicate()
	tutup_dalam.append(_poligon_dalam[0])
	draw_polyline(tutup_dalam, Color(0.28, 0.6, 0.78, 0.8), 2.0, true)

	# Mulut gua: buang batu di situ supaya lubang masuk jelas kelihatan.
	for i in range(bilangan_sisi):
		if not _di_mulut(i):
			continue
		var j: int = (i + 1) % bilangan_sisi
		var keping := PackedVector2Array([
			_poligon[i], _poligon[j], _poligon_dalam[j], _poligon_dalam[i],
		])
		draw_colored_polygon(keping, warna_ruang)
		var garis := keping.duplicate()
		garis.append(keping[0])
		draw_polyline(garis, warna_mulut, 2.0, true)

# Bolehkah tile dibina pada posisi dunia ini? Dipanggil oleh BuildGrid.
# Ikut bentuk sebenar batu: tile mesti berada dalam poligon dalam asteroid.
func boleh_bina_di(pos_dunia: Vector2) -> bool:
	return dalam_asteroid(pos_dunia)

# Adakah posisi dunia ini berada di ruang dalam asteroid?
func dalam_asteroid(pos_dunia: Vector2) -> bool:
	if _poligon_dalam.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(to_local(pos_dunia), _poligon_dalam)

# ==========================================
# TUKAR STATE PEMAIN (dalam = Base, luar = Angkasa)
# ==========================================
func _physics_process(_delta: float) -> void:
	if not tukar_state_pemain:
		return

	var pemain := get_tree().get_first_node_in_group("Player") as Node2D
	if pemain == null or not is_instance_valid(pemain):
		_pemain = null
		return

	var dalam: bool = dalam_asteroid(pemain.global_position)
	if pemain != _pemain:
		# Kali pertama jumpa pemain: ikut posisi semasa tanpa tukar state,
		# supaya state awal level tidak terganggu.
		_pemain = pemain
		_pemain_dalam = dalam
		return

	if dalam == _pemain_dalam:
		return
	_pemain_dalam = dalam
	_tukar_state_pemain(pemain, dalam)

func _tukar_state_pemain(pemain: Node2D, ke_dalam: bool) -> void:
	var sm := pemain.get_node_or_null("StateMachine")
	if sm == null or not sm.has_method("tukar_state"):
		return
	var nama: String = "BaseState" if ke_dalam else "AngkasaState"
	var state_baru := sm.get_node_or_null(nama)
	if state_baru and sm.get("state_sekarang") != state_baru:
		sm.tukar_state(state_baru)
