class_name SaveMenu
extends CanvasLayer

## Panel SAVE/LOAD dalam game. Dibuka oleh level_3 dan berjalan walaupun
## SceneTree dipause (process_mode = ALWAYS).

signal ditutup

const MOD_SIMPAN := 0
const MOD_MUAT := 1
# Menu kecil dalam game: pilih SAVE, LOAD atau NEW GAME.
const MOD_MENU := 2

var mod_semasa: int = MOD_SIMPAN

const SAIZ_HALAMAN := 3

var _tajuk: Label
var _petua: Label
var _isi: VBoxContainer
var _hub: VBoxContainer
var _senarai: VBoxContainer
var _butang_sebelum: Button
var _butang_seterusnya: Button
var _label_halaman: Label
var _slot_semua: Array = []
var _halaman: int = 0
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
# Tindakan dialog yang sedang terbuka: "simpan", "timpa" atau "baru".
var _dialog_tindakan: String = "simpan"
# Senarai dibuka daripada menu dalam game, jadi butang tutup kembali ke menu.
var _dari_hub: bool = false

func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bina_ui()
	if mod_semasa == MOD_MENU:
		_tunjuk_hub()
	else:
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
	# Rangka biru panel berada ~42 px dari tepi panel; kandungan diinset lebih
	# supaya tulisan tidak terkeluar dari kotak biru itu.
	isi.offset_left = 48.0
	isi.offset_top = 48.0
	isi.offset_right = -48.0
	isi.offset_bottom = -48.0
	isi.add_theme_constant_override("separation", 8)
	isi.theme = _bina_tema()
	panel.add_child(isi)
	_isi = isi

	_tajuk = Label.new()
	_tajuk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tajuk.add_theme_font_size_override("font_size", 13)
	isi.add_child(_tajuk)

	_petua = Label.new()
	_petua.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_petua.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_petua.add_theme_font_size_override("font_size", 8)
	isi.add_child(_petua)

	_senarai = VBoxContainer.new()
	_senarai.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_senarai.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_senarai.add_theme_constant_override("separation", 4)
	isi.add_child(_senarai)

	# Navigasi halaman menggantikan bar scroll (skrol sentuh tidak berfungsi).
	var baris_halaman := HBoxContainer.new()
	baris_halaman.add_theme_constant_override("separation", 6)
	isi.add_child(baris_halaman)

	_butang_sebelum = Button.new()
	_butang_sebelum.text = "<"
	_butang_sebelum.custom_minimum_size = Vector2(34, 24)
	_butang_sebelum.add_theme_font_size_override("font_size", 10)
	_butang_sebelum.pressed.connect(_halaman_sebelum)
	baris_halaman.add_child(_butang_sebelum)

	_label_halaman = Label.new()
	_label_halaman.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_halaman.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_halaman.add_theme_font_size_override("font_size", 8)
	baris_halaman.add_child(_label_halaman)

	_butang_seterusnya = Button.new()
	_butang_seterusnya.text = ">"
	_butang_seterusnya.custom_minimum_size = Vector2(34, 24)
	_butang_seterusnya.add_theme_font_size_override("font_size", 10)
	_butang_seterusnya.pressed.connect(_halaman_seterusnya)
	baris_halaman.add_child(_butang_seterusnya)

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
	_bina_hub(panel)

# Menu kecil dalam game: SAVE, LOAD, NEW GAME dan Resume.
func _bina_hub(panel: Control) -> void:
	_hub = VBoxContainer.new()
	_hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hub.offset_left = 48.0
	_hub.offset_top = 48.0
	_hub.offset_right = -48.0
	_hub.offset_bottom = -48.0
	_hub.add_theme_constant_override("separation", 10)
	_hub.alignment = BoxContainer.ALIGNMENT_CENTER
	_hub.theme = _bina_tema()
	_hub.visible = false
	panel.add_child(_hub)

	var tajuk := Label.new()
	tajuk.text = "MENU"
	tajuk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tajuk.add_theme_font_size_override("font_size", 13)
	_hub.add_child(tajuk)

	_hub.add_child(_butang_hub("Save Game", _on_hub_simpan))
	_hub.add_child(_butang_hub("Load Game", _on_hub_muat))
	_hub.add_child(_butang_hub("New Game", _tanya_baru))
	_hub.add_child(_butang_hub("Resume", _tutup))

func _butang_hub(teks: String, sasaran: Callable) -> Button:
	var butang := Button.new()
	butang.text = teks
	butang.custom_minimum_size = Vector2(0, 32)
	butang.add_theme_font_size_override("font_size", 10)
	butang.pressed.connect(sasaran)
	return butang

func _tunjuk_hub() -> void:
	mod_semasa = MOD_MENU
	_dari_hub = false
	_lapis_dialog.visible = false
	_isi.visible = false
	_hub.visible = true

func _buka_senarai(mod: int) -> void:
	mod_semasa = mod
	_dari_hub = true
	_hub.visible = false
	_isi.visible = true
	segarkan_senarai()

func _on_hub_simpan() -> void:
	_buka_senarai(MOD_SIMPAN)

func _on_hub_muat() -> void:
	_buka_senarai(MOD_MUAT)

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
	kotak.offset_left = -125.0
	kotak.offset_top = -105.0
	kotak.offset_right = 125.0
	kotak.offset_bottom = 105.0
	_lapis_dialog.add_child(kotak)

	var isi := VBoxContainer.new()
	isi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	isi.offset_left = 48.0
	isi.offset_top = 48.0
	isi.offset_right = -48.0
	isi.offset_bottom = -48.0
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
	_butang_tutup.text = "Back" if _dari_hub else ("Resume" if mod_simpan else "Cancel")
	_status.text = ""

	_slot_semua = []
	for slot in SaveManager.senarai_slot():
		var id := str(slot["id"])
		# Slot autosave tidak boleh ditimpa secara manual.
		if mod_simpan and SaveManager.SLOT_AUTOSAVE.has(id):
			continue
		_slot_semua.append(slot)
	_halaman = 0
	_tunjuk_halaman()

func _tunjuk_halaman() -> void:
	for anak in _senarai.get_children():
		_senarai.remove_child(anak)
		anak.queue_free()

	var jumlah: int = _slot_semua.size()
	var maks: int = maxi(1, int(ceil(float(jumlah) / SAIZ_HALAMAN)))
	_halaman = clampi(_halaman, 0, maks - 1)
	var mula: int = _halaman * SAIZ_HALAMAN
	var akhir: int = mini(mula + SAIZ_HALAMAN, jumlah)
	for i in range(mula, akhir):
		_senarai.add_child(_bina_baris(_slot_semua[i]))

	if jumlah == 0:
		var kosong := Label.new()
		kosong.text = "No saves yet. Use New Save." if mod_semasa == MOD_SIMPAN else "No saves yet."
		kosong.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kosong.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_senarai.add_child(kosong)

	_butang_sebelum.disabled = _halaman <= 0
	_butang_seterusnya.disabled = _halaman >= maks - 1
	_label_halaman.text = "Page %d / %d" % [_halaman + 1, maks]

func _halaman_sebelum() -> void:
	_halaman -= 1
	_tunjuk_halaman()

func _halaman_seterusnya() -> void:
	_halaman += 1
	_tunjuk_halaman()

func _bina_baris(slot: Dictionary) -> Control:
	var butang := Button.new()
	butang.text = "%s\n%s" % [str(slot["nama"]), _format_tarikh(float(slot["masa"]))]
	butang.add_theme_font_size_override("font_size", 9)
	butang.custom_minimum_size = Vector2(0, 32)
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
	_dialog_tindakan = "simpan"
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
	_dialog_tindakan = "timpa"
	_id_sasaran = id
	_dialog_tajuk.text = "OVERWRITE SAVE"
	_dialog_mesej.text = "Overwrite \"%s\"?\nCurrent progress in that slot will be replaced." % SaveManager.nama_slot(id)
	_butang_ya.text = "Overwrite"
	_input_nama.visible = false
	_lapis_dialog.visible = true

func _tanya_baru() -> void:
	_dialog_tindakan = "baru"
	_id_sasaran = ""
	_dialog_tajuk.text = "NEW GAME"
	_dialog_mesej.text = "Start a new game?\nUnsaved progress in this session will be lost."
	_butang_ya.text = "New Game"
	_input_nama.visible = false
	_lapis_dialog.visible = true

func _on_nama_dihantar(_teks: String) -> void:
	if _lapis_dialog.visible and _input_nama.visible:
		_dialog_ya()

func _dialog_ya() -> void:
	var tindakan := _dialog_tindakan
	var id_sasaran := _id_sasaran
	var nama := _input_nama.text
	_id_sasaran = ""
	_lapis_dialog.visible = false

	if tindakan == "baru":
		SaveManager.mula_permainan_baru()
		get_tree().paused = false
		ditutup.emit()
		get_tree().change_scene_to_file("res://scene/level_3/level_3.tscn")
		return

	var id := id_sasaran
	if tindakan == "simpan":
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
	if _dari_hub:
		_tunjuk_hub()
		return
	ditutup.emit()
