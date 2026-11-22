class_name ZonBina
extends RefCounted

## Peraturan zon bina untuk perabot:
## SELURUH tapak perabot (bentuk Area2D preview) mesti berada di atas zon
## bina (layer 3). Sebelum ini satu titik bersentuhan pun sudah cukup, jadi
## perabot boleh terkeluar dari lantai yang dibina.
##
## Semakan dibuat dengan titik semakan yang ditabur ke seluruh tapak:
## setiap titik mesti berada dalam kawasan zon bina. Tepi dan bucu tapak
## turut disemak, jadi tapak yang terkeluar sedikit pun tidak diterima.

## Layer 3 (nilai bit 4) = zon bina lantai / ZonBuildable.
const MASK_ZON_BINA: int = 4
## Jarak sasaran antara titik semakan (piksel).
const JARAK_SEMAK: float = 4.0
## Had titik sebaris supaya kos semakan kekal rendah (maks 10 x 10 titik).
const MAKS_TITIK_SEBARIS: int = 10
## Toleransi di tepi tapak (piksel) supaya titik semakan tidak jatuh tepat
## pada garisan sempadan antara dua tile lantai.
const TOLERANSI_TEPI: float = 1.0

# Adakah seluruh tapak `area` berada di dalam zon bina?
static func semua_dalam_zon_bina(area: Area2D) -> bool:
	if area == null or not is_instance_valid(area):
		return false

	var tapak := _rect_dunia(area).grow(-TOLERANSI_TEPI)
	if tapak.size.x <= 0.0 or tapak.size.y <= 0.0:
		return false

	var ruang := area.get_world_2d().direct_space_state
	if ruang == null:
		return false

	var params := PhysicsPointQueryParameters2D.new()
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = MASK_ZON_BINA
	params.exclude = [area.get_rid()]

	# Termasuk tepi: titik pertama dan terakhir tepat pada bucu tapak.
	var lajur: int = clampi(ceili(tapak.size.x / JARAK_SEMAK) + 1, 2, MAKS_TITIK_SEBARIS)
	var baris: int = clampi(ceili(tapak.size.y / JARAK_SEMAK) + 1, 2, MAKS_TITIK_SEBARIS)

	for i in range(lajur):
		for j in range(baris):
			var t := Vector2(float(i) / float(lajur - 1), float(j) / float(baris - 1))
			params.position = tapak.position + tapak.size * t
			if not _titik_atas_zon(ruang, params):
				return false
	return true

static func _titik_atas_zon(ruang: PhysicsDirectSpaceState2D, params: PhysicsPointQueryParameters2D) -> bool:
	for hasil in ruang.intersect_point(params, 8):
		var kawasan := hasil.get("collider") as Node
		if kawasan != null and kawasan.get_collision_layer_value(3):
			return true
	return false

# Rect dunia bagi bentuk kolider preview (termasuk Scale dari Inspector).
static func _rect_dunia(area: Area2D) -> Rect2:
	for anak in area.get_children():
		if anak is CollisionShape2D and anak.shape != null:
			var bentuk := anak as CollisionShape2D
			var setempat: Rect2 = bentuk.shape.get_rect()
			var xf: Transform2D = bentuk.global_transform
			var sudut := [
				xf * setempat.position,
				xf * Vector2(setempat.end.x, setempat.position.y),
				xf * setempat.end,
				xf * Vector2(setempat.position.x, setempat.end.y),
			]
			var min_v: Vector2 = sudut[0]
			var max_v: Vector2 = sudut[0]
			for s in sudut:
				min_v = min_v.min(s)
				max_v = max_v.max(s)
			return Rect2(min_v, max_v - min_v)
	# Tiada bentuk: anggap tapak kecil di tengah preview (lebih ketat).
	return Rect2(area.global_position, Vector2.ZERO)
