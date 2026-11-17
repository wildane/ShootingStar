extends Node2D

## Kesan visual semasa player dicas oleh Charging Station:
## arka sian berputar + titik kecil mengelilingi badan player.

@export var radius: float = 14.0
@export var warna: Color = Color(0.45, 0.95, 1.0)
@export var kelajuan: float = 2.0

var aktif: bool = false
var _masa: float = 0.0

func _ready() -> void:
	visible = false
	z_index = 2
	set_process(true)

func _process(delta: float) -> void:
	if not aktif:
		if visible:
			visible = false
		return
	visible = true
	_masa += delta
	queue_redraw()

func _draw() -> void:
	if not aktif:
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
