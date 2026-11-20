extends StaticBody2D

## Charging Station: perabot yang mengecas semula tenaga pemain.
## Perlu kuasa dari Power Inverter (sama macam perabot lain) dan pemain
## mesti berada dalam radius stesen untuk menerima cas.

@onready var save_component = $SaveComponent
@onready var sprite = get_node_or_null("Sprite2D")
@onready var area_penderia = get_node_or_null("Area2D")
@onready var menu_ui = get_node_or_null("CanvasLayer/MenuUI")
@onready var label_status = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/LabelStatus")
@onready var butang_tutup = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonTutup")
@onready var butang_demolish = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonDemolish")

@export_category("Sistem Kuasa")
@export var power_required: float = 30.0
var has_power: bool = false
var inverter_pembekal: Node2D = null

@export_category("Sistem Pengecasan")
@export var radius_cas: float = 30.0
@export var kadar_cas: float = 5.0        # tenaga sesaat semasa aktif

var player_dekat: bool = false
var masa_ketikan_terakhir: float = 0.0
const SELA_MASA_MINIMUM: float = 0.2

var masa_semakan_terakhir: float = 0.0
const SELA_MASA_SEMAKAN: float = 0.2

var kadar_cas_semasa: float = 0.0
var _pemain_dicas: Node = null
var _ikon_cas: Node2D = null

func _ready() -> void:
	add_to_group("Furniture")
	# Robot pekerja cari stesen melalui group ini untuk mengecas tenaga.
	add_to_group("StesenCas")

	if area_penderia:
		area_penderia.input_pickable = true
		area_penderia.body_entered.connect(_on_body_entered)
		area_penderia.body_exited.connect(_on_body_exited)
		area_penderia.input_event.connect(_on_area_input_event)

	if menu_ui:
		menu_ui.hide()
	if butang_tutup: butang_tutup.pressed.connect(_on_butang_tutup_pressed)
	if butang_demolish: butang_demolish.pressed.connect(_on_butang_demolish_pressed)

	_bina_ikon_cas()
	_kemas_kini_warna_visual()
	_kemas_kini_label_status()
	_auto_save_selepas_wujud()

# Ikon kilat kuning berkelip di atas stesen semasa ia mengecas player.
func _bina_ikon_cas() -> void:
	var skrip = load("res://scene/astro/ChargeEffect.gd")
	if skrip == null:
		return
	_ikon_cas = Node2D.new()
	_ikon_cas.name = "IkonCas"
	_ikon_cas.set_script(skrip)
	_ikon_cas.ikut_sprite_aktif = false
	# Sprite stesen lebih kurang 24 unit tinggi (tengah di 0), jadi ikon
	# diletak rapat di atas bahagian atasnya.
	_ikon_cas.jarak_simbol = -16.0
	_ikon_cas.saiz_simbol = 10.0
	_ikon_cas.position = Vector2.ZERO
	add_child(_ikon_cas)

func _physics_process(_delta: float) -> void:
	var masa_sekarang = Time.get_ticks_msec() / 1000.0
	if masa_sekarang - masa_semakan_terakhir < SELA_MASA_SEMAKAN:
		return
	masa_semakan_terakhir = masa_sekarang
	_kemas_kini_pengecasan()
	_kemas_kini_label_status()

## Daftar/lepas pemain pada EnergyComponent ikut jarak dan status kuasa.
func _kemas_kini_pengecasan() -> void:
	var pemain = get_tree().get_first_node_in_group("Player")
	var tenaga: Node = null
	var dalam_julat: bool = false
	if is_instance_valid(pemain):
		dalam_julat = global_position.distance_to(pemain.global_position) <= radius_cas
		if dalam_julat:
			tenaga = pemain.get_node_or_null("EnergyComponent")

	var aktif: bool = has_power and dalam_julat and tenaga != null
	if aktif and tenaga.has_method("daftar_stesen_cas"):
		if _pemain_dicas != tenaga:
			_lepas_pemain()
			_pemain_dicas = tenaga
		tenaga.daftar_stesen_cas(self)
		kadar_cas_semasa = kadar_cas
	else:
		_lepas_pemain()

	if _ikon_cas != null and ("aktif" in _ikon_cas):
		_ikon_cas.aktif = kadar_cas_semasa > 0.0

func _lepas_pemain() -> void:
	if is_instance_valid(_pemain_dicas) and _pemain_dicas.has_method("nyahdaftar_stesen_cas"):
		_pemain_dicas.nyahdaftar_stesen_cas(self)
	_pemain_dicas = null
	kadar_cas_semasa = 0.0

# ---- Sistem kuasa (dipanggil oleh PowerInverter) ----
func set_power_status(status_elektrik: bool, pembekal: Node2D = null) -> void:
	has_power = status_elektrik
	if status_elektrik:
		inverter_pembekal = pembekal
	else:
		if inverter_pembekal == pembekal or pembekal == null:
			inverter_pembekal = null
	_kemas_kini_warna_visual()
	_kemas_kini_label_status()

func _kemas_kini_warna_visual() -> void:
	if not sprite: return
	if player_dekat:
		sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)
	elif has_power:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		sprite.modulate = Color(0.45, 0.45, 0.45, 1.0)

func _kemas_kini_label_status() -> void:
	if label_status == null: return
	if has_power:
		label_status.text = "Power: ON"
		label_status.modulate = Color(0.35, 1.0, 0.45)
	else:
		label_status.text = "Power: OFF"
		label_status.modulate = Color(1.0, 0.4, 0.4)

# ---- Penderia player ----
func _on_body_entered(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = true
		_kemas_kini_warna_visual()

func _on_body_exited(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = false
		_kemas_kini_warna_visual()
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
			_kemas_kini_label_status()
			menu_ui.visible = !menu_ui.visible
		get_viewport().set_input_as_handled()

func _on_butang_tutup_pressed():
	if menu_ui: menu_ui.hide()

func _on_butang_demolish_pressed():
	_lepas_pemain()
	player_dekat = false
	if sprite: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	queue_free()
	await get_tree().process_frame
	if get_node_or_null("/root/SaveManager"):
		SaveManager.save_game()

func get_save_data() -> Dictionary:
	var data_stesen: Dictionary = {}
	if save_component and save_component.has_method("get_data"):
		data_stesen = save_component.get_data()
	data_stesen["scene_path"] = scene_file_path
	data_stesen["pos_x"] = global_position.x
	data_stesen["pos_y"] = global_position.y
	return data_stesen

func load_save_data(data: Dictionary) -> void:
	if data.has("global_position"):
		global_position = data["global_position"]

func _exit_tree() -> void:
	_lepas_pemain()

func _auto_save_selepas_wujud() -> void:
	await get_tree().process_frame
	if get_node_or_null("/root/SaveManager"):
		SaveManager.save_game()
