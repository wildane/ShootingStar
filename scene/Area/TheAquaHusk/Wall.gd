@tool # <--- BARIS INI WAJIB supaya bentuk dinding nipis ini terus nampak di dalam Editor
extends StaticBody2D

func _ready() -> void:
	# Set perlanggaran fizikal dinding terus melalui kod supaya selari
	collision_layer = 2  # Dinding di Layer 2
	collision_mask = 1   # Sekat Player di Mask 1

	# PEMBERSIHAN AUTOMATIK: Buang semua bentuk perlanggaran lama yang tersisa
	for child in get_children():
		if child is CollisionPolygon2D:
			remove_child(child)
			child.queue_free()

	# Tetapkan ketebalan dinding yang anda mahu
	var ketebalan_dinding: float = 20.0

	# --- 1. TITIK GARISAN DINDING KIRI ---
	var line_kiri = [
		Vector2(320, 0),
		Vector2(320, 150),
		Vector2(100, 150),
		Vector2(100, 390),
		Vector2(320, 390),
		Vector2(265, 440),
		Vector2(265, 930),
		Vector2(320, 980),
		Vector2(100, 980),
		Vector2(100, 1220),
		Vector2(320, 1220),
		Vector2(320, 1440)
	]
	
	# Tukar garisan tunggal menjadi poligon tebal
	var poly_kiri_points = Geometry2D.offset_polyline(line_kiri, ketebalan_dinding / 2.0)
	for points in poly_kiri_points:
		var poly = CollisionPolygon2D.new()
		poly.polygon = points
		poly.build_mode = CollisionPolygon2D.BUILD_SOLIDS # <--- Kunci penting supaya dinding padat & tidak bocor
		add_child(poly)

	# --- 2. TITIK GARISAN DINDING KANAN ---
	var line_kanan = [
		Vector2(490, 0),
		Vector2(490, 150),
		Vector2(710, 150),
		Vector2(710, 390),
		Vector2(490, 390),
		Vector2(545, 440),
		Vector2(545, 930),
		Vector2(490, 980),
		Vector2(710, 980),
		Vector2(710, 1220),
		Vector2(490, 1220),
		Vector2(490, 1440)
	]
	
	# Tukar garisan tunggal menjadi poligon tebal
	var poly_kanan_points = Geometry2D.offset_polyline(line_kanan, ketebalan_dinding / 2.0)
	for points in poly_kanan_points:
		var poly = CollisionPolygon2D.new()
		poly.polygon = points
		poly.build_mode = CollisionPolygon2D.BUILD_SOLIDS # <--- Kunci penting supaya dinding padat & tidak bocor
		add_child(poly)
