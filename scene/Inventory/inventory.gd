# ==========================================================
# FAIL: inventory_ui.gd (Versi Pembaikan Paparan Anti-Float)
# ==========================================================
class_name InventoryUI
extends Control

# --- EXPORTED CONFIGURATIONS ---
@export var ukuran_slot : Vector2 = Vector2(64, 64)
@export var saiz_fon_stack : int = 14
@export var had_maksimum_slot : int = 24

# Pembolehubah rujukan node utama
var close_button: Button = null
var grid_container: GridContainer = null
var info_label: Label = null
var search_line_edit: LineEdit = null
var teks_carian_semasa: String = ""

func _ready():
	self.visible = false
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	
	close_button = find_child("CloseButton", true, false) as Button
	grid_container = find_child("GridContainer", true, false) as GridContainer
	
	if has_node("%InfoText"):
		info_label = get_node("%InfoText") as Label
		info_label.text = "" 
	else:
		print("Sistem Amaran: Nod %InfoText gagal dijumpai!")
	
	# CIPTA BAR CARIAN
	search_line_edit = LineEdit.new()
	search_line_edit.name = "Search"
	search_line_edit.placeholder_text = " Search..."
	search_line_edit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	search_line_edit.add_theme_font_size_override("font_size", saiz_fon_stack)
	search_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_line_edit.custom_minimum_size = Vector2(0, ukuran_slot.y)
	search_line_edit.virtual_keyboard_enabled = true
	search_line_edit.text_changed.connect(_on_search_text_changed)
	
	var parent_grid = grid_container.get_parent()
	if parent_grid != null:
		if not parent_grid is VBoxContainer:
			var container_baru = VBoxContainer.new()
			container_baru.name = "SusunanInventory"
			container_baru.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container_baru.size_flags_vertical = Control.SIZE_EXPAND_FILL
			container_baru.add_theme_constant_override("separation", 6)
			
			parent_grid.add_child(container_baru)
			grid_container.get_parent().remove_child(grid_container)
			
			container_baru.add_child(search_line_edit)
			container_baru.add_child(grid_container)
		else:
			parent_grid.add_child(search_line_edit)
			parent_grid.move_child(search_line_edit, 0)
	
	var margin_cont = find_child("MarginContainer", true, false)
	if margin_cont != null: margin_cont.mouse_filter = Control.MOUSE_FILTER_PASS
		
	var inv_panel = find_child("InventoryPanel", true, false)
	if inv_panel != null: inv_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		
	if close_button != null: close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager and inv_manager.has_signal("inventory_dikemaskini"):
		if not inv_manager.inventory_dikemaskini.is_connected(kemaskini_paparan_barang):
			inv_manager.inventory_dikemaskini.connect(kemaskini_paparan_barang)
	
	call_deferred("kemaskini_paparan_barang")

func show_inventory():
	self.visible = true
	_kosongkan_info()
	kemaskini_paparan_barang()

func kemaskini_paparan_barang():
	if grid_container == null:
		return
	# UI tertutup: tak perlu bina semula grid. Ia akan dibina apabila
	# show_inventory() dipanggil, jadi tiada kos semasa bermain.
	if not is_visible_in_tree():
		return
		
	for child in grid_container.get_children():
		child.queue_free()
	
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if not inv_manager: return
	
	var senarai_asal = inv_manager.senarai_barang
	var senarai_ditapis = []
	
	for barang: Dictionary in senarai_asal:
		var nama_barang = barang.get("nama", "").to_lower()
		if teks_carian_semasa == "" or teks_carian_semasa in nama_barang:
			senarai_ditapis.append(barang)
			
	print("UI Beg: Membina grid penuh. Barangan sepadan carian = ", senarai_ditapis.size())
	
	for i in range(had_maksimum_slot):
		var slot_tapak = PanelContainer.new()
		slot_tapak.custom_minimum_size = ukuran_slot 
		slot_tapak.mouse_filter = Control.MOUSE_FILTER_STOP
		
		if i < senarai_ditapis.size():
			var barang: Dictionary = senarai_ditapis[i]
			
			var visual_ikon = TextureRect.new()
			visual_ikon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			visual_ikon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			visual_ikon.custom_minimum_size = ukuran_slot
			
			var gambar_ikon = barang.get("ikon", null)
			if gambar_ikon and gambar_ikon is Texture2D:
				visual_ikon.texture = gambar_ikon
			else:
				var gambar_test = PlaceholderTexture2D.new()
				gambar_test.size = ukuran_slot
				visual_ikon.texture = gambar_test
				
			slot_tapak.add_child(visual_ikon)
			
			# 🔥 DIPERBAIKI: Mengunci nilai kuantiti sebagai Integer tulen untuk memadam .0
			var kuantiti_barang = int(barang.get("kuantiti", 1))
			if kuantiti_barang > 1:
				var label_kuantiti = Label.new()
				label_kuantiti.name = "KuantitiLabel"
				label_kuantiti.text = str(kuantiti_barang)
				label_kuantiti.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				label_kuantiti.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				label_kuantiti.add_theme_font_size_override("font_size", saiz_fon_stack)
				label_kuantiti.add_theme_color_override("font_outline_color", Color.BLACK)
				label_kuantiti.add_theme_constant_override("outline_size", 4)
				label_kuantiti.grow_horizontal = Control.GROW_DIRECTION_BEGIN
				label_kuantiti.grow_vertical = Control.GROW_DIRECTION_BEGIN
				label_kuantiti.anchors_preset = Control.PRESET_FULL_RECT
				slot_tapak.add_child(label_kuantiti)
				
			var data_klik = {
				"id": barang.get("id", "unknown"), 
				"nama": barang.get("nama", "Unnamed Item"), 
				"kuantiti": kuantiti_barang
			}
			slot_tapak.gui_input.connect(_on_slot_berisi_diklik.bind(data_klik))
				
		else:
			var empty_space = Control.new()
			empty_space.custom_minimum_size = ukuran_slot
			slot_tapak.add_child(empty_space)
			slot_tapak.gui_input.connect(_on_slot_kosong_diklik)
			
		grid_container.add_child(slot_tapak)

func _on_slot_berisi_diklik(event: InputEvent, barang_dipilih: Dictionary):
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			accept_event()
			var nama_item = barang_dipilih.get("nama", "Unnamed")
			var id_item = barang_dipilih.get("id", "Unknown")
			var kuantiti_item = int(barang_dipilih.get("kuantiti", 1)) # 🔥 Paksa int di panel tepi juga
			
			print("Sentuh slot carian: ", nama_item)
			
			if info_label != null:
				var teks_info : String = "Name: " + str(nama_item) + "\n"
				teks_info += "ID: " + str(id_item) + "\n"
				teks_info += "Amount: " + str(kuantiti_item) + " units"
				info_label.text = teks_info

func _on_slot_kosong_diklik(event: InputEvent):
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			accept_event()
			_kosongkan_info()

func _on_search_text_changed(new_text: String):
	teks_carian_semasa = new_text.strip_edges().to_lower()
	_kosongkan_info()
	kemaskini_paparan_barang()

func _gui_input(event: InputEvent):
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed: 
			accept_event()
			_kosongkan_info()

func _unhandled_input(event: InputEvent):
	if self.visible and (event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)):
		if event.pressed: 
			_kosongkan_info()

func _kosongkan_info():
	if info_label != null and info_label.text != "":
		info_label.text = ""
		print("Sistem: Panel info dikosongkan.")
