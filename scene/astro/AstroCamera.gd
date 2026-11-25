extends Camera2D
class_name AstroCamera

# ==========================================================
# EXPORTS (BOLEH LARAS DI INSPECTOR CAMERA2D)
# ==========================================================
@export_group("Had Jarak Zoom Mobile")
@export var min_zoom: float = 0.5            # Jarak paling jauh (Zoom Out)
@export var max_zoom: float = 3.0            # Jarak paling dekat (Zoom In)

@export_group("Sensitiviti Cubitan Jari")
@export var zoom_sensitivity: float = 0.003  # Kecekapan cubitan jari (Makin tinggi makin laju)

@export_group("Zoom Scroll Mouse")
@export var zoom_scroll_step: float = 0.1    # Perubahan zoom setiap tatal wheel (0.1 = 10%)

@export_group("Tetapan Permulaan")
@export var zoom_awal: float = 1.0           # Tahap zoom asal kamera apabila game bermula

@export_group("Mod Peta")
@export var zoom_peta: float = 0.25          # Tahap zoom keluar semasa mod peta

# ==========================================================
# VARIABLES INTERNAL
# ==========================================================
var touches: Dictionary = {}
var pinch_mode: bool = false
var last_pinch_distance: float = 0.0
var parent_astro: CharacterBody2D
var mod_peta_aktif: bool = false
var zoom_sebelum_peta: float = 1.0

func _ready() -> void:
	parent_astro = get_parent() as CharacterBody2D
	
	# Tetapkan tahap zoom awal kamera dari Inspector
	zoom = Vector2(zoom_awal, zoom_awal)

func _input(event: InputEvent) -> void:
	# Pastikan hanya player tempatan sahaja yang boleh kawal kamera zoom
	if not parent_astro or not parent_astro.get_meta("local", false):
		return

	# DETECT SENTUHAN JARI
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
			if touches.size() < 2:
				pinch_mode = false
				last_pinch_distance = 0.0

	# DETECT HERETAN JARI (PINCH)
	if event is InputEventScreenDrag:
		touches[event.index] = event.position

		# Jika ada 2 jari serentak pada skrin, aktifkan Pinch Zoom
		if touches.size() == 2:
			pinch_mode = true
			_handle_pinch()

	# DETECT SCROLL WHEEL MOUSE (ZOOM DESKTOP)
	if event is InputEventMouseButton and event.pressed:
		if _mouse_di_atas_ui():
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_handle_scroll_zoom(1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_scroll_zoom(-1.0)

func _handle_scroll_zoom(arah: float) -> void:
	if mod_peta_aktif:
		tetapkan_mod_peta(false)
	var new_zoom: float = zoom.x * (1.0 + arah * zoom_scroll_step)
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)

func _mouse_di_atas_ui() -> bool:
	# Jangan zoom bila kursor berada di atas butang/panel HUD
	var kawalan: Control = get_viewport().gui_get_hovered_control()
	return kawalan != null and kawalan.mouse_filter != Control.MOUSE_FILTER_IGNORE

func _handle_pinch() -> void:
	var v: Array = touches.values()
	if v.size() < 2:
		return

	var p1: Vector2 = v[0]
	var p2: Vector2 = v[1]

	# Kira jarak antara dua jari
	var dist: float = p1.distance_to(p2)

	if last_pinch_distance == 0.0:
		last_pinch_distance = dist
		return

	# Hitung perbezaan jarak cubitan
	var diff: float = dist - last_pinch_distance

	if mod_peta_aktif:
		tetapkan_mod_peta(false)

	# Laksanakan perubahan nilai zoom pada kamera
	var new_zoom: float = zoom.x + diff * zoom_sensitivity
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)

	zoom = Vector2(new_zoom, new_zoom)
	last_pinch_distance = dist


func togol_mod_peta() -> void:
	tetapkan_mod_peta(not mod_peta_aktif)


func tetapkan_mod_peta(aktif: bool) -> void:
	if aktif == mod_peta_aktif:
		return
	mod_peta_aktif = aktif
	if mod_peta_aktif:
		zoom_sebelum_peta = zoom.x
		zoom = Vector2(zoom_peta, zoom_peta)
	else:
		var sasaran: float = clamp(zoom_sebelum_peta, min_zoom, max_zoom)
		zoom = Vector2(sasaran, sasaran)
