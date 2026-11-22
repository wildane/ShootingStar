class_name SaveMenu
extends CanvasLayer

## Panel SAVE/LOAD dalam game. Dibuka oleh level_3 dan berjalan walaupun
## SceneTree dipause (process_mode = ALWAYS).

signal ditutup

const MOD_SIMPAN := 0
const MOD_MUAT := 1

var mod_semasa: int = MOD_SIMPAN

var _tajuk: Label
var _petua: Label
var _senarai: VBoxContainer
var _butang_baru: Button
var _butang_tutup: Button
var _status: Label

# Dialog dalam panel: nama simpanan baharu / pengesahan timpa.
var _lapis_dialog: Control
var _dialog_tajuk: Label
var _dialog_mesej: Label
var _input_nama: LineEdit
var _butang_ya: Button
var _id_sasaran: String = ""

func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bina_ui()
	segarkan_senarai()

# ==========================================
# UI
# ==========================================
func _bina_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := NinePatchRect.new()
	panel.texture = load("res://scene/main_menu/panel_menu.png")
	panel.patch_margin_left = 40
	panel.patch_margin_top = 40
	panel.patch_margin_right = 40
	panel.patch_margin_bottom = 40
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -125.0
	panel.offset_top = -175.0
	panel.offset_right = 125.0
	panel.offset_bottom = 175.0
	add_child(panel)

	var isi := VBoxContainer.new()
	isi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	isi.offset_left = 16.0
	isi.offset_top = 16.0
	isi.offset_right = -16.0
	isi.offset_bottom = -16.0
	isi.add_theme_constant_override("separation", 8)
	isi.theme = _bina_tema()
	panel.add_child(isi)

	_tajuk = Label.new()
	_tajuk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tajuk.add_theme_font_size_override("font_size", 13)
	isi.add_child(_tajuk)

	_petua = Label.new()
	_petua.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_petua.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_petua.add_theme_font_size_override("font_size", 8)
	isi.add_child(_petua)

	var skrol := ScrollContainer.new()
	skrol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skrol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	isi.add_child(skrol)

	_senarai = VBoxContainer.new()
	_senarai.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_senarai.add_theme_constant_override("separation", 6)
	skrol.add_child(_senarai)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 8)
	_status.text = ""
	isi.add_child(_status)

	var baris := HBoxContainer.new()
	baris.add_theme_constant_override("separation", 8)
	isi.add_child(baris)

	_butang_baru = Button.new()
	_butang_baru.text = "New Save"
	_butang_baru.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_butang_baru.add_theme_font_size_override("font_size", 10)
	_butang_baru.pressed.connect(_on_butang_baru)
	baris.add_child(_butang_baru)

	_butang_tutup = Button.new()
	_butang_tutup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_butang_tutup.add_theme_font_size_override("font_size", 10)
	_butang_tutup.pressed.connect(_tutup)
	baris.add_child(_butang_tutup)

	_bina_dialog()

# Dialog kecil di atas panel untuk nama simpanan dan pengesahan overwrite.
func _bina_dialog() -> void:
	_lapis_dialog = Control.new()
	_lapis_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lapis_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_lapis_dialog.visible = false
	add_child(_lapis_dialog)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_lapis_dialog.add_child(dim)

	var kotak := NinePatchRect.new()
	kotak.texture = load("res://scene/main_menu/panel_menu.png")
	kotak.patch_margin_left = 40
	kotak.patch_margin_top = 40
	kotak.patch_margin_right = 40
	kotak.patch_margin_bottom = 40
	kotak.anchor_left = 0.5
	kotak.anchor_top = 0.5
	kotak.anchor_right = 0.5
	kotak.anchor_bottom = 0.5
	kotak.offset_left = -110.0
	kotak.offset_top = -80.0
	kotak.offset_right = 110.0
	kotak.offset_bottom = 80.0
	_lapis_dialog.add_child(kotak)

	var isi := VBoxContainer.new()
	isi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	isi.offset_left = 14.0
	isi.offset_top = 14.0
	isi.offset_right = -14.0
	isi.offset_bottom = -14.0
	isi.add_theme_constant_override("separation", 6)
	kotak.add_child(isi)

	_dialog_tajuk = Label.new()
	_dialog_tajuk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_tajuk.add_theme_font_size_override("font_size", 11)
	isi.add_child(_dialog_tajuk)

	_dialog_mesej = Label.new()
	_dialog_mesej.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_mesej.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_mesej.add_theme_font_size_override("font_size", 9)
	_dialog_mesej.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog_mesej.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	isi.add_child(_dialog_mesej)

	_input_nama = LineEdit.new()
	_input_nama.placeholder_text = "Save name"
	_input_nama.custom_minimum_size = Vector2(0, 26)
	_input_nama.add_theme_font_size_override("font_size", 10)
	_input_nama.text_submitted.connect(_on_nama_dihantar)
	isi.add_child(_input_nama)

	var baris := HBoxContainer.new()
	baris.add_theme_constant_override("separation", 8)
	isi.add_child(baris)

	_butang_ya = Button.new()
	_butang_ya.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_butang_ya.add_theme_font_size_override("font_size", 10)
	_butang_ya.pressed.connect(_dialog_ya)
	baris.add_child(_butang_ya)

	var butang_tidak := Button.new()
	butang_tidak.text = "Cancel"
	butang_tidak.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	butang_tidak.add_theme_font_size_override("font_size", 10)
	butang_tidak.pressed.connect(_dialog_tidak)
	baris.add_child(butang_tidak)

func _bina_tema() -> Theme:
	var tema := Theme.new()

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.054, 0.145, 0.211, 0.92)
	normal.border_color = Color(0.36, 0.9, 1, 0.7)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(4.0)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.098, 0.278, 0.38, 0.96)
	hover.border_color = Color(0.5, 0.97, 1, 1)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.2, 0.55, 0.68, 1)
	pressed.border_color = Color(0.75, 1, 1, 1)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.05, 0.09, 0.13, 0.7)
	disabled.border_color = Color(0.25, 0.42, 0.5, 0.5)

	tema.set_stylebox("normal", "Button", normal)
	tema.set_stylebox("hover", "Button", hover)
	tema.set_stylebox("pressed", "Button", pressed)
	tema.set_stylebox("focus", "Button", hover)
	tema.set_stylebox("disabled", "Button", disabled)
	tema.set_font_size("font_size", "Button", 10)
	tema.set_color("font_color", "Button", Color(0.85, 0.97, 1, 1))
	tema.set_color("font_hover_color", "Button", Color(1, 1, 1, 1))
	tema.set_color("font_pressed_color", "Button", Color(0.05, 0.12, 0.16, 1))
	tema.set_color("font_disabled_color", "Button", Color(0.46, 0.56, 0.63, 1))
	tema.set_color("font_color", "Label", Color(0.82, 0.95, 1, 1))
	tema.set_font_size("font_size", "Label", 9)
	return tema

# ==========================================
# SENARAI SLOT
# ==========================================
func segarkan_senarai() -> void:
	for anak in _senarai.get_children():
		_senarai.remove_child(anak)
		anak.queue_free()

	var mod_simpan := mod_semasa == MOD_SIMPAN
	_tajuk.text = "SAVE GAME" if mod_simpan else "LOAD GAME"
	_petua.text = "Tap a save to overwrite it, or use New Save." if mod_simpan else "Tap a save to load it."
	_butang_baru.visible = mod_simpan
	_butang_tutup.text = "Resume" if mod_simpan else "Cancel"
	_status.text = ""

	var jumlah := 0
	for slot in SaveManager.senarai_slot():
		var id := str(slot["id"])
		# Slot autosave tidak boleh ditimpa secara manual.
		if mod_simpan and SaveManager.SLOT_AUTOSAVE.has(id):
			continue
		jumlah += 1
		_senarai.add_child(_bina_baris(slot))

	if jumlah == 0:
		var kosong := Label.new()
		kosong.text = "No saves yet. Use New Save." if mod_simpan else "No saves yet."
		kosong.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kosong.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_senarai.add_child(kosong)

func _bina_baris(slot: Dictionary) -> Control:
	var butang := Button.new()
	butang.text = "%s\n%s" % [str(slot["nama"]), _format_tarikh(float(slot["masa"]))]
	butang.add_theme_font_size_override("font_size", 9)
	butang.custom_minimum_size = Vector2(0, 34)
	butang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	butang.pressed.connect(_on_slot.bind(str(slot["id"])))
	return butang

func _format_tarikh(masa: float) -> String:
	return SaveManager.format_masa(masa)

# ==========================================
# TINDAKAN
# ==========================================
func _on_slot(id: String) -> void:
	if mod_semasa == MOD_SIMPAN:
		# Tanya pengesahan dahulu sebelum menimpa simpanan sedia ada.
		_tanya_timpa(id)
		return

	# Mod Muat: pilih slot, tutup panel dan muat semula level.
	SaveManager.tetapkan_slot(id)
	get_tree().paused = false
	ditutup.emit()
	get_tree().change_scene_to_file("res://scene/level_3/level_3.tscn")

func _on_butang_baru() -> void:
	_tanya_nama()

# ==========================================
# DIALOG NAMA / PENGESAHAN
# ==========================================
func _tanya_nama() -> void:
	_id_sasaran = ""
	_dialog_tajuk.text = "NEW SAVE"
	_dialog_mesej.text = "Give this save a name:"
	_butang_ya.text = "Save"
	_input_nama.visible = true
	_input_nama.text = "Save %d" % (SaveManager.senarai_slot().size() + 1)
	_lapis_dialog.visible = true
	_input_nama.grab_focus()
	_input_nama.select_all()

func _tanya_timpa(id: String) -> void:
	_id_sasaran = id
	_dialog_tajuk.text = "OVERWRITE SAVE"
	_dialog_mesej.text = "Overwrite \"%s\"?\nCurrent progress in that slot will be replaced." % SaveManager.nama_slot(id)
	_butang_ya.text = "Overwrite"
	_input_nama.visible = false
	_lapis_dialog.visible = true

func _on_nama_dihantar(_teks: String) -> void:
	if _lapis_dialog.visible and _input_nama.visible:
		_dialog_ya()

func _dialog_ya() -> void:
	var id_sasaran := _id_sasaran
	var nama := _input_nama.text
	_id_sasaran = ""
	_lapis_dialog.visible = false

	var id := id_sasaran
	if id == "":
		id = SaveManager.simpan_slot_baru(nama)
	elif not SaveManager.simpan_ke_slot(id):
		id = ""

	if id != "":
		segarkan_senarai()
		_status.text = "Saved to %s" % SaveManager.nama_slot(id)
	else:
		_status.text = "Cannot save right now"

func _dialog_tidak() -> void:
	_id_sasaran = ""
	_lapis_dialog.visible = false

func _tutup() -> void:
	ditutup.emit()
