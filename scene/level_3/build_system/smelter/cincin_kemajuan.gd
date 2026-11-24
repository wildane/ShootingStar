extends Control

## Cincin kemajuan kecil di kanan kad resipi: trek gelap, cincin cyan yang
## memenuhi satu unit dan teks "1/3" di tengah. Hanya dilukis semasa relau
## melebur (teks kosong = lukis tiada apa-apa).

const WARNA_LATAR := Color(0.02, 0.05, 0.08, 0.85)
const WARNA_TREK := Color(0.22, 0.38, 0.46, 0.9)
const WARNA_ISI := Color(0.36, 0.9, 1.0, 1.0)
const WARNA_PUDAR := Color(0.36, 0.9, 1.0, 0.25)

var nisbah: float = 0.0
var teks: String = ""
var _label: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 5)
	_label.add_theme_color_override("font_color", Color(0.85, 0.97, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.08, 0.95))
	_label.add_theme_constant_override("outline_size", 2)
	add_child(_label)

func set_kemajuan(n: float, t: String) -> void:
	var n_baru: float = clampf(n, 0.0, 1.0)
	var teks_berubah: bool = t != teks
	if _label and teks_berubah:
		_label.text = t
	# Hanya lukis semula bila bentuk cincin atau teks benar-benar berubah.
	if is_equal_approx(n_baru, nisbah) and not teks_berubah:
		return
	nisbah = n_baru
	teks = t
	queue_redraw()

func _draw() -> void:
	if teks == "":
		return # Relau menganggur: tiada cincin pada kad.
	var pusat: Vector2 = size * 0.5
	var jejari: float = minf(size.x, size.y) * 0.5 - 1.0
	# Latar gelap supaya cincin jelas atas kad.
	draw_circle(pusat, jejari + 1.0, WARNA_LATAR)
	draw_arc(pusat, jejari, 0.0, TAU, 24, WARNA_TREK, 1.5, true)
	if nisbah > 0.0:
		# Glow nipis di luar trek, kemudian cincin kemajuan dari atas.
		draw_arc(pusat, jejari, -PI * 0.5, -PI * 0.5 + TAU * nisbah, 24, WARNA_PUDAR, 3.0, true)
		draw_arc(pusat, jejari, -PI * 0.5, -PI * 0.5 + TAU * nisbah, 24, WARNA_ISI, 2.0, true)
