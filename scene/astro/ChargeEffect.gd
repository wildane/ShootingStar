extends Node2D

## Kesan visual semasa player dicas oleh Charging Station.
## Guna tekstur cincin (ChargeRing.png) yang diputarkan dalam 3 lapisan,
## jadi kesan ni dirender macam sprite biasa - lebih pasti kelihatan
## berbanding lukisan _draw yang halus.
## Node ini anak terus player, jadi ia ikut SpriteBase dan SpriteAngkasa.

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

	for lapis in _lapis:
		if not is_instance_valid(lapis):
			continue
		var arah: float = lapis.get_meta("arah", 1.0)
		lapis.rotation += arah * kelajuan * delta

	# Denyut skala lembut
	var denyut: float = 1.0 + 0.05 * sin(_masa * 6.0)
	scale = Vector2(denyut, denyut)

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
