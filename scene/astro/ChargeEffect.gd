extends Node2D

## Kesan visual semasa player dicas oleh Charging Station:
##   - simbol "+" berkelip di atas kepala player
##   - zarah kecil bercahaya menaik dari badan (flow ke atas)
##
## Node ini anak terus player, jadi ia ikut SpriteBase dan SpriteAngkasa.
## Kesan menyala selagi ada sumber cas, termasuk bila tenaga sudah penuh.

@export var warna: Color = Color(0.45, 0.95, 1.0)
@export var saiz_simbol: int = 16        # saiz font simbol "+"
@export var jumlah_zarah: int = 24       # banyaknya zarah menaik
@export var kelajuan_denyut: float = 7.0 # kelajuan simbol berkelip
@export var ikut_sprite_aktif: bool = true

const TEKSTUR_ZARAH: String = "res://scene/astro/ChargeSpark.png"

var aktif: bool = false
var _masa: float = 0.0
var _label_plus: Label = null
var _zarah: CPUParticles2D = null

func _ready() -> void:
	visible = false
	z_index = 6
	set_process(true)
	_bina_simbol()
	_bina_zarah()

func _bina_simbol() -> void:
	_label_plus = Label.new()
	_label_plus.name = "SimbolPlus"
	_label_plus.text = "+"
	_label_plus.add_theme_font_size_override("font_size", saiz_simbol)
	_label_plus.add_theme_color_override("font_outline_color", Color(0.02, 0.10, 0.14, 0.9))
	_label_plus.add_theme_constant_override("outline_size", 3)
	_label_plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_plus.size = Vector2(30, 22)
	_label_plus.position = Vector2(-15, -40)
	_label_plus.modulate = warna
	_label_plus.z_index = 7
	add_child(_label_plus)

func _bina_zarah() -> void:
	_zarah = CPUParticles2D.new()
	_zarah.name = "ZarahCas"
	var tekstur = load(TEKSTUR_ZARAH)
	if tekstur != null:
		_zarah.texture = tekstur
	_zarah.amount = jumlah_zarah
	_zarah.lifetime = 0.9
	_zarah.preprocess = 0.4
	_zarah.direction = Vector2(0, -1)
	_zarah.spread = 28.0
	_zarah.gravity = Vector2(0, -25)
	_zarah.initial_velocity_min = 26.0
	_zarah.initial_velocity_max = 60.0
	_zarah.scale_amount_min = 0.35
	_zarah.scale_amount_max = 0.85
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

	# Simbol "+" berkelip dan naik-turun sedikit
	if _label_plus != null:
		var denyut: float = 0.5 + 0.5 * sin(_masa * kelajuan_denyut)
		_label_plus.modulate = Color(warna.r, warna.g, warna.b, 0.35 + 0.65 * denyut)
		var skala: float = 0.85 + 0.25 * denyut
		_label_plus.scale = Vector2(skala, skala)
		_label_plus.position = Vector2(-15, -40 - 2.0 * sin(_masa * 3.0))

	if _zarah != null and not _zarah.emitting:
		_zarah.emitting = true

	if ikut_sprite_aktif:
		_ikut_sprite_aktif()

# Letak kesan pada sprite player yang sedang kelihatan supaya simbol
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
