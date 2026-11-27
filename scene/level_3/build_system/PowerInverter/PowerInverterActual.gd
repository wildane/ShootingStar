extends StaticBody2D

const TemaPerabot := preload("res://scene/ui/TemaPerabot.gd")
const PowerGridRef := preload("res://scene/level_3/build_system/PowerInverter/PowerGrid.gd")
const REPAIR := preload("res://scene/level_3/build_system/RepairStruktur.gd")
const PANEL_REPAIR := preload("res://scene/level_3/build_system/PanelRepair.gd")

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

## Panel baiki di atas butang menu (kelihatan hanya bila inverter rosak).
var _panel_repair = null

var masa_semakan_terakhir: float = 0.0
const SELA_MASA_SEMAKAN: float = 0.15

# Bendera serasi lama; sumber kebenaran kini PowerGrid.
var _grid_kotor: bool = true

static func tanda_grid_kotor(tree: SceneTree) -> void:
	if tree:
		PowerGridRef.tanda_kotor_semua("tanda_grid_kotor")

func tanda_kotor() -> void:
	_grid_kotor = true
	PowerGridRef.tanda_kotor_inverter(self, "tanda_kotor")

func _ready():
	add_to_group("PowerInverter")
	_pastikan_debug_overlay()
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

	if menu_ui:
		menu_ui.hide()
		TemaPerabot.pasang(menu_ui)
	if bt_tutup: bt_tutup.pressed.connect(_on_butang_tutup_pressed)
	if bt_demo: bt_demo.pressed.connect(_on_butang_demolish_pressed)
	_bina_panel_repair()

	_grid_kotor = true
	_kemas_kini_paparan_skrin()
	PowerGridRef.daftar_inverter(self)

func _physics_process(_delta: float) -> void:
	if not PowerGridRef.perlu_kira() and not _grid_kotor:
		return
	var masa_sekarang = Time.get_ticks_msec() / 1000.0
	if masa_sekarang - masa_semakan_terakhir < SELA_MASA_SEMAKAN:
		return
	masa_semakan_terakhir = masa_sekarang
	_grid_kotor = false
	PowerGridRef.proses(get_tree())

func kira_grid_kuasa_lokal() -> void:
	# Kekalkan API sedia ada. Kiraan sebenar dipusatkan di PowerGrid.
	PowerGridRef.tanda_kotor_semua("kira_grid_kuasa_lokal")
	PowerGridRef.proses(get_tree(), true)

static func kira_semua_grid(tree: SceneTree) -> void:
	PowerGridRef.tanda_kotor_semua("kira_semua_grid")
	PowerGridRef.proses(tree, true)

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
		if is_instance_valid(perabot) and "inverter_pembekal" in perabot and perabot.inverter_pembekal == self and perabot.has_method("set_power_status"):
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
			if menu_ui.visible:
				_segarkan_repair()
		get_viewport().set_input_as_handled()

func _on_butang_tutup_pressed():
	var menu_ui = get_node_or_null("CanvasLayer/MenuUI")
	if menu_ui: menu_ui.hide()

# Panel baiki: bahan repair + butang Repair di atas butang tutup/demolish.
func _bina_panel_repair() -> void:
	var menu_ui = get_node_or_null("CanvasLayer/MenuUI")
	if menu_ui == null:
		return
	var vbox := menu_ui.get_node_or_null("VBoxContainer")
	if vbox == null:
		return
	_panel_repair = PANEL_REPAIR.new()
	vbox.add_child(_panel_repair)
	vbox.move_child(_panel_repair, 1)
	_panel_repair.sediakan(self)
	_panel_repair.selesai_baiki.connect(_segarkan_repair)

func _segarkan_repair() -> void:
	if is_instance_valid(_panel_repair):
		_panel_repair.segarkan()

# Kos bina ikut PowerInverter_Preview.tscn: 2 Meteorite Ice + 3 Basic Iron Ore.
func kos_bina() -> Array:
	return [
		{"id": "item_0002", "nama": "Meteorite Ice", "ikon": load("res://scene/Item/0002MeteoriteIce/Image_393.png"), "scene_path": "res://scene/Item/0002MeteoriteIce/MeteoriteIce.tscn", "diperlukan": 2},
		{"id": "item_0001", "nama": "Basic Iron Ore", "ikon": load("res://scene/Item/0001BasicIronOre/Image_959.png"), "scene_path": "res://scene/Item/0001BasicIronOre/0001BasicIronOre.tscn", "diperlukan": 3},
	]

func _on_butang_demolish_pressed():
	# Pulangkan bahan bina (popup "+N <nama>") sebelum inverter dibuang.
	# Inverter yang rosak dirobohkan tanpa pulangan bahan langsung.
	if not REPAIR.rosak(self):
		BahanBinaan.pulangkan(self)
	_kemas_kini_status_perabot_tiada_kuasa()
	_bebaskan_semua_solar_milik_saya()
	player_dekat = false
	if sprite: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	PowerGridRef.nyahdaftar_inverter(self)
	queue_free()

func _exit_tree() -> void:
	# Lepaskan pemilikan dan pastikan grid/perabot tidak tersekat dengan rujukan lama.
	var tree = get_tree()
	if tree == null:
		return
	for solar in tree.get_nodes_in_group("SolarModule"):
		if is_instance_valid(solar) and solar.inverter_pembeli == self:
			solar.release_owner_inverter(self)
	for perabot in tree.get_nodes_in_group("Furniture"):
		if not is_instance_valid(perabot) or perabot.is_queued_for_deletion():
			continue
		var pembekal = perabot.inverter_pembekal if "inverter_pembekal" in perabot else null
		if pembekal == self and perabot.has_method("set_power_status"):
			perabot.set_power_status(false, null)
	PowerGridRef.nyahdaftar_inverter(self)

func _pastikan_debug_overlay() -> void:
	var tree = get_tree()
	if tree == null:
		return
	if tree.root.find_child("PowerDebugOverlay", true, false) != null:
		return
	var skrip = load("res://scene/level_3/build_system/PowerInverter/PowerDebugOverlay.gd")
	if skrip == null:
		return
	var nod = CanvasLayer.new()
	nod.set_script(skrip)
	tree.root.call_deferred("add_child", nod)
