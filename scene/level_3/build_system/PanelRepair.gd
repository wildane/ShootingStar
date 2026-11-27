extends VBoxContainer

## Baris baiki perabot di bahagian atas menu perabot: tajuk "Repair", senarai
## bahan yang diperlukan (ikon + ada/perlu) dan butang Repair.
##
## Panel ini hanya kelihatan bila perabot rosak. Kos dikira oleh
## RepairStruktur ikut nisbah HP yang hilang, jadi ia berubah bila perabot
## diserang lagi.

const RepairRef := preload("res://scene/level_3/build_system/RepairStruktur.gd")

const WARNA_CUKUP: Color = Color(0.5, 0.95, 0.62, 1.0)
const WARNA_KURANG: Color = Color(1.0, 0.44, 0.44, 1.0)
const WARNA_TAJUK: Color = Color(1.0, 0.85, 0.4, 1.0)

## Dipancar selepas baiki berjaya supaya menu perabot boleh dikemas kini.
signal selesai_baiki

var perabot: Node = null

var _baris: HBoxContainer = null
var _tajuk: Label = null
var _butang: Button = null
var _slot: Array[Dictionary] = []
var _tandatangan: String = ""


func _ready() -> void:
	_sedia_nod()


func sediakan(nod: Node) -> void:
	perabot = nod
	if _baris == null:
		_sedia_nod()
	segarkan()


func _sedia_nod() -> void:
	if _baris != null:
		return
	name = "PanelRepair"
	add_theme_constant_override("separation", 1)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_baris = HBoxContainer.new()
	_baris.name = "BarisBahan"
	_baris.alignment = BoxContainer.ALIGNMENT_CENTER
	_baris.add_theme_constant_override("separation", 4)
	add_child(_baris)

	_tajuk = Label.new()
	_tajuk.text = "Repair"
	_tajuk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tajuk.add_theme_font_size_override("font_size", 7)
	_tajuk.add_theme_color_override("font_color", WARNA_TAJUK)
	_baris.add_child(_tajuk)

	_butang = Button.new()
	_butang.name = "ButangRepair"
	_butang.text = "Repair"
	_butang.custom_minimum_size = Vector2(0, 16)
	_butang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_butang.add_theme_font_size_override("font_size", 8)
	_butang.pressed.connect(_on_butang_pressed)
	add_child(_butang)


# Segarkan paparan ikut HP dan isi beg semasa. Sembunyi bila perabot penuh.
func segarkan() -> void:
	if perabot == null or not is_instance_valid(perabot):
		visible = false
		return
	if not RepairRef.rosak(perabot):
		visible = false
		return
	visible = true
	var kos: Array = RepairRef.kos_repair(perabot)
	_bina_slot(kos)

	var cukup: bool = true
	for i in kos.size():
		if i >= _slot.size():
			break
		var data: Dictionary = kos[i]
		var perlu: int = int(data.get("diperlukan", 0))
		var ada: int = RepairRef.bilangan_dalam_beg(perabot, str(data.get("id", "")))
		var label: Label = _slot[i]["label"]
		label.text = "%d/%d" % [ada, perlu]
		label.add_theme_color_override("font_color", WARNA_CUKUP if ada >= perlu else WARNA_KURANG)
		if ada < perlu:
			cukup = false

	if _butang != null:
		_butang.disabled = not cukup
		_butang.modulate = Color(1, 1, 1, 1) if cukup else Color(0.55, 0.55, 0.55, 1)


# Bina ikon + label bahan hanya bila senarai keperluan berubah.
func _bina_slot(kos: Array) -> void:
	var cap: String = ""
	for data in kos:
		cap += "%s:%d|" % [str(data.get("id", "")), int(data.get("diperlukan", 0))]
	if cap == _tandatangan:
		return
	_tandatangan = cap

	for s in _slot:
		var ikon_lama: Node = s["ikon"]
		var label_lama: Node = s["label"]
		if is_instance_valid(ikon_lama):
			ikon_lama.queue_free()
		if is_instance_valid(label_lama):
			label_lama.queue_free()
	_slot.clear()

	for data in kos:
		var ikon := TextureRect.new()
		ikon.custom_minimum_size = Vector2(12, 12)
		ikon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ikon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tekstur: Variant = data.get("ikon")
		if tekstur is Texture2D:
			ikon.texture = tekstur
		_baris.add_child(ikon)

		var label := Label.new()
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 7)
		_baris.add_child(label)

		_slot.append({"ikon": ikon, "label": label})


func _on_butang_pressed() -> void:
	if perabot == null or not is_instance_valid(perabot):
		return
	if not RepairRef.baiki(perabot):
		return
	segarkan()
	selesai_baiki.emit()
