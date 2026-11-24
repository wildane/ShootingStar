extends CanvasLayer

## Overlay diagnostik kuasa (Idea 7). Aktif hanya apabila ditogol (F8 pada debug build).
## Kos sifar apabila tersembunyi.

const PowerGridRef := preload("res://scene/level_3/build_system/PowerInverter/PowerGrid.gd")

var _label: Label
var _masa_kemas_kini: float = 0.0
const SELA_KEMAS_KINI: float = 0.25

func _ready() -> void:
	layer = 120
	name = "PowerDebugOverlay"
	_label = Label.new()
	_label.position = Vector2(10, 120)
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = false
	PowerGridRef.debug_aktif = false

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F8:
		visible = not visible
		PowerGridRef.debug_aktif = visible
		if visible:
			_kemas_kini_teks()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	_masa_kemas_kini += delta
	if _masa_kemas_kini < SELA_KEMAS_KINI:
		return
	_masa_kemas_kini = 0.0
	_kemas_kini_teks()

func _kemas_kini_teks() -> void:
	var s: Dictionary = PowerGridRef.get_stats()
	var teks := "[PowerGrid F8]\n"
	teks += "inv:%d solar:%d perabot:%d\n" % [int(s.get("inverter_berdaftar", 0)), int(s.get("solar_berdaftar", 0)), int(s.get("perabot_berdaftar", 0))]
	teks += "kira:%d (penuh:%d inc:%d)\n" % [int(s.get("kiraan", 0)), int(s.get("kiraan_penuh", 0)), int(s.get("kiraan_incremental", 0))]
	teks += "ms:%.2f nod:%d inv:%d\n" % [float(s.get("masa_terakhir_ms", 0.0)), int(s.get("nod_diproses", 0)), int(s.get("inverter_diproses", 0))]
	teks += "dirty:semua=%d inv=%d kotor=%s/%d\n" % [int(s.get("dirty_semua", 0)), int(s.get("dirty_inverter", 0)), str(s.get("kotor_semua", false)), int(s.get("inverter_kotor", 0))]
	teks += "sebab:%s\n" % str(s.get("sebab_terakhir", ""))
	var amaran := str(s.get("amaran", ""))
	if amaran != "":
		teks += "AMARAN: %s\n" % amaran
	_label.text = teks
