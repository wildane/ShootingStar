extends Node2D

## Cincin kemajuan kecil di atas relau: ikon item yang sedang di-craft di
## tengah, cincin cyan yang bergerak ikut kemajuan satu unit, dan teks
## "1/7" di bawahnya.

const JEJARI: float = 8.0
const TEBAL: float = 2.0
const SAIZ_IKON: float = 11.0

var nisbah: float = 0.0
var tekstur: Texture2D = null
var teks: String = ""
var _label: Label = null

func _ready() -> void:
	# Kekal di atas sprite relau walaupun susunan y-sort berubah.
	z_as_relative = false
	z_index = 60

	_label = Label.new()
	_label.position = Vector2(-14.0, JEJARI + 1.0)
	_label.size = Vector2(28.0, 9.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 6)
	_label.add_theme_color_override("font_color", Color(0.85, 0.97, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.08, 0.95))
	_label.add_theme_constant_override("outline_size", 3)
	add_child(_label)

func set_kemajuan(n: float, t: String) -> void:
	nisbah = clampf(n, 0.0, 1.0)
	teks = t
	if _label:
		_label.text = t
	queue_redraw()

func _draw() -> void:
	# Latar gelap supaya ikon nampak jelas atas lantai/base.
	draw_circle(Vector2.ZERO, JEJARI + 1.6, Color(0.02, 0.05, 0.08, 0.85))
	# Trek cincin.
	draw_arc(Vector2.ZERO, JEJARI, 0.0, TAU, 48, Color(0.22, 0.38, 0.46, 0.9), TEBAL, true)
	# Cincin kemajuan satu unit, mula dari atas.
	if nisbah > 0.0:
		draw_arc(Vector2.ZERO, JEJARI, -PI * 0.5, -PI * 0.5 + TAU * nisbah, 48,
			Color(0.36, 0.9, 1.0, 1.0), TEBAL + 0.6, true)
	# Ikon item di tengah.
	if tekstur:
		draw_texture_rect(tekstur,
			Rect2(Vector2(-SAIZ_IKON * 0.5, -SAIZ_IKON * 0.5), Vector2(SAIZ_IKON, SAIZ_IKON)),
			false)
