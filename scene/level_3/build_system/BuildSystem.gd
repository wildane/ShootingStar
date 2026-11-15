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
		tutup_inventory_jika_terbuka()
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

func tutup_inventory_jika_terbuka():
	if inventory_ui and inventory_ui.visible:
		if inventory_ui.has_method("hide_inventory"):
			inventory_ui.hide_inventory()
		else:
			inventory_ui.hide()
