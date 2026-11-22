class_name Asteroid
extends Node2D

## Asteroid besar — BUKAN meteorit yang boleh dilombong. Ia bongkah batu pejal
## yang TIDAK menghalang pemain: tiada kolider, jadi pemain boleh terbang
## terus menembusinya dan berada di ruang dalamnya untuk membina pangkalan.
##
## Semakan bentuk menggunakan poligon sebenar asteroid (bukan bulatan,
## silinder atau kotak), jadi kawasan bina dan pengesanan "di dalam asteroid"
## mengikut lekuk batu yang dilukis.

@export var jejari: float = 150.0
@export var bilangan_sisi: int = 28
## Jarak ke dalam dari tepi batu. Tile grid mesti berada sekurang-kurangnya
## sejauh ini dari tepi supaya ia tidak tergantung di luar asteroid.
@export var ketebalan: float = 26.0
@export var warna_batu: Color = Color(0.15, 0.18, 0.25, 1.0)
@export var warna_tepi: Color = Color(0.36, 0.72, 0.95, 0.55)
## Tukar state pemain (Base di dalam / Angkasa di luar) secara automatik.
@export var tukar_state_pemain: bool = true

@onready var _permukaan: Polygon2D = get_node_or_null("Permukaan") as Polygon2D
@onready var _tepi: Line2D = get_node_or_null("Tepi") as Line2D
@onready var _tepi_glow: Line2D = get_node_or_null("TepiGlow") as Line2D

## Saiz tekstur permukaan batu (asteroid_surface.png) dalam piksel.
const SAIZ_TEKSTUR: float = 1024.0

var _poligon: PackedVector2Array = PackedVector2Array()
var _poligon_dalam: PackedVector2Array = PackedVector2Array()

var _pemain: Node2D = null
var _pemain_dalam: bool = false

func _ready() -> void:
	add_to_group("Asteroid")
	_bina_bentuk()

func _bina_bentuk() -> void:
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

	# Tiada StaticBody2D / CollisionPolygon2D di sini dengan sengaja: asteroid
	# tidak menyekat pemain, jadi pemain boleh terbang masuk terus.
	_kemas_kini_rupa()
	queue_redraw()

# Isi bentuk batu dengan tekstur permukaan (kawah, habuk, rekahan) dan
# selaraskan garis tepi dengan poligon yang sama.
func _kemas_kini_rupa() -> void:
	if _poligon.size() < 3:
		return

	if _permukaan:
		_permukaan.polygon = _poligon
		# Petakan SATU tekstur penuh merentasi batu supaya kawah tidak berulang.
		var r_maks: float = 1.0
		for p in _poligon:
			r_maks = maxf(r_maks, p.length())
		var skala: float = SAIZ_TEKSTUR / (2.0 * r_maks)
		_permukaan.texture_scale = Vector2(skala, skala)
		_permukaan.texture_offset = Vector2(SAIZ_TEKSTUR * 0.5, SAIZ_TEKSTUR * 0.5)

	if _tepi:
		_tepi.points = _poligon
		_tepi.default_color = warna_tepi
	if _tepi_glow:
		_tepi_glow.points = _poligon

func _draw() -> void:
	if _poligon.size() < 3:
		return
	# Warna asas di bawah tekstur: pastikan tiada lubang jika tekstur gagal dimuat.
	draw_colored_polygon(_poligon, warna_batu)

# Bolehkah tile dibina pada posisi dunia ini? Dipanggil oleh BuildGrid.
# Ikut bentuk sebenar batu: tile mesti berada dalam kawasan dalam asteroid.
func boleh_bina_di(pos_dunia: Vector2) -> bool:
	return dalam_asteroid(pos_dunia)

# Adakah posisi dunia ini berada di dalam asteroid?
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
