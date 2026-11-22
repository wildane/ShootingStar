extends StaticBody2D

@onready var save_component = $SaveComponent 
@onready var sprite = get_node_or_null("Sprite2D")
@onready var area_penderia = get_node_or_null("Area2D")

var bacaan_kuasa: Label = null

@export_category("Sistem Had Kuasa Inverter")
@export var radius_inverter_to_solar: float = 300.0
@export var radius_inverter_to_furniture: float = 250.0
@export var ketinggian_teks: float = -60.0
@export var font_size: int = 16
@export var font_offset_x: float = -150.0
@export var font_box_width: float = 300.0
@export var line_spacing: int = -6

@export_category("Sistem Warna Font")
@export var warna_selamat: Color = Color(0.3, 1.0, 0.3) 
@export var warna_overload: Color = Color(1.0, 0.3, 0.3) 
@export var warna_kosong: Color = Color(1.0, 1.0, 1.0) 

@export_category("Data Semasa")
@export var total_power_supply: float = 0.0
@export var total_power_requirement: float = 0.0
@export var baki_tenaga: float = 0.0

var player_dekat: bool = false
var masa_ketikan_terakhir: float = 0.0
const SELA_MASA_MINIMUM: float = 0.2  

var masa_semakan_terakhir: float = 0.0
const SELA_MASA_SEMAKAN: float = 0.15 

func _ready():
	add_to_group("PowerInverter")
	bacaan_kuasa = Label.new()
	add_child(bacaan_kuasa)
	bacaan_kuasa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bacaan_kuasa.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bacaan_kuasa.add_theme_font_size_override("font_size", font_size)
	bacaan_kuasa.add_theme_constant_override("line_spacing", line_spacing)
	bacaan_kuasa.position = Vector2(font_offset_x, ketinggian_teks) 
	bacaan_kuasa.size = Vector2(font_box_width, 50) 
	
	if area_penderia:
		area_penderia.input_pickable = true
		area_penderia.body_entered.connect(_on_body_entered)
		area_penderia.body_exited.connect(_on_body_exited)
		area_penderia.input_event.connect(_on_area_input_event)
		
	var menu_ui = get_node_or_null("CanvasLayer/MenuUI")
	var bt_tutup = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonTutup")
	var bt_demo = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonDemolish")
	
	if menu_ui: menu_ui.hide()
	if bt_tutup: bt_tutup.pressed.connect(_on_butang_tutup_pressed)
	if bt_demo: bt_demo.pressed.connect(_on_butang_demolish_pressed)
	_kemas_kini_paparan_skrin()

func _physics_process(_delta: float) -> void:
	var masa_sekarang = Time.get_ticks_msec() / 1000.0
	if masa_sekarang - masa_semakan_terakhir >= SELA_MASA_SEMAKAN:
		masa_semakan_terakhir = masa_sekarang
		kira_grid_kuasa_lokal()

func kira_grid_kuasa_lokal() -> void:
	var semua_solar = get_tree().get_nodes_in_group("SolarModule")
	if semua_solar.is_empty():
		_set_kuasa_kosong()
		_kemas_kini_status_perabot_tiada_kuasa()
		return
		
	var solar_bersambung: Array[Node2D] = []
	var senarai_semak: Array[Node2D] = []
	var pos_inverter = global_position
	
	for solar in semua_solar:
		if is_instance_valid(solar) and solar.is_inside_tree():
			solar.force_update_transform()
			var pos_solar = solar.global_position
			if pos_solar == Vector2.ZERO and pos_inverter != Vector2.ZERO: continue
			var had_jarak = solar.jarak_cantuman if "jarak_cantuman" in solar else radius_inverter_to_solar
			if pos_inverter.distance_to(pos_solar) <= had_jarak:
				if solar.inverter_pembeli == null or solar.inverter_pembeli == self:
					senarai_semak.append(solar)
					solar.set_owner_inverter(self)

	var jumlah_supply: float = 0.0
	while senarai_semak.size() > 0:
		var semasa = senarai_semak.pop_back()
		if not is_instance_valid(semasa) or semasa in solar_bersambung: continue
		solar_bersambung.append(semasa)
		jumlah_supply += semasa.power_production if "power_production" in semasa else 100.0
		var had_cantuman = semasa.jarak_cantuman if "jarak_cantuman" in semasa else 300.0
		var pos_semasa = semasa.global_position
		for solar_lain in semua_solar:
			if is_instance_valid(solar_lain) and not (solar_lain in solar_bersambung):
				solar_lain.force_update_transform()
				if solar_lain.global_position == Vector2.ZERO and pos_inverter != Vector2.ZERO: continue 
				if pos_semasa.distance_to(solar_lain.global_position) <= had_cantuman and not (solar_lain in senarai_semak):
					if solar_lain.inverter_pembeli == null or solar_lain.inverter_pembeli == self:
						senarai_semak.append(solar_lain)
						solar_lain.set_owner_inverter(self)

	for solar in semua_solar:
		if is_instance_valid(solar) and solar.inverter_pembeli == self and not (solar in solar_bersambung):
			solar.release_owner_inverter(self)

	var semua_perabot_game = get_tree().get_nodes_in_group("Furniture")
	var jumlah_requirement: float = 0.0
	var tenaga_tersedia_semasa = jumlah_supply
	for perabot in semua_perabot_game:
		if is_instance_valid(perabot) and perabot.is_inside_tree() and "power_required" in perabot:
			perabot.force_update_transform()
			if global_position.distance_to(perabot.global_position) <= radius_inverter_to_furniture:
				if not perabot.has_power or perabot.inverter_pembekal == self:
					jumlah_requirement += perabot.power_required
					if perabot.has_method("set_power_status"):
						if tenaga_tersedia_semasa >= perabot.power_required and jumlah_supply > 0:
							perabot.set_power_status(true, self)
							tenaga_tersedia_semasa -= perabot.power_required 
						else:
							perabot.set_power_status(false, self)
			else:
				if perabot.inverter_pembekal == self and perabot.has_method("set_power_status"):
					perabot.set_power_status(false, self)

	var baki_dikira = jumlah_supply - jumlah_requirement
	if total_power_supply != jumlah_supply or total_power_requirement != jumlah_requirement or baki_tenaga != baki_dikira:
		total_power_supply = jumlah_supply
		total_power_requirement = jumlah_requirement
		baki_tenaga = baki_dikira
		_kemas_kini_paparan_skrin()

func _set_kuasa_kosong() -> void:
	if total_power_supply != 0.0 or total_power_requirement != 0.0:
		total_power_supply = 0.0
		total_power_requirement = 0.0
		baki_tenaga = 0.0
		_kemas_kini_paparan_skrin()

func _kemas_kini_paparan_skrin() -> void:
	if not is_instance_valid(bacaan_kuasa): return
	bacaan_kuasa.text = "Used: " + str(total_power_requirement) + "W / " + str(total_power_supply) + "W\nBal: " + str(baki_tenaga) + "W"
	if baki_tenaga < 0: bacaan_kuasa.modulate = warna_overload
	elif baki_tenaga == 0 and total_power_supply == 0: bacaan_kuasa.modulate = warna_kosong
	else: bacaan_kuasa.modulate = warna_selamat

func _kemas_kini_status_perabot_tiada_kuasa() -> void:
	for perabot in get_tree().get_nodes_in_group("Furniture"):
		if is_instance_valid(perabot) and perabot.inverter_pembekal == self and perabot.has_method("set_power_status"):
			perabot.set_power_status(false, self)

func _bebaskan_semua_solar_milik_saya() -> void:
	for solar in get_tree().get_nodes_in_group("SolarModule"):
		if is_instance_valid(solar) and solar.inverter_pembeli == self:
			solar.release_owner_inverter(self)

func _on_body_entered(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = true
		if sprite: sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)

func _on_body_exited(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = false
		if sprite: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var menu_ui = get_node_or_null("CanvasLayer/MenuUI")
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
		var menu_ui = get_node_or_null("CanvasLayer/MenuUI")
		if menu_ui:
			menu_ui.visible = !menu_ui.visible
		get_viewport().set_input_as_handled()

func _on_butang_tutup_pressed():
	var menu_ui = get_node_or_null("CanvasLayer/MenuUI")
	if menu_ui: menu_ui.hide()

func _on_butang_demolish_pressed():
	_kemas_kini_status_perabot_tiada_kuasa()
	_bebaskan_semua_solar_milik_saya()
	player_dekat = false
	if sprite: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	queue_free()

func get_save_data() -> Dictionary:
	var data_inverter: Dictionary = {}
	if save_component and save_component.has_method("get_data"):
		data_inverter = save_component.get_data()
	data_inverter["scene_path"] = scene_file_path  
	data_inverter["pos_x"] = global_position.x     
	data_inverter["pos_y"] = global_position.y     
	return data_inverter

func load_save_data(data: Dictionary) -> void:
	if data.has("global_position"):
		global_position = data["global_position"]
