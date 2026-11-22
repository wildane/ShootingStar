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
var _dialog_nama: ConfirmationDialog
var _input_nama: LineEdit
var _dialog_hapus: ConfirmationDialog
var _dialog_pilihan: AcceptDialog
var _label_pilihan: Label
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

func _bina_dialog() -> void:
	_dialog_nama = ConfirmationDialog.new()
	_dialog_nama.title = "Rename Save"
	_dialog_nama.ok_button_text = "Save"
	_dialog_nama.cancel_button_text = "Cancel"
	_input_nama = LineEdit.new()
	_input_nama.custom_minimum_size = Vector2(200, 0)
	_input_nama.max_length = 40
	_input_nama.placeholder_text = "Save name"
	_dialog_nama.add_child(_input_nama)
	_dialog_nama.confirmed.connect(_on_nama_disahkan)
	add_child(_dialog_nama)

	_dialog_hapus = ConfirmationDialog.new()
	_dialog_hapus.title = "Delete Save"
	_dialog_hapus.ok_button_text = "Delete"
	_dialog_hapus.cancel_button_text = "Cancel"
	_dialog_hapus.confirmed.connect(_on_hapus_disahkan)
	add_child(_dialog_hapus)

	# Pilihan untuk satu slot: Rename atau Delete.
	_dialog_pilihan = AcceptDialog.new()
	_dialog_pilihan.title = "Save Options"
	_dialog_pilihan.ok_button_text = "Close"
	_label_pilihan = Label.new()
	_label_pilihan.custom_minimum_size = Vector2(200, 0)
	_label_pilihan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_pilihan.add_child(_label_pilihan)
	_dialog_pilihan.add_button("Rename", true, "rename")
	_dialog_pilihan.add_button("Delete", true, "delete")
	_dialog_pilihan.custom_action.connect(_on_pilihan_slot)
	add_child(_dialog_pilihan)

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
	_label_pilihan.text = "Save \"%s\"" % SaveManager.nama_slot(id)
	_dialog_pilihan.popup_centered(Vector2i(250, 120))

func _on_pilihan_slot(tindakan: StringName) -> void:
	_dialog_pilihan.hide()
	match tindakan:
		"rename":
			_buka_dialog_nama(_id_dialog)
		"delete":
			_buka_dialog_hapus(_id_dialog)

func _pilih_slot(id: String) -> void:
	SaveManager.tetapkan_slot(id)
	print("[Menu] Muat slot: ", SaveManager.nama_slot(id))
	_ke_level()

func _format_tarikh(masa: float) -> String:
	return SaveManager.format_masa(masa)

func _buka_dialog_nama(id: String) -> void:
	_id_dialog = id
	_input_nama.text = SaveManager.nama_slot(id)
	_dialog_nama.popup_centered(Vector2i(250, 110))
	_input_nama.grab_focus()
	_input_nama.select_all()

func _on_nama_disahkan() -> void:
	var nama := _input_nama.text.strip_edges()
	if nama == "":
		_mesej("Name cannot be empty")
		return
	SaveManager.tukar_nama_slot(_id_dialog, nama)
	_mesej("Save renamed")
	_segarkan_senarai()

func _buka_dialog_hapus(id: String) -> void:
	_id_dialog = id
	_dialog_hapus.dialog_text = "Delete save \"%s\"?\nThis cannot be undone." % SaveManager.nama_slot(id)
	_dialog_hapus.popup_centered(Vector2i(250, 130))

func _on_hapus_disahkan() -> void:
	SaveManager.hapus_slot(_id_dialog)
	_mesej("Save deleted")
	_segarkan_senarai()
	butang_teruskan.disabled = not SaveManager.ada_simpanan()

func _mesej(teks: String) -> void:
	label_mesej.text = teks
	if _tween_mesej != null and _tween_mesej.is_valid():
		_tween_mesej.kill()
	label_mesej.modulate.a = 1.0
	_tween_mesej = create_tween()
	_tween_mesej.tween_interval(1.5)
	_tween_mesej.tween_property(label_mesej, "modulate:a", 0.0, 0.5)
