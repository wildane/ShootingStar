extends StaticBody2D

const TemaPerabot := preload("res://scene/ui/TemaPerabot.gd")
const PowerGridRef := preload("res://scene/level_3/build_system/PowerInverter/PowerGrid.gd")

@onready var sprite = get_node_or_null("Sprite2D")
@onready var area_penderia = get_node_or_null("Area2D")

@onready var menu_ui = get_node_or_null("CanvasLayer/MenuUI") 
@onready var butang_tutup = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonTutup")
@onready var butang_demolish = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonDemolish")

@export_category("Sistem Kuasa Solar")
@export var power_production: float = 100.0 
@export var jarak_cantuman: float = 150.0

var inverter_pembeli: Node2D = null
var player_dekat: bool = false
var masa_ketikan_terakhir: float = 0.0
const SELA_MASA_MINIMUM: float = 0.2  

func _ready():
	add_to_group("SolarModule")
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
	PowerGridRef.daftar_solar(self)

func set_owner_inverter(inverter: Node2D) -> void:
	inverter_pembeli = inverter

func release_owner_inverter(inverter: Node2D) -> void:
	if inverter_pembeli == inverter:
		inverter_pembeli = null

func _on_body_entered(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = true
		if sprite: sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)

func _on_body_exited(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = false
		if sprite: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if menu_ui: menu_ui.hide() 

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

func _on_butang_tutup_pressed():
	if menu_ui: menu_ui.hide()

# Kos bina ikut SolarModule_Preview.tscn: 1 Raw Silica + 2 Basic Iron Ore.
func kos_bina() -> Array:
	return [
		{"id": "item_0003", "nama": "Raw Silica", "ikon": load("res://scene/Item/0003RawSilica/Image_495.png"), "scene_path": "res://scene/Item/0003RawSilica/0003RawSilica.tscn", "diperlukan": 1},
		{"id": "item_0001", "nama": "Basic Iron Ore", "ikon": load("res://scene/Item/0001BasicIronOre/Image_959.png"), "scene_path": "res://scene/Item/0001BasicIronOre/0001BasicIronOre.tscn", "diperlukan": 2},
	]

func _on_butang_demolish_pressed():
	# Pulangkan bahan bina (popup "+N <nama>") sebelum modul dibuang.
	BahanBinaan.pulangkan(self)
	inverter_pembeli = null
	player_dekat = false
	if sprite: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	PowerGridRef.nyahdaftar_solar(self)
	queue_free()

func _exit_tree() -> void:
	PowerGridRef.nyahdaftar_solar(self)
