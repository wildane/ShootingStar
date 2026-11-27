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


# ==========================================================
# VARIABLES INTERNAL
# ==========================================================
var touches: Dictionary = {}
var pinch_mode: bool = false
var last_pinch_distance: float = 0.0
var parent_astro: CharacterBody2D

func _ready() -> void:
	parent_astro = get_parent() as CharacterBody2D
	
	# Tetapkan tahap zoom awal kamera dari Inspector
	zoom = Vector2(zoom_awal, zoom_awal)

# Sentuhan boleh "tersangkut" bila SceneTree dipause (menu) atau tetingkap
# hilang fokus: event lepas jari tidak sampai ke kamera, jadi index lama kekal
# dalam `touches`. Jari baharu kemudian disangka jari kedua (pinch palsu) dan
# bila index hantu bertambah, pinch sebenar pula tersekat. Kosongkan state.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, \
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_VISIBILITY_CHANGED:
			_kosongkan_sentuhan()

func _kosongkan_sentuhan() -> void:
	touches.clear()
	pinch_mode = false
	last_pinch_distance = 0.0

func _input(event: InputEvent) -> void:
	# Pastikan hanya player tempatan sahaja yang boleh kawal kamera zoom
	if not parent_astro or not parent_astro.get_meta("local", false):
		return

	# DETECT SENTUHAN JARI
	if event is InputEventScreenTouch:
		# Sentuhan yang dibatalkan sistem (touchcancel pelayar) mesti dibuang,
		# kalau tidak index itu kekal sebagai "jari" selama-lamanya.
		if event.pressed and not event.canceled:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
			if touches.size() < 2:
				pinch_mode = false
				last_pinch_distance = 0.0

	# DETECT HERETAN JARI (PINCH)
	if event is InputEventScreenDrag:
		# Abaikan drag untuk jari yang tiada rekod tekan (jari hantu).
		if not touches.has(event.index):
			return
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

	# Laksanakan perubahan nilai zoom pada kamera
	var new_zoom: float = zoom.x + diff * zoom_sensitivity
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)

	zoom = Vector2(new_zoom, new_zoom)
	last_pinch_distance = dist
