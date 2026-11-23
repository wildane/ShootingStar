extends StaticBody2D

## Relau pelebur: 2 Basic Iron Ore + 1 Meteorite Ice -> 1 Steel.
## Semasa melebur, sprite berdenyut warna relau dan ada cahaya api di mulut.

@onready var save_component = $SaveComponent
@onready var sprite = get_node_or_null("Sprite2D")
@onready var area_penderia = get_node_or_null("Area2D")
@onready var menu_ui = get_node_or_null("CanvasLayer/MenuUI")
@onready var butang_tutup = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonTutup")
@onready var butang_demolish = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonDemolish")
@onready var label_status = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/Status")
@onready var bar_progres = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/Progress")
@onready var label_bahan = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/Bahan")
@onready var butang_lebur = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/ButangLebur")

const MASA_LEBUR: float = 4.0

const ID_STEEL := "item_0009"
const LALUAN_STEEL := "res://scene/Item/0009Steel/Steel.tscn"
const IKON_STEEL := "res://scene/Item/0009Steel/Image_steel.png"
const LALUAN_BESI := "res://scene/Item/0001BasicIronOre/Image_959.png"
const LALUAN_AIS := "res://scene/Item/0002MeteoriteIce/Image_393.png"

# Resipi peleburan steel.
@export var resipi: Array[Dictionary] = [
	{"id": "item_0001", "nama": "Basic Iron Ore", "kuantiti": 2, "ikon": LALUAN_BESI},
	{"id": "item_0002", "nama": "Meteorite Ice", "kuantiti": 1, "ikon": LALUAN_AIS},
]

var player_dekat: bool = false
var masa_ketikan_terakhir: float = 0.0
const SELA_MASA_MINIMUM: float = 0.2

# Keadaan peleburan
var sedang_lebur: bool = false
var masa_berlalu: float = 0.0
var masa_hiasan: float = 0.0
var _cahaya: Sprite2D = null
var _skala_asal: Vector2 = Vector2(0.05, 0.05)

func _ready() -> void:
	add_to_group("Furniture")

	if area_penderia:
		area_penderia.input_pickable = true
		area_penderia.body_entered.connect(_on_body_entered)
		area_penderia.body_exited.connect(_on_body_exited)
		area_penderia.input_event.connect(_on_area_input_event)

	if menu_ui:
		menu_ui.hide()

	if butang_tutup: butang_tutup.pressed.connect(_on_butang_tutup_pressed)
	if butang_demolish: butang_demolish.pressed.connect(_on_butang_demolish_pressed)
	if butang_lebur: butang_lebur.pressed.connect(_on_butang_lebur_pressed)

	if sprite:
		_skala_asal = sprite.scale

	_bina_cahaya()
	_kemas_kini_ui()

	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_dikemaskini"):
		if not inv.inventory_dikemaskini.is_connected(_kemas_kini_ui):
			inv.inventory_dikemaskini.connect(_kemas_kini_ui)

# Cahaya api di muncung relau (dibina dalam kod, tiada aset tambahan).
func _bina_cahaya() -> void:
	_cahaya = Sprite2D.new()
	_cahaya.name = "CahayaLebur"
	var gradien := Gradient.new()
	gradien.set_color(0, Color(1.0, 0.62, 0.22, 0.85))
	gradien.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	var tekstur := GradientTexture2D.new()
	tekstur.gradient = gradien
	tekstur.fill = GradientTexture2D.FILL_RADIAL
	tekstur.fill_from = Vector2(0.5, 0.5)
	tekstur.fill_to = Vector2(1.0, 0.5)
	tekstur.width = 64
	tekstur.height = 64
	_cahaya.texture = tekstur
	_cahaya.position = Vector2(0, -5)
	_cahaya.scale = Vector2(0.75, 0.75)
	_cahaya.visible = false
	add_child(_cahaya)
	move_child(_cahaya, 0)

func get_save_data() -> Dictionary:
	var data_perabot: Dictionary = {}
	if save_component and save_component.has_method("get_data"):
		data_perabot = save_component.get_data()
	data_perabot["scene_path"] = scene_file_path
	data_perabot["pos_x"] = global_position.x
	data_perabot["pos_y"] = global_position.y
	return data_perabot

# ==========================================================
# CRAFT STEEL
# ==========================================================
func _bilangan_dalam_beg(id_item: String) -> int:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return 0
	return inv.bilangan_item(id_item)

func _bahan_cukup() -> bool:
	for bahan in resipi:
		if _bilangan_dalam_beg(bahan["id"]) < int(bahan["kuantiti"]):
			return false
	return true

func _on_butang_lebur_pressed() -> void:
	if sedang_lebur:
		return
	if not _bahan_cukup():
		_tulis_info("Not enough materials for Steel")
		return
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return
	for bahan in resipi:
		inv.tolak_item(bahan["id"], int(bahan["kuantiti"]))
	sedang_lebur = true
	masa_berlalu = 0.0
	masa_hiasan = 0.0
	if _cahaya:
		_cahaya.visible = true
	_kemas_kini_ui()
	_tulis_info("Smelting Steel...")

# Animasai relau + kemajuan peleburan.
func _process(delta: float) -> void:
	if not sedang_lebur:
		return
	masa_berlalu += delta
	masa_hiasan += delta
	var nisbah: float = clamp(masa_berlalu / MASA_LEBUR, 0.0, 1.0)
	if bar_progres:
		bar_progres.value = nisbah * 100.0
	if butang_lebur:
		butang_lebur.text = "Smelting... %0.1fs" % max(0.0, MASA_LEBUR - masa_berlalu)

	var denyut: float = (sin(masa_hiasan * 7.5) + 1.0) * 0.5
	if sprite:
		sprite.modulate = Color(1.0, 0.78 + 0.22 * denyut, 0.62 + 0.38 * denyut)
		sprite.scale = _skala_asal * (1.0 + 0.05 * denyut)
	if _cahaya:
		_cahaya.modulate.a = 0.55 + 0.45 * denyut
		_cahaya.scale = Vector2.ONE * (0.62 + 0.18 * denyut)

	if nisbah >= 1.0:
		_selesai_lebur()

func _selesai_lebur() -> void:
	sedang_lebur = false
	masa_berlalu = 0.0
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = _skala_asal
	if _cahaya:
		_cahaya.visible = false
	if bar_progres:
		bar_progres.value = 0.0

	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		inv.tambah_item({
			"id": ID_STEEL,
			"nama": "Steel",
			"ikon": load(IKON_STEEL),
			"scene_path": LALUAN_STEEL,
		})
	_kemas_kini_ui()
	_tulis_info("Steel produced! +1")
	print("Smelter: 1 Steel dihasilkan")

# Kandungan menu: senarai bahan (hijau/merah) + status butang.
func _kemas_kini_ui() -> void:
	if label_bahan:
		var teks: String = ""
		for bahan in resipi:
			var ada := _bilangan_dalam_beg(bahan["id"])
			var warna: String = "#7dff86" if ada >= int(bahan["kuantiti"]) or sedang_lebur else "#ff6b6b"
			teks += "[color=%s]%d x %s[/color]\n" % [warna, int(bahan["kuantiti"]), str(bahan["nama"])]
		label_bahan.text = teks

	if label_status and not sedang_lebur:
		label_status.text = "Ready" if _bahan_cukup() else "Need materials"

	if butang_lebur and not sedang_lebur:
		if _bahan_cukup():
			butang_lebur.text = "Smelt Steel"
			butang_lebur.disabled = false
		else:
			butang_lebur.text = "Not enough materials"
			butang_lebur.disabled = true

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
# PENDERIA & INPUT
# ==========================================================
func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_dekat = true
		if sprite:
			sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_dekat = false
		if not sedang_lebur and sprite:
			sprite.modulate = Color.WHITE
		if menu_ui:
			menu_ui.hide()

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
	if not ada_sentuhan or not player_dekat:
		return
	var masa_sekarang = Time.get_ticks_msec() / 1000.0
	if masa_sekarang - masa_ketikan_terakhir < SELA_MASA_MINIMUM:
		return
	masa_ketikan_terakhir = masa_sekarang
	if menu_ui:
		menu_ui.visible = not menu_ui.visible
		if menu_ui.visible:
			_kemas_kini_ui()
	get_viewport().set_input_as_handled()

func _on_butang_tutup_pressed() -> void:
	if menu_ui:
		menu_ui.hide()

func _on_butang_demolish_pressed() -> void:
	sedang_lebur = false
	player_dekat = false
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = _skala_asal
	queue_free()
