extends CanvasLayer

## Menu utama: Teruskan (slot simpanan terbaharu), Permainan Baru, dan
## halaman Muat Simpanan untuk pilih / tukar nama / padam slot.

@export var scene_sasaran: PackedScene
@export var tempoh_fade: float = 0.8

@onready var halaman_menu: Control = $UIRoot/HalamanMenu
@onready var halaman_muat: Control = $UIRoot/HalamanMuat
@onready var senarai_slot: VBoxContainer = $UIRoot/HalamanMuat/Panel/Isi/SenaraiSlot
@onready var pager: HBoxContainer = $UIRoot/HalamanMuat/Panel/Isi/Pager
@onready var label_kosong: Label = $UIRoot/HalamanMuat/Panel/Isi/Kosong
@onready var butang_teruskan: Button = $UIRoot/HalamanMenu/PanelLatar/Kotak/Teruskan
@onready var label_mesej: Label = $UIRoot/Mesej

var _overlay: ColorRect
# Dialog gaya neon panel (pilihan slot, tukar nama, padam).
var _lapis_dialog: Control
var _dialog_tajuk: Label
var _dialog_mesej: Label
var _input_nama: LineEdit
var _butang_a: Button
var _butang_b: Button
var _butang_tutup: Button
var _dialog_modo: String = ""
var _id_dialog: String = ""
var _sibuk: bool = false
var _tween_mesej: Tween

# Navigasi halaman untuk senarai simpanan (bar scroll tidak boleh diskrol
# dengan jari pada skrin sentuh).
const SAIZ_HALAMAN := 4
var _butang_sebelum: Button
var _butang_seterusnya: Button
var _label_halaman: Label
var _slot_semua: Array = []
var _halaman: int = 0

func _ready() -> void:
	layer = 100
	_bina_overlay()
	_bina_dialog()
	_bina_pager()

	$UIRoot/HalamanMenu/PanelLatar/Kotak/Teruskan.pressed.connect(_on_teruskan)
	$UIRoot/HalamanMenu/PanelLatar/Kotak/PermainanBaru.pressed.connect(_on_permainan_baru)
	$UIRoot/HalamanMenu/PanelLatar/Kotak/Muat.pressed.connect(_tunjuk_halaman_muat)
	$UIRoot/HalamanMuat/Panel/Isi/Kembali.pressed.connect(_tunjuk_halaman_menu)

	_tunjuk_halaman_menu()
	label_mesej.modulate.a = 0.0
	$UIRoot.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property($UIRoot, "modulate:a", 1.0, 0.35)

func _bina_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

# Dialog dibina sendiri (bukan AcceptDialog) supaya rupanya sama dengan panel
# neon dalam game: bingkai biru, butang biru dan tiada bar tetingkap kelabu.
func _bina_dialog() -> void:
	_lapis_dialog = Control.new()
	_lapis_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lapis_dialog.visible = false
	$UIRoot.add_child(_lapis_dialog)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
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
	isi.theme = _tema_dialog()
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
	_input_nama.max_length = 40
	_input_nama.custom_minimum_size = Vector2(0, 26)
	_input_nama.add_theme_font_size_override("font_size", 10)
	_input_nama.text_submitted.connect(_on_nama_dihantar)
	isi.add_child(_input_nama)

	var baris := HBoxContainer.new()
	baris.add_theme_constant_override("separation", 6)
	isi.add_child(baris)

	_butang_a = Button.new()
	_butang_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_butang_a.add_theme_font_size_override("font_size", 9)
	_butang_a.pressed.connect(_on_dialog_a)
	baris.add_child(_butang_a)

	_butang_b = Button.new()
	_butang_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_butang_b.add_theme_font_size_override("font_size", 9)
	_butang_b.pressed.connect(_on_dialog_b)
	baris.add_child(_butang_b)

	_butang_tutup = Button.new()
	_butang_tutup.text = "Close"
	_butang_tutup.custom_minimum_size = Vector2(0, 26)
	_butang_tutup.add_theme_font_size_override("font_size", 9)
	_butang_tutup.pressed.connect(_tutup_dialog)
	isi.add_child(_butang_tutup)

func _tema_dialog() -> Theme:
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
	tema.set_font_size("font_size", "Button", 9)
	tema.set_color("font_color", "Button", Color(0.85, 0.97, 1, 1))
	tema.set_color("font_hover_color", "Button", Color(1, 1, 1, 1))
	tema.set_color("font_pressed_color", "Button", Color(0.05, 0.12, 0.16, 1))
	tema.set_color("font_disabled_color", "Button", Color(0.46, 0.56, 0.63, 1))
	tema.set_color("font_color", "Label", Color(0.82, 0.95, 1, 1))
	tema.set_font_size("font_size", "Label", 9)

	var kotak := normal.duplicate() as StyleBoxFlat
	kotak.bg_color = Color(0.03, 0.09, 0.14, 0.95)
	tema.set_stylebox("normal", "LineEdit", kotak)
	tema.set_stylebox("focus", "LineEdit", hover)
	tema.set_color("font_color", "LineEdit", Color(0.85, 0.97, 1, 1))
	tema.set_color("caret_color", "LineEdit", Color(0.5, 0.97, 1, 1))
	tema.set_font_size("font_size", "LineEdit", 10)
	return tema

# Buka dialog dalam salah satu mod: "pilihan", "nama" atau "hapus".
func _buka_dialog(modo: String) -> void:
	_dialog_modo = modo
	_input_nama.visible = false
	_butang_tutup.visible = modo == "pilihan"
	_susun_modo(modo)
	_lapis_dialog.visible = true
	if _input_nama.visible:
		_input_nama.grab_focus()
		_input_nama.select_all()

func _susun_modo(modo: String) -> void:
	match modo:
		"pilihan":
			_dialog_tajuk.text = "SAVE OPTIONS"
			_dialog_mesej.text = "Save \"%s\"" % SaveManager.nama_slot(_id_dialog)
			_butang_a.text = "Rename"
			_butang_b.text = "Delete"
		"nama":
			_dialog_tajuk.text = "RENAME SAVE"
			_dialog_mesej.text = "Enter a new name:"
			_butang_a.text = "Save"
			_butang_b.text = "Cancel"
			_input_nama.text = SaveManager.nama_slot(_id_dialog)
			_input_nama.visible = true
		"hapus":
			_dialog_tajuk.text = "DELETE SAVE"
			_dialog_mesej.text = "Delete \"%s\"?\nThis cannot be undone." % SaveManager.nama_slot(_id_dialog)
			_butang_a.text = "Delete"
			_butang_b.text = "Cancel"

func _on_dialog_a() -> void:
	match _dialog_modo:
		"pilihan":
			_buka_dialog("nama")
		"nama":
			_on_nama_disahkan()
		"hapus":
			_on_hapus_disahkan()

func _on_dialog_b() -> void:
	if _dialog_modo == "pilihan":
		_buka_dialog("hapus")
	else:
		_tutup_dialog()

func _on_nama_dihantar(_teks: String) -> void:
	if _lapis_dialog.visible and _dialog_modo == "nama":
		_on_nama_disahkan()

func _tutup_dialog() -> void:
	_dialog_modo = ""
	_lapis_dialog.visible = false

# ==========================================
# BUTANG MENU
# ==========================================
func _on_teruskan() -> void:
	var id := SaveManager.slot_terbaru()
	if id == "":
		_mesej("No saves yet")
		return
	SaveManager.tetapkan_slot(id)
	print("[Menu] Teruskan simpanan: ", SaveManager.nama_slot(id))
	_ke_level()

func _on_permainan_baru() -> void:
	SaveManager.mula_permainan_baru()
	print("[Menu] Permainan baru dimulakan")
	_ke_level()

func _ke_level() -> void:
	if _sibuk:
		return
	if scene_sasaran == null:
		_mesej("Target scene is not set")
		return
	_sibuk = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, tempoh_fade)
	await tween.finished
	# Pasang perisai hitam milik autoload supaya skrin kekal hitam sehingga
	# level baharu siap dimuatkan (bukan kelabu).
	SceneTransition.pasang_perisai()
	get_tree().change_scene_to_packed(scene_sasaran)

# ==========================================
# HALAMAN MUAT SIMPANAN
# ==========================================
func _tunjuk_halaman_muat() -> void:
	halaman_menu.visible = false
	halaman_muat.visible = true
	_segarkan_senarai()

func _tunjuk_halaman_menu() -> void:
	halaman_muat.visible = false
	halaman_menu.visible = true
	butang_teruskan.disabled = not SaveManager.ada_simpanan()

func _bina_pager() -> void:
	_butang_sebelum = Button.new()
	_butang_sebelum.text = "<"
	_butang_sebelum.custom_minimum_size = Vector2(34, 24)
	_butang_sebelum.add_theme_font_size_override("font_size", 10)
	_butang_sebelum.pressed.connect(_halaman_sebelum)
	pager.add_child(_butang_sebelum)

	_label_halaman = Label.new()
	_label_halaman.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_halaman.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_halaman.add_theme_font_size_override("font_size", 9)
	pager.add_child(_label_halaman)

	_butang_seterusnya = Button.new()
	_butang_seterusnya.text = ">"
	_butang_seterusnya.custom_minimum_size = Vector2(34, 24)
	_butang_seterusnya.add_theme_font_size_override("font_size", 10)
	_butang_seterusnya.pressed.connect(_halaman_seterusnya)
	pager.add_child(_butang_seterusnya)

func _halaman_sebelum() -> void:
	_halaman -= 1
	_tunjuk_halaman()

func _halaman_seterusnya() -> void:
	_halaman += 1
	_tunjuk_halaman()

func _segarkan_senarai() -> void:
	_slot_semua = SaveManager.senarai_slot()
	_halaman = 0
	label_kosong.visible = _slot_semua.is_empty()
	_tunjuk_halaman()

func _tunjuk_halaman() -> void:
	for anak in senarai_slot.get_children():
		senarai_slot.remove_child(anak)
		anak.queue_free()

	var jumlah: int = _slot_semua.size()
	var maks: int = maxi(1, int(ceil(float(jumlah) / SAIZ_HALAMAN)))
	_halaman = clampi(_halaman, 0, maks - 1)
	var mula: int = _halaman * SAIZ_HALAMAN
	var akhir: int = mini(mula + SAIZ_HALAMAN, jumlah)
	for i in range(mula, akhir):
		senarai_slot.add_child(_bina_baris_slot(_slot_semua[i]))

	_butang_sebelum.disabled = _halaman <= 0
	_butang_seterusnya.disabled = _halaman >= maks - 1
	_label_halaman.text = "Page %d / %d" % [_halaman + 1, maks]

func _bina_baris_slot(slot: Dictionary) -> Control:
	var id := str(slot["id"])
	var baris := HBoxContainer.new()
	baris.add_theme_constant_override("separation", 4)

	var butang_muat := Button.new()
	butang_muat.text = "%s\n%s" % [str(slot["nama"]), _format_tarikh(float(slot["masa"]))]
	butang_muat.add_theme_font_size_override("font_size", 9)
	butang_muat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	butang_muat.custom_minimum_size = Vector2(0, 34)
	butang_muat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	butang_muat.pressed.connect(_pilih_slot.bind(id))
	baris.add_child(butang_muat)

	# Rename dan Delete dimasukkan ke dalam dialog supaya baris kekal dalam
	# kotak biru panel (lebar panel hanya 154 px selepas inset).
	var butang_pilihan := Button.new()
	butang_pilihan.text = "..."
	butang_pilihan.add_theme_font_size_override("font_size", 9)
	butang_pilihan.custom_minimum_size = Vector2(34, 34)
	butang_pilihan.pressed.connect(_buka_dialog_pilihan.bind(id))
	baris.add_child(butang_pilihan)

	return baris

func _buka_dialog_pilihan(id: String) -> void:
	_id_dialog = id
	_buka_dialog("pilihan")

func _pilih_slot(id: String) -> void:
	SaveManager.tetapkan_slot(id)
	print("[Menu] Muat slot: ", SaveManager.nama_slot(id))
	_ke_level()

func _format_tarikh(masa: float) -> String:
	return SaveManager.format_masa(masa)

func _on_nama_disahkan() -> void:
	var nama := _input_nama.text.strip_edges()
	if nama == "":
		_mesej("Name cannot be empty")
		return
	SaveManager.tukar_nama_slot(_id_dialog, nama)
	_mesej("Save renamed")
	_segarkan_senarai()
	_tutup_dialog()

func _on_hapus_disahkan() -> void:
	SaveManager.hapus_slot(_id_dialog)
	_mesej("Save deleted")
	_segarkan_senarai()
	butang_teruskan.disabled = not SaveManager.ada_simpanan()
	_tutup_dialog()

func _mesej(teks: String) -> void:
	label_mesej.text = teks
	if _tween_mesej != null and _tween_mesej.is_valid():
		_tween_mesej.kill()
	label_mesej.modulate.a = 1.0
	_tween_mesej = create_tween()
	_tween_mesej.tween_interval(1.5)
	_tween_mesej.tween_property(label_mesej, "modulate:a", 0.0, 0.5)
