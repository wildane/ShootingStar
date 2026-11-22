extends CanvasLayer

## Menu utama: Teruskan (slot simpanan terbaharu), Permainan Baru, dan
## halaman Muat Simpanan untuk pilih / tukar nama / padam slot.

@export var scene_sasaran: PackedScene
@export var tempoh_fade: float = 0.8

@onready var halaman_menu: Control = $UIRoot/HalamanMenu
@onready var halaman_muat: Control = $UIRoot/HalamanMuat
@onready var senarai_slot: VBoxContainer = $UIRoot/HalamanMuat/Panel/Isi/Skrol/SenaraiSlot
@onready var label_kosong: Label = $UIRoot/HalamanMuat/Panel/Isi/Kosong
@onready var butang_teruskan: Button = $UIRoot/HalamanMenu/PanelLatar/Kotak/Teruskan
@onready var label_mesej: Label = $UIRoot/Mesej

var _overlay: ColorRect
var _dialog_nama: ConfirmationDialog
var _input_nama: LineEdit
var _dialog_hapus: ConfirmationDialog
var _id_dialog: String = ""
var _sibuk: bool = false
var _tween_mesej: Tween

func _ready() -> void:
	layer = 100
	_bina_overlay()
	_bina_dialog()

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
	_dialog_nama.title = "Tukar Nama Simpanan"
	_dialog_nama.ok_button_text = "Simpan"
	_dialog_nama.cancel_button_text = "Batal"
	_input_nama = LineEdit.new()
	_input_nama.custom_minimum_size = Vector2(200, 0)
	_input_nama.max_length = 40
	_input_nama.placeholder_text = "Nama simpanan"
	_dialog_nama.add_child(_input_nama)
	_dialog_nama.confirmed.connect(_on_nama_disahkan)
	add_child(_dialog_nama)

	_dialog_hapus = ConfirmationDialog.new()
	_dialog_hapus.title = "Padam Simpanan"
	_dialog_hapus.ok_button_text = "Padam"
	_dialog_hapus.cancel_button_text = "Batal"
	_dialog_hapus.confirmed.connect(_on_hapus_disahkan)
	add_child(_dialog_hapus)

# ==========================================
# BUTANG MENU
# ==========================================
func _on_teruskan() -> void:
	var id := SaveManager.slot_terbaru()
	if id == "":
		_mesej("Tiada simpanan lagi")
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
		_mesej("Scene sasaran belum ditetapkan")
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

func _segarkan_senarai() -> void:
	for anak in senarai_slot.get_children():
		anak.queue_free()
	var senarai := SaveManager.senarai_slot()
	label_kosong.visible = senarai.is_empty()
	for slot in senarai:
		senarai_slot.add_child(_bina_baris_slot(slot))

func _bina_baris_slot(slot: Dictionary) -> Control:
	var id := str(slot["id"])
	var baris := HBoxContainer.new()
	baris.add_theme_constant_override("separation", 4)

	var butang_muat := Button.new()
	butang_muat.text = "%s\n%s" % [str(slot["nama"]), _format_tarikh(float(slot["masa"]))]
	butang_muat.add_theme_font_size_override("font_size", 9)
	butang_muat.custom_minimum_size = Vector2(0, 34)
	butang_muat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	butang_muat.pressed.connect(_pilih_slot.bind(id))
	baris.add_child(butang_muat)

	var butang_nama := Button.new()
	butang_nama.text = "Nama"
	butang_nama.add_theme_font_size_override("font_size", 9)
	butang_nama.custom_minimum_size = Vector2(38, 34)
	butang_nama.pressed.connect(_buka_dialog_nama.bind(id))
	baris.add_child(butang_nama)

	var butang_hapus := Button.new()
	butang_hapus.text = "Padam"
	butang_hapus.add_theme_font_size_override("font_size", 9)
	butang_hapus.custom_minimum_size = Vector2(44, 34)
	butang_hapus.pressed.connect(_buka_dialog_hapus.bind(id))
	baris.add_child(butang_hapus)

	return baris

func _pilih_slot(id: String) -> void:
	SaveManager.tetapkan_slot(id)
	print("[Menu] Muat slot: ", SaveManager.nama_slot(id))
	_ke_level()

func _format_tarikh(masa: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(masa))
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]

func _buka_dialog_nama(id: String) -> void:
	_id_dialog = id
	_input_nama.text = SaveManager.nama_slot(id)
	_dialog_nama.popup_centered(Vector2i(250, 110))
	_input_nama.grab_focus()
	_input_nama.select_all()

func _on_nama_disahkan() -> void:
	var nama := _input_nama.text.strip_edges()
	if nama == "":
		_mesej("Nama tidak boleh kosong")
		return
	SaveManager.tukar_nama_slot(_id_dialog, nama)
	_mesej("Nama simpanan dikemas kini")
	_segarkan_senarai()

func _buka_dialog_hapus(id: String) -> void:
	_id_dialog = id
	_dialog_hapus.dialog_text = "Padam simpanan \"%s\"?\nTindakan ini tidak boleh dibatalkan." % SaveManager.nama_slot(id)
	_dialog_hapus.popup_centered(Vector2i(250, 130))

func _on_hapus_disahkan() -> void:
	SaveManager.hapus_slot(_id_dialog)
	_mesej("Simpanan dipadam")
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
