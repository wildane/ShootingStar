class_name Asteroid
extends Node2D

## Asteroid besar — BUKAN meteorit yang boleh dilombong. Ia padat, pemain
## melanggar permukaannya, dan ia menyediakan kawasan sah untuk membina
## lantai/dinding/pintu pangkalan.
##
## Bentuk dan kolider dibina daripada `jejari` supaya satu scene boleh
## digunakan pada saiz berbeza (letak instance lain dalam level).

@export var jejari: float = 150.0
@export var bilangan_sisi: int = 28
## Jarak ke dalam dari tepi batu. Tile grid mesti berada sekurang-kurangnya
## sejauh ini dari tepi supaya ia tidak tergantung di luar asteroid.
@export var margin_bina: float = 16.0
@export var warna_batu: Color = Color(0.15, 0.18, 0.25, 1.0)
@export var warna_tepi: Color = Color(0.36, 0.72, 0.95, 0.55)

var _poligon: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	add_to_group("Asteroid")
	_bina_bentuk()

func _bina_bentuk() -> void:
	_poligon = PackedVector2Array()
	for i in range(bilangan_sisi):
		var sudut: float = TAU * float(i) / float(bilangan_sisi)
		# Sedikit tak seragam supaya nampak seperti batu, bukan bulatan sempurna.
		var r: float = jejari * (1.0 + 0.09 * sin(sudut * 3.0 + 0.7) + 0.05 * cos(sudut * 5.0))
		_poligon.append(Vector2(cos(sudut), sin(sudut)) * r)

	var badan := StaticBody2D.new()
	badan.name = "Badan"
	# Layer 4 (nilai 8) = environment, sama seperti meteorit. Pemain
	# (collision_mask 10) berlanggar dengan layer ini.
	badan.collision_layer = 8
	badan.collision_mask = 0
	var bentuk := CollisionPolygon2D.new()
	bentuk.polygon = _poligon
	badan.add_child(bentuk)
	add_child(badan)

	queue_redraw()

func _draw() -> void:
	if _poligon.size() < 3:
		return
	draw_colored_polygon(_poligon, warna_batu)
	var tutup := _poligon.duplicate()
	tutup.append(_poligon[0])
	draw_polyline(tutup, warna_tepi, 3.0, true)
	draw_polyline(tutup, Color(0.55, 0.88, 1.0, 0.12), 9.0, true)

# Bolehkah tile dibina pada posisi dunia ini? Dipanggil oleh BuildGrid.
func boleh_bina_di(pos_dunia: Vector2) -> bool:
	return to_local(pos_dunia).length() <= jejari - margin_bina
