extends StaticBody2D

# 🔴 Komponen Save
@onready var save_component = $SaveComponent 

# 🔴 Rujukan Nod Utama
@onready var sprite = get_node_or_null("Sprite2D")
@onready var area_penderia = get_node_or_null("Area2D")
const TemaPerabot := preload("res://scene/ui/TemaPerabot.gd")
const PowerGridRef := preload("res://scene/level_3/build_system/PowerInverter/PowerGrid.gd")

@onready var menu_ui = get_node_or_null("CanvasLayer/MenuUI") 
@onready var butang_tutup = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonTutup")
@onready var butang_demolish = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonDemolish")

# 🔴 Tetapan Konfigurasi Dinamik
var player_dekat: bool = false
var masa_ketikan_terakhir: float = 0.0
const SELA_MASA_MINIMUM: float = 0.2  

@export var power_required: float = 20.0  
var has_power: bool = false               
var inverter_pembekal: Node2D = null

func _ready():
	# 1. Masuk group perabot
	add_to_group("Furniture") 

	# 2. Sediakan sambungan isyarat (signals)
	if area_penderia:
		area_penderia.input_pickable = true
		area_penderia.body_entered.connect(_on_body_entered)
		area_penderia.body_exited.connect(_on_body_exited)
		area_penderia.input_event.connect(_on_area_input_event)
		
	if menu_ui:
		menu_ui.hide()
		TemaPerabot.pasang(menu_ui)
		
	if butang_tutup: butang_tutup.pressed.connect(_on_butang_tutup_pressed)
	if butang_demolish: butang_demolish.pressed.connect(_on_butang_demolish_pressed)

	_kemas_kini_warna_visual()
	PowerGridRef.daftar_perabot(self)

# 🔴 DIKEMASKINI: Hanya kumpul fail laluan objek dan kedudukan koordinat dunia sahaja (Bersih Tanpa Logik Kuasa)
func get_save_data() -> Dictionary:
	var data_perabot: Dictionary = {}
	if save_component and save_component.has_method("get_data"):
		data_perabot = save_component.get_data()
	
	# Set koordinat sahaja secara bersih mengikut keperluan SaveManager
	data_perabot["scene_path"] = scene_file_path  
	data_perabot["pos_x"] = global_position.x     
	data_perabot["pos_y"] = global_position.y     
	
	return data_perabot

# 🔴 Sistem Pengurusan Kuasa Elektrik
func set_power_status(status_elektrik: bool, pembekal: Node2D = null) -> void:
	var pembekal_baru: Node2D = inverter_pembekal
	if status_elektrik:
		pembekal_baru = pembekal
	else:
		if inverter_pembekal == pembekal or pembekal == null:
			pembekal_baru = null
	if has_power == status_elektrik and inverter_pembekal == pembekal_baru:
		return
	has_power = status_elektrik
	inverter_pembekal = pembekal_baru
	_kemas_kini_warna_visual()

# 🔴 Sistem Visual Feedback
func _kemas_kini_warna_visual() -> void:
	if not sprite: return
	if player_dekat: 
		sprite.modulate = Color(0.3, 1.0, 0.3, 1.0) 
	else:
		if has_power: 
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) 
		else: 
			sprite.modulate = Color(0.4, 0.4, 0.4, 1.0) 

# 🔴 Penderia Jarak Player
func _on_body_entered(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = true
		_kemas_kini_warna_visual() 

func _on_body_exited(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = false
		_kemas_kini_warna_visual() 
		if menu_ui: menu_ui.hide() 

# 🔴 Input Klik / Sentuhan Objek
# =========================
# Klik mouse pada PC
# =========================
# AstroStateMachine menandakan setiap klik kiri mouse sebagai "handled" dalam
# _unhandled_input, jadi physics picking Area2D dibatalkan dan input_event
# perabot tidak pernah dicetus pada PC. _input berjalan lebih awal, jadi klik
# dihantar ke pengendali sedia ada sebagai sentuhan maya.
func _input(event: InputEvent) -> void:
	var klik := event as InputEventMouseButton
	if klik == null or not klik.pressed or klik.button_index != MOUSE_BUTTON_LEFT:
		return
	if not player_dekat or area_penderia == null:
		return
	# Jangan rampas klik yang sepatutnya milik butang/panel UI.
	var kawalan := get_viewport().gui_get_hovered_control()
	if kawalan != null and kawalan.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return
	if not _klik_dalam_kawasan(klik.position):
		return
	var sentuhan := InputEventScreenTouch.new()
	sentuhan.index = 0
	sentuhan.position = klik.position
	sentuhan.pressed = true
	_on_area_input_event(get_viewport(), sentuhan, 0)
	get_viewport().set_input_as_handled()


# Zon klik perabot ikut CollisionShape2D pada Area2D, dengan sedikit toleransi.
func _klik_dalam_kawasan(pos_skrin: Vector2) -> bool:
	var titik: Vector2 = area_penderia.to_local(get_canvas_transform().affine_inverse() * pos_skrin)
	var ada_bentuk := false
	for anak in area_penderia.get_children():
		if anak is CollisionShape2D and anak.shape is RectangleShape2D:
			ada_bentuk = true
			var jejari: Vector2 = anak.shape.size * 0.5 + Vector2(2.0, 2.0)
			if Rect2(anak.position - jejari, jejari * 2.0).has_point(titik):
				return true
	if ada_bentuk:
		return false
	return titik.length() < 24.0


# =========================
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	var ada_sentuhan = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if ada_sentuhan and player_dekat:
		var masa_sekarang = Time.get_ticks_msec() / 1000.0
		if masa_sekarang - masa_ketikan_terakhir < SELA_MASA_MINIMUM: return
		masa_ketikan_terakhir = masa_sekarang
		
		if menu_ui:
			menu_ui.visible = !menu_ui.visible
		get_viewport().set_input_as_handled()

# 🔴 Pengurusan Butang UI
func _on_butang_tutup_pressed(): 
	if menu_ui: menu_ui.hide()

func _on_butang_demolish_pressed():
	print("Sistem Khas: Objek perabot telah dimusnahkan!")
	player_dekat = false
	if sprite: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	PowerGridRef.nyahdaftar_perabot(self)
	queue_free()

func _exit_tree() -> void:
	PowerGridRef.nyahdaftar_perabot(self)
