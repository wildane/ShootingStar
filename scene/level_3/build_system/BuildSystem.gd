extends Control # 💡 KAWALAN PANEL MENU UI SAHAJA!

# ==========================================================
# 🔌 RUTUAN NOD UI (LOCAL UI REFERENCES)
# ==========================================================
@onready var build_button = $HBoxContainer/BuildButton
@onready var items_panel = $HBoxContainer/ItemsPanel

# Mencari inventory menggunakan Unique Name (%)
@onready var inventory_ui: Control = get_node_or_null("%Inventory")

# ==========================================================
# 📊 PEMBOLEH UBAH SISTEM (SYSTEM VARIABLES)
# ==========================================================
var menu_terbuka: bool = false

# ==========================================================
# 🚀 PROSES AWALAN (READY FUNCTION)
# ==========================================================
func _ready():
	build_button.pressed.connect(_on_build_button_pressed)

	# Set keadaan awal panel (sembunyi/kosong)
	items_panel.visible = false
	items_panel.modulate.a = 0.0
	items_panel.scale.x = 0.0

	# Nama ringkas di bawah setiap ikon bangunan
	_tambah_label_ikon()

	# Panel ikon dijadikan overlay (top_level) supaya ia TIDAK memberi
	# tekanan saiz pada baris butang. Tanpa ini, HBoxContainer membesar
	# bila panel dibuka dan butang tukul nampak "turun ke bawah".
	items_panel.top_level = true
	items_panel.pivot_offset = Vector2.ZERO

# Nama pendek supaya muat dalam sel 32 px
const NAMA_IKON: Dictionary = {
	"ResearchTableButton": "Research",
	"FabricatorButton": "Fabricator",
	"SmelterButton": "Smelter",
	"KitchenTableButton": "Kitchen",
	"SolarModuleButton": "Solar",
	"PowerInverterButton": "Inverter",
	"ChargingStationButton": "Charger",
}

func _tambah_label_ikon() -> void:
	var grid: Node = items_panel.get_node_or_null("MarginContainer/HBoxContainer")
	if grid == null:
		return
	# Setiap butang dibalut dalam VBox + label nama di bawahnya.
	for kanak in grid.get_children():
		if not (kanak is Control):
			continue
		var bekas := VBoxContainer.new()
		bekas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bekas.add_theme_constant_override("separation", 0)
		var idx: int = kanak.get_index()
		grid.add_child(bekas)
		grid.move_child(bekas, idx)
		kanak.reparent(bekas, false)

		var label := Label.new()
		label.text = NAMA_IKON.get(str(kanak.name), "")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.custom_minimum_size = Vector2(32, 8)
		label.add_theme_font_size_override("font_size", 5)
		label.add_theme_color_override("font_color", Color(0.86, 0.95, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06))
		label.add_theme_constant_override("outline_size", 2)
		bekas.add_child(label)

# ==========================================================
# 📱 KAWALAN PANEL MENU UI (EXPAND / COLLAPSE)
# ==========================================================
func _on_build_button_pressed():
	# Telefon tiada klik kanan: butang build ini jadi butang BATAL
	# bila mod pembinaan sedang aktif (semua jenis bangunan).
	if BuildManager.mod_pembinaan:
		BuildManager.batal_pembinaan()
		tutup_menu_cepat()
		return

	menu_terbuka = !menu_terbuka
	var tween = create_tween().set_parallel(true)
	
	if menu_terbuka:
		_tutup_menu_lain()
		var saiz: Vector2 = items_panel.get_combined_minimum_size()
		items_panel.size = saiz if saiz != Vector2.ZERO else Vector2(96, 84)
		items_panel.global_position = build_button.global_position + Vector2(build_button.size.x, 0.0)
		items_panel.visible = true
		tween.tween_property(items_panel, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(items_panel, "modulate:a", 1.0, 0.2)
		build_button.text = ""
	else:
		tutup_menu_cepat()

func tutup_menu_cepat():
	menu_terbuka = false
	items_panel.scale.x = 0.0
	items_panel.modulate.a = 0.0
	items_panel.visible = false
	build_button.text = ""

# Tutup menu cepat lain (inventori, pilihan dron) supaya tidak bertindih.
# BuildSystem sendiri anak terus VBoxContainer, sama seperti butang lain.
func _tutup_menu_lain():
	var induk: Node = get_parent()
	if induk == null:
		return
	for nod in induk.get_children():
		if nod == self or not (nod is Node):
			continue
		if nod.has_method("tutup_menu_cepat"):
			nod.tutup_menu_cepat()
		elif nod.has_method("tutup_menu"):
			nod.tutup_menu()

func tutup_inventory_jika_terbuka():
	if inventory_ui and inventory_ui.visible:
		if inventory_ui.has_method("hide_inventory"):
			inventory_ui.hide_inventory()
		else:
			inventory_ui.hide()
