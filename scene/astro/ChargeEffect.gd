extends Node2D

## Kesan visual semasa player dicas oleh Charging Station.
##
## Ada dua gaya yang boleh dipilih melalui `guna_tekstur`:
##   false = animasi arka asal (dilukis dengan _draw, garis nipis)
##   true  = tiga lapisan sprite cincin (ChargeRing.png) yang berputar
##
## Node ini anak terus player, jadi ia ikut SpriteBase dan SpriteAngkasa.
## Kesan menyala selagi ada sumber cas, termasuk bila tenaga sudah penuh.

@export var guna_tekstur: bool = false    # tukar ke true untuk versi sprite cincin
@export var radius: float = 18.0          # jejari arka (unit dunia)
@export var warna: Color = Color(0.45, 0.95, 1.0)
@export var kelajuan: float = 1.6         # pusingan sesaat
@export var ikut_sprite_aktif: bool = true

const TEKSTUR_CINCIN: String = "res://scene/astro/ChargeRing.png"
const SAIZ_TEKSTUR: float = 128.0

var aktif: bool = false
var _masa: float = 0.0
var _lapis: Array[Sprite2D] = []

func _ready() -> void:
	visible = false
	z_index = 6
	set_process(true)
	if guna_tekstur:
		_bina_lapis()

func _bina_lapis() -> void:
	var tekstur = load(TEKSTUR_CINCIN)
	if tekstur == null:
		print("[Cas] GAGAL muat tekstur ", TEKSTUR_CINCIN)
		return

	# Tiga lapisan cincin: luar, tengah, dalam - pusing arah berbeza
	var faktor: Array[float] = [1.0, 0.72, 0.5]
	var alfa: Array[float] = [1.0, 0.85, 0.7]
	var arah: Array[float] = [1.0, -1.4, 1.9]
	var saiz_asas: float = (radius * 2.0) / SAIZ_TEKSTUR

	for i in 3:
		var lapis := Sprite2D.new()
		lapis.texture = tekstur
		lapis.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		lapis.modulate = Color(warna.r, warna.g, warna.b, alfa[i])
		lapis.scale = Vector2.ONE * saiz_asas * faktor[i]
		lapis.set_meta("arah", arah[i])
		add_child(lapis)
		_lapis.append(lapis)

func _process(delta: float) -> void:
	if not aktif:
		if visible:
			visible = false
		return

	visible = true
	_masa += delta

	if guna_tekstur:
		for lapis in _lapis:
			if not is_instance_valid(lapis):
				continue
			var arah: float = lapis.get_meta("arah", 1.0)
			lapis.rotation += arah * kelajuan * delta
		var denyut: float = 1.0 + 0.05 * sin(_masa * 6.0)
		scale = Vector2(denyut, denyut)
	else:
		queue_redraw()

	if ikut_sprite_aktif:
		_ikut_sprite_aktif()

# Letak kesan pada sprite player yang sedang kelihatan supaya arka
# mengelilingi badan yang betul dalam kedua-dua bentuk player.
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

# ---- Gaya asal: arka dilukis terus ----
func _draw() -> void:
	if not aktif or guna_tekstur:
		return

	# Arka utama berputar mengelilingi badan
	var denyut: float = 1.0 + 0.06 * sin(_masa * 6.0)
	for i in 3:
		var fasa: float = -_masa * kelajuan + TAU * float(i) / 3.0
		draw_arc(Vector2.ZERO, radius * denyut, fasa, fasa + PI * 0.7, 16, warna, 1.5)

	# Arka dalam, lebih nipis dan berlawanan arah
	for i in 2:
		var fasa_dalam: float = _masa * kelajuan * 0.7 + TAU * float(i) / 2.0
		draw_arc(Vector2.ZERO, radius * 0.6, fasa_dalam, fasa_dalam + PI * 0.5, 12, Color(warna.r, warna.g, warna.b, 0.55), 1.0)

	# Titik kecil yang mengorbit (macam percikan tenaga)
	for i in 5:
		var sudut: float = -_masa * kelajuan * 1.3 + TAU * float(i) / 5.0
		var pos: Vector2 = Vector2(cos(sudut), sin(sudut)) * radius * 1.15
		draw_circle(pos, 1.2, warna)

	# Kilau tengah yang berdenyut perlahan
	var alpha_tengah: float = 0.12 + 0.06 * sin(_masa * 4.0)
	draw_circle(Vector2.ZERO, radius * 0.5, Color(warna.r, warna.g, warna.b, alpha_tengah))
