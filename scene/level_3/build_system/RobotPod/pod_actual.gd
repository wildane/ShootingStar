extends StaticBody2D
## Robot Pod: perabot tempat robot pekerja dibuat dan tempat robot mengecas.
##
## - Perlu kuasa dari Power Inverter (sama macam perabot lain). Tanpa kuasa
##   ia tidak boleh craft robot dan tidak boleh mengecas.
## - Semasa robot mengecas, robot itu masuk ke dalam pod, disembunyikan, dan
##   pod melukisnya baring di dalam kanopi kaca dengan bar tenaga di atas.

const SkripReka := preload("res://scene/level_3/build_system/RobotPod/RekaPod.gd")
const SkripRekaRobot := preload("res://scene/robot/RekaRobot.gd")
const ADEGAN_ROBOT: String = "res://scene/robot/RobotPekerja.tscn"

@onready var save_component = $SaveComponent
@onready var area_penderia = get_node_or_null("Area2D")
@onready var menu_ui = get_node_or_null("CanvasLayer/MenuUI")
@onready var label_status = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/LabelStatus")
@onready var label_bahan = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/LabelBahan")
@onready var butang_craft = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/ButtonCraft")
@onready var butang_tutup = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonTutup")
@onready var butang_demolish = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonDemolish")

@export_category("Sistem Kuasa")
@export var power_required: float = 40.0
var has_power: bool = false
var inverter_pembekal: Node2D = null

var player_dekat: bool = false
var masa_ketikan_terakhir: float = 0.0
const SELA_MASA_MINIMUM: float = 0.2

# Resipi robot pekerja. Bahan dipotong dari InventoryManager.
const RESIPI_ROBOT: Dictionary = {
	"nama": "Mining Robot",
	"bahan": [
		{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 10},
		{"id": "item_0003", "nama": "Raw Silica", "kuantiti": 4},
		{"id": "item_0004", "nama": "Rock Anomaly (Geode)", "kuantiti": 2},
	],
}

# Robot yang sedang mengecas di dalam pod (null bila kosong).
var _robot_dock: Node2D = null
var _masa_anim: float = 0.0


func _ready() -> void:
	add_to_group("Furniture")
	# Robot pekerja cari stesen melalui group ini untuk mengecas tenaga.
	add_to_group("StesenCas")
	# Penanda supaya robot tahu stesen ini boleh "menelan" robot semasa cas.
	add_to_group("PodRobot")

	if area_penderia:
		area_penderia.input_pickable = true
		area_penderia.body_entered.connect(_on_body_entered)
		area_penderia.body_exited.connect(_on_body_exited)
		area_penderia.input_event.connect(_on_area_input_event)

	if menu_ui:
		menu_ui.hide()
	if butang_tutup: butang_tutup.pressed.connect(_on_butang_tutup_pressed)
	if butang_demolish: butang_demolish.pressed.connect(_on_butang_demolish_pressed)
	if butang_craft: butang_craft.pressed.connect(_on_butang_craft_pressed)

	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_dikemaskini"):
		if not inv.inventory_dikemaskini.is_connected(_kemas_kini_menu):
			inv.inventory_dikemaskini.connect(_kemas_kini_menu)

	_kemas_kini_warna_visual()
	_kemas_kini_menu()
	_auto_save_selepas_wujud()


func _process(delta: float) -> void:
	_masa_anim += delta
	if _robot_dock != null and (not is_instance_valid(_robot_dock) or _robot_dock.is_queued_for_deletion()):
		_robot_dock = null
	queue_redraw()


# ==========================================================
# LUKISAN POD + ROBOT YANG SEDANG MENCAS
# ==========================================================
func _draw() -> void:
	for lapisan in SkripReka.lapisan_belakang(has_power):
		_lukis(lapisan)

	var ada_robot: bool = is_instance_valid(_robot_dock)
	var degup: float = 0.5 + 0.5 * sin(_masa_anim * 3.5)
	if ada_robot:
		var nisbah: float = clampf(
			float(_robot_dock.tenaga) / maxf(1.0, float(_robot_dock.tenaga_maks)), 0.0, 1.0
		)
		# Halo tenaga di sekitar robot.
		draw_circle(Vector2(0.0, -12.5), 9.0 + degup * 2.0, Color(0.45, 0.85, 1.0, 0.10))

		# Robot baring di dalam pod (pose mendatar RekaRobot sudah baring).
		draw_set_transform(Vector2(-1.5, -12.5), 0.0, Vector2(0.46, 0.46))
		for lapisan in SkripRekaRobot.bentuk(1.0, SkripRekaRobot.AKSEN_CAS, 0.0, 0.0, 0.0, degup):
			_lukis(lapisan)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Kanopi kaca menutup robot: nampak seperti baring dalam pod.
		for lapisan in SkripReka.lapisan_kaca():
			_lukis(lapisan)

		_lukis_bar_tenaga(nisbah)


func _lukis(lapisan: Dictionary) -> void:
	if str(lapisan.get("jenis", "")) == "bulatan":
		draw_circle(lapisan["pusat"], float(lapisan["jejari"]), lapisan["warna"], true, -1.0, true)
	else:
		draw_colored_polygon(lapisan["titik"], lapisan["warna"])


# Bar tenaga di atas pod semasa robot mengecas.
func _lukis_bar_tenaga(nisbah: float) -> void:
	var lebar: float = 26.0
	var tinggi: float = 3.2
	var asas := Vector2(-lebar * 0.5, -32.0)
	draw_rect(Rect2(asas, Vector2(lebar, tinggi)), Color(0.0, 0.0, 0.0, 0.75))
	if nisbah > 0.0:
		draw_rect(
			Rect2(asas + Vector2(0.5, 0.5), Vector2((lebar - 1.0) * nisbah, tinggi - 1.0)),
			Color(0.45, 0.85, 1.0)
		)
	draw_rect(Rect2(asas, Vector2(lebar, tinggi)), Color(0.45, 0.85, 1.0, 0.85), false, 0.5)


# ==========================================================
# API POD UNTUK ROBOT
# ==========================================================
# Dipanggil RobotPekerja bila ia sampai dan mula mengecas.
func masuk_pod(robot: Node2D) -> void:
	_robot_dock = robot
	queue_redraw()


# Dipanggil RobotPekerja bila cas penuh / robot keluar.
func keluar_pod() -> void:
	_robot_dock = null
	queue_redraw()


func posisi_parkir() -> Vector2:
	return global_position + Vector2(0.0, -12.0)


func posisi_keluar() -> Vector2:
	return global_position + Vector2(0.0, -34.0)


# ==========================================================
# KUASA
# ==========================================================
func set_power_status(status_elektrik: bool, pembekal: Node2D = null) -> void:
	has_power = status_elektrik
	if status_elektrik:
		inverter_pembekal = pembekal
	else:
		if inverter_pembekal == pembekal or pembekal == null:
			inverter_pembekal = null
	# Kuasa terputus semasa robot mengecas: keluarkan robot dari pod.
	if not has_power and is_instance_valid(_robot_dock) and _robot_dock.has_method("keluar_dari_pod"):
		_robot_dock.call("keluar_dari_pod")
	_kemas_kini_warna_visual()
	_kemas_kini_menu()


func _kemas_kini_warna_visual() -> void:
	if player_dekat:
		modulate = Color(0.85, 1.0, 0.9, 1.0)
	elif has_power:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(0.45, 0.45, 0.5, 1.0)
	queue_redraw()


func _kemas_kini_menu() -> void:
	if label_status == null:
		return
	if has_power:
		label_status.text = "Power: ON"
		label_status.modulate = Color(0.35, 1.0, 0.45)
	else:
		label_status.text = "Power: OFF"
		label_status.modulate = Color(1.0, 0.4, 0.4)

	if label_bahan != null:
		var teks: String = ""
		for bahan in RESIPI_ROBOT["bahan"]:
			teks += str(bahan["nama"]) + " " + str(_bilangan_dalam_beg(str(bahan["id"]))) + "/" + str(int(bahan["kuantiti"])) + "\n"
		label_bahan.text = teks.strip_edges()

	if butang_craft != null:
		if _robot_wujud():
			butang_craft.text = "Already crafted"
			butang_craft.disabled = true
		elif not has_power:
			butang_craft.text = "No power"
			butang_craft.disabled = true
		elif _bahan_cukup():
			butang_craft.text = "Craft Robot"
			butang_craft.disabled = false
		else:
			butang_craft.text = "Not enough materials"
			butang_craft.disabled = true


# ==========================================================
# CRAFT ROBOT
# ==========================================================
func _bilangan_dalam_beg(id_item: String) -> int:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return 0
	return inv.bilangan_item(id_item)


func _robot_wujud() -> bool:
	for nod in get_tree().get_nodes_in_group("RobotPekerja"):
		if is_instance_valid(nod) and not nod.is_queued_for_deletion():
			return true
	return false


func _bahan_cukup() -> bool:
	for bahan in RESIPI_ROBOT["bahan"]:
		if _bilangan_dalam_beg(str(bahan["id"])) < int(bahan["kuantiti"]):
			return false
	return true


func _on_butang_craft_pressed() -> void:
	if not has_power:
		_tulis_info("Robot Pod has no power - connect it to a power inverter")
		return
	if _robot_wujud():
		_tulis_info("A worker robot already exists")
		return
	if not _bahan_cukup():
		_tulis_info("Not enough materials for " + str(RESIPI_ROBOT["nama"]))
		return

	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return
	for bahan in RESIPI_ROBOT["bahan"]:
		inv.tolak_item(str(bahan["id"]), int(bahan["kuantiti"]))

	_cipta_robot()
	_kemas_kini_menu()
	_tulis_info(str(RESIPI_ROBOT["nama"]) + " built! It is heading out to mine meteorites.")


func _cipta_robot() -> void:
	if not ResourceLoader.exists(ADEGAN_ROBOT):
		return
	var adegan := load(ADEGAN_ROBOT) as PackedScene
	if adegan == null:
		return
	var robot := adegan.instantiate()
	var adegan_utama := get_tree().current_scene
	if adegan_utama == null:
		return
	var induk := adegan_utama.get_node_or_null("Y_Sort_Container")
	if induk == null:
		induk = adegan_utama
	induk.add_child(robot)
	robot.global_position = global_position + Vector2(28.0, -14.0)
	if get_node_or_null("/root/SaveManager"):
		SaveManager.save_game()


func _tulis_info(teks: String) -> void:
	var adegan := get_tree().current_scene
	if adegan == null:
		return
	var lbl := adegan.find_child("InfoText", true, false) as Label
	if lbl == null:
		return
	lbl.text = teks
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(lbl) and lbl.text == teks:
		lbl.text = ""


# ==========================================================
# PENDERIA DAN INPUT
# ==========================================================
func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_dekat = true
		_kemas_kini_warna_visual()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_dekat = false
		_kemas_kini_warna_visual()
		if menu_ui:
			menu_ui.hide()


# AstroStateMachine menandakan setiap klik kiri mouse sebagai "handled" dalam
# _unhandled_input, jadi physics picking Area2D dibatalkan pada PC. _input
# berjalan lebih awal, jadi klik dihantar sebagai sentuhan maya.
func _input(event: InputEvent) -> void:
	var klik := event as InputEventMouseButton
	if klik == null or not klik.pressed or klik.button_index != MOUSE_BUTTON_LEFT:
		return
	if not player_dekat or area_penderia == null:
		return
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


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var ada_sentuhan = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if ada_sentuhan and player_dekat:
		var masa_sekarang = Time.get_ticks_msec() / 1000.0
		if masa_sekarang - masa_ketikan_terakhir < SELA_MASA_MINIMUM:
			return
		masa_ketikan_terakhir = masa_sekarang
		if menu_ui:
			if menu_ui.visible:
				_tutup_menu()
			else:
				_buka_menu()
		get_viewport().set_input_as_handled()


func _buka_menu() -> void:
	if menu_ui == null:
		return
	_kemas_kini_menu()
	menu_ui.visible = true


func _tutup_menu() -> void:
	if menu_ui:
		menu_ui.hide()


func _on_butang_tutup_pressed() -> void:
	_tutup_menu()


func _on_butang_demolish_pressed() -> void:
	# Robot yang sedang mengecas keluar semula sebelum pod dimusnahkan.
	if is_instance_valid(_robot_dock) and _robot_dock.has_method("keluar_dari_pod"):
		_robot_dock.call("keluar_dari_pod")
	_robot_dock = null
	player_dekat = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	queue_free()
	await get_tree().process_frame
	if get_node_or_null("/root/SaveManager"):
		SaveManager.save_game()


func _exit_tree() -> void:
	if is_instance_valid(_robot_dock) and _robot_dock.has_method("keluar_dari_pod"):
		_robot_dock.call("keluar_dari_pod")
	_robot_dock = null


# ==========================================================
# SAVE
# ==========================================================
func get_save_data() -> Dictionary:
	var data_pod: Dictionary = {}
	if save_component and save_component.has_method("get_data"):
		data_pod = save_component.get_data()
	data_pod["scene_path"] = scene_file_path
	data_pod["pos_x"] = global_position.x
	data_pod["pos_y"] = global_position.y
	return data_pod


func load_save_data(data: Dictionary) -> void:
	if data.has("global_position"):
		global_position = data["global_position"]


func _auto_save_selepas_wujud() -> void:
	await get_tree().process_frame
	if get_node_or_null("/root/SaveManager"):
		SaveManager.save_game()
