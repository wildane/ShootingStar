extends Node2D

## Kesan visual semasa player dicas oleh Charging Station:
##   - ikon kilat kuning berkelip di atas kepala (sama bentuk dengan ikon
##     tenaga pada bar HUD: WARNA_KILAT di HpBar.gd)
##   - zarah kecil bercahaya menaik dari badan
##
## Node ini anak terus player, jadi ia ikut SpriteBase dan SpriteAngkasa.
## Kesan menyala selagi ada sumber cas, termasuk bila tenaga sudah penuh.

@export var warna: Color = Color(0.45, 0.95, 1.0)          # warna zarah
@export var warna_simbol: Color = Color(1.0, 0.85, 0.2)    # kuning ikon HUD
@export var saiz_simbol: float = 13.0                      # tinggi ikon kilat
@export var jarak_simbol: float = -30.0                    # atas kepala
@export var jumlah_zarah: int = 24
@export var saiz_zarah_min: float = 0.12
@export var saiz_zarah_max: float = 0.32
@export var kelajuan_denyut: float = 7.0
@export var ikut_sprite_aktif: bool = true

const TEKSTUR_ZARAH: String = "res://scene/astro/ChargeSpark.png"

var aktif: bool = false
var _masa: float = 0.0
var _zarah: CPUParticles2D = null

func _ready() -> void:
	visible = false
	z_index = 6
	set_process(true)
	_bina_zarah()

func _bina_zarah() -> void:
	_zarah = CPUParticles2D.new()
	_zarah.name = "ZarahCas"
	var tekstur = load(TEKSTUR_ZARAH)
	if tekstur != null:
		_zarah.texture = tekstur
	_zarah.amount = jumlah_zarah
	_zarah.lifetime = 0.8
	_zarah.preprocess = 0.35
	_zarah.direction = Vector2(0, -1)
	_zarah.spread = 28.0
	_zarah.gravity = Vector2(0, -25)
	_zarah.initial_velocity_min = 26.0
	_zarah.initial_velocity_max = 58.0
	_zarah.scale_amount_min = saiz_zarah_min
	_zarah.scale_amount_max = saiz_zarah_max
	_zarah.color = warna
	_zarah.position = Vector2(0, 8)
	_zarah.z_index = 5
	_zarah.emitting = false
	add_child(_zarah)

func _process(delta: float) -> void:
	if not aktif:
		if visible:
			visible = false
			if _zarah != null:
				_zarah.emitting = false
		return

	visible = true
	_masa += delta
	queue_redraw()

	if _zarah != null and not _zarah.emitting:
		_zarah.emitting = true

	if ikut_sprite_aktif:
		_ikut_sprite_aktif()

# Letak kesan pada sprite player yang sedang kelihatan supaya ikon
# berada di atas kepala yang betul dalam kedua-dua bentuk player.
func _ikut_sprite_aktif() -> void:
	var ibu := get_parent()
	if ibu == null:
		return

	var sprite: Node2D = null
	var base := ibu.get_node_or_null("SpriteBase") as Node2D
	if base != null and base.visible:
		sprite = base
	else:
		var angkasa := ibu.get_node_or_null("SpriteAngkasa") as Node2D
		if angkasa != null and angkasa.visible:
			sprite = angkasa

	if sprite != null:
		position = sprite.position

# Bentuk kilat yang sama seperti ikon tenaga HUD (HpBar.IkonBar).
func _bentuk_kilat(pusat: Vector2, skala: float) -> PackedVector2Array:
	var bentuk: Array[Vector2] = [
		Vector2(13, 2), Vector2(4, 14), Vector2(11, 14),
		Vector2(9, 22), Vector2(20, 10), Vector2(13, 10),
	]
	var titik := PackedVector2Array()
	for b in bentuk:
		titik.append(pusat + (b - Vector2(12, 12)) * skala)
	return titik

func _draw() -> void:
	if not aktif:
		return

	var denyut: float = 0.5 + 0.5 * sin(_masa * kelajuan_denyut)
	var alpha: float = 0.35 + 0.65 * denyut
	var skala: float = (saiz_simbol / 24.0) * (0.9 + 0.15 * denyut)
	var pusat := Vector2(0, jarak_simbol - 2.0 * sin(_masa * 3.0))

	# Garis luar gelap supaya ikon kekal jelas atas latar cerah
	var luar := PackedVector2Array()
	for p in _bentuk_kilat(pusat, skala * 1.22):
		luar.append(pusat + (p - pusat) * 1.22)
	draw_colored_polygon(luar, Color(0.06, 0.05, 0.01, 0.9 * alpha))

	draw_colored_polygon(
		_bentuk_kilat(pusat, skala),
		Color(warna_simbol.r, warna_simbol.g, warna_simbol.b, alpha)
	)
