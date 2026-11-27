extends PanelContainer

## Menu threat gaya menu perabot (panel navy, bingkai cyan):
##   kiri   - ikon HuskLurker
##   tengah - status, Threat %, Husk kills, Est. raiders
##   kanan  - pemasa serangan balas
##
## Menu ini membina dirinya sendiri dan membaca data dari autoload
## SeranganBalas jika ada (kalau tiada, ia tetap terbuka dengan nilai 0).

const TemaPerabot := preload("res://scene/ui/TemaPerabot.gd")
const LALUAN_IKON_HUSK: String = "res://scene/Mob/HuskLurker/Image_husk.png"
const LEBAR_MENU: float = 248.0
const THREAT_SETIAP_BUNUH: int = 1  # 1 bunuhan husk = 1% threat
const SELA_UI: float = 0.1

var _label_status: Label
var _label_threat: Label
var _label_bunuh: Label
var _label_raider: Label
var _label_timer: Label
var _butang_ready: Button
var _tick: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "MenuThreat"
	visible = false
	StorThreat.muat()
	TemaPerabot.pasang(self)
	_bina()
	_kemas_kini()

func _process(delta: float) -> void:
	if not visible:
		return
	_tick += delta
	if _tick < SELA_UI:
		return
	_tick = 0.0
	_kemas_kini()

func buka() -> void:
	_kemas_kini()
	reset_size()
	var saiz_vp: Vector2 = get_viewport().get_visible_rect().size
	size = Vector2(LEBAR_MENU, maxf(get_combined_minimum_size().y, 60.0))
	position = ((saiz_vp - size) * 0.5).floor()
	visible = true
	_tick = 0.0

func tutup() -> void:
	visible = false

func tukar() -> void:
	if visible:
		tutup()
	else:
		buka()

func _bina() -> void:
	var akar := VBoxContainer.new()
	akar.add_theme_constant_override("separation", 4)
	add_child(akar)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	akar.add_child(header)

	var tajuk := Label.new()
	tajuk.text = "Husk Threat"
	tajuk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tajuk.add_theme_font_size_override("font_size", 10)
	tajuk.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55, 1.0))
	header.add_child(tajuk)

	var butang_tutup := Button.new()
	butang_tutup.text = "X"
	butang_tutup.focus_mode = Control.FOCUS_NONE
	butang_tutup.custom_minimum_size = Vector2(18, 18)
	butang_tutup.pressed.connect(tutup)
	header.add_child(butang_tutup)

	var isi := HBoxContainer.new()
	isi.add_theme_constant_override("separation", 6)
	akar.add_child(isi)

	# Kiri: ikon husk + nama.
	var kiri := VBoxContainer.new()
	kiri.custom_minimum_size = Vector2(58, 0)
	kiri.add_theme_constant_override("separation", 2)
	isi.add_child(kiri)

	var ikon := TextureRect.new()
	if ResourceLoader.exists(LALUAN_IKON_HUSK):
		ikon.texture = load(LALUAN_IKON_HUSK) as Texture2D
	ikon.custom_minimum_size = Vector2(48, 48)
	ikon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ikon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ikon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ikon.modulate = Color(1.9, 1.9, 1.9)
	kiri.add_child(ikon)

	var nama := Label.new()
	nama.text = "Husk Lurker"
	nama.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nama.add_theme_font_size_override("font_size", 6)
	nama.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0, 1.0))
	kiri.add_child(nama)

	# Tengah: info threat.
	var tengah := VBoxContainer.new()
	tengah.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tengah.add_theme_constant_override("separation", 2)
	isi.add_child(tengah)

	_label_status = _buat_label(tengah, "", 6, Color(0.72, 0.93, 1.0, 1.0))
	_label_threat = _buat_label(tengah, "Threat 0%", 9, Color(1.0, 0.55, 0.45, 1.0))
	_label_bunuh = _buat_label(tengah, "Husk kills: 0", 7, Color(0.82, 0.95, 1.0, 1.0))
	_label_raider = _buat_label(tengah, "Est. raiders: 0", 7, Color(0.82, 0.95, 1.0, 1.0))

	# Kanan: pemasa.
	var kanan := VBoxContainer.new()
	kanan.custom_minimum_size = Vector2(64, 0)
	kanan.add_theme_constant_override("separation", 2)
	isi.add_child(kanan)

	var label_pemasa := _buat_label(kanan, "Next wave", 6, Color(0.72, 0.9, 1.0, 1.0))
	label_pemasa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_timer = _buat_label(kanan, "--:--", 14, Color(1.0, 0.8, 0.45, 1.0))
	_label_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Butang Ready: hantar penyerang serta-merta tanpa tunggu pemasa 3 minit.
	_butang_ready = Button.new()
	_butang_ready.text = "Ready - send raiders"
	_butang_ready.focus_mode = Control.FOCUS_NONE
	_butang_ready.add_theme_font_size_override("font_size", 8)
	_butang_ready.pressed.connect(_tekan_ready)
	akar.add_child(_butang_ready)

	var butang_tutup_bawah := Button.new()
	butang_tutup_bawah.text = "Close"
	butang_tutup_bawah.focus_mode = Control.FOCUS_NONE
	butang_tutup_bawah.pressed.connect(tutup)
	akar.add_child(butang_tutup_bawah)

# Pemain tekan Ready: gelombang yang sedang menunggu dilancarkan sekarang.
func _tekan_ready() -> void:
	var pantau := _cari_pemantau()
	if pantau != null and pantau.has_method("lancar_sekarang"):
		var berjaya: bool = pantau.call("lancar_sekarang")
		print("MenuThreat: butang Ready ditekan, gelombang dilancarkan=", berjaya)
	_kemas_kini()

# Pemasa/spawn kini nod dalam scene level (bukan autoload).
func _cari_pemantau() -> Node:
	var autoload := get_node_or_null("/root/SeranganBalas")
	if autoload != null:
		return autoload
	var scene_utama := get_tree().current_scene
	if scene_utama == null:
		return null
	return scene_utama.find_child("SeranganBalas", true, false)

func _ada_pemantau() -> bool:
	return _cari_pemantau() != null

func _buat_label(ibu: Node, teks: String, saiz: int, warna: Color) -> Label:
	var label := Label.new()
	label.text = teks
	label.add_theme_font_size_override("font_size", saiz)
	label.add_theme_color_override("font_color", warna)
	ibu.add_child(label)
	return label

func _kemas_kini() -> void:
	# Kiraan dibaca dari stor static: husk menulis ke situ, jadi menu berubah
	# walaupun autoload SeranganBalas lambat dimuatkan.
	StorThreat.muat()
	var bunuh: int = StorThreat.bunuh
	var baki: float = StorThreat.masa_serang
	var ada_spawner: bool = _ada_pemantau()
	var peratus: int = clampi(bunuh * THREAT_SETIAP_BUNUH, 0, 100)
	var julat: Vector2i = StorThreat.julat_raider()

	if _label_threat:
		_label_threat.text = "Threat %d%%" % peratus
	if _label_bunuh:
		_label_bunuh.text = "Husk kills: %d" % bunuh
	if _label_raider:
		if julat.x == julat.y:
			_label_raider.text = "Est. raiders: %d" % julat.x
		else:
			_label_raider.text = "Est. raiders: %d-%d" % [julat.x, julat.y]
	if _label_status:
		if not ada_spawner:
			_label_status.text = "Spawner off"
			_label_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4, 1.0))
		elif baki >= 0.0:
			_label_status.text = "Wave incoming"
			_label_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45, 1.0))
		elif bunuh > 0:
			_label_status.text = "Raiders ready"
			_label_status.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45, 1.0))
		else:
			_label_status.text = "No threat"
			_label_status.add_theme_color_override("font_color", Color(0.62, 0.95, 0.7, 1.0))
	if _butang_ready:
		# Hanya boleh tekan bila ada gelombang menunggu dan spawner hidup.
		_butang_ready.disabled = not (ada_spawner and baki >= 0.0 and bunuh > 0)
	if _label_timer:
		if baki >= 0.0:
			var saat: int = maxi(0, ceili(baki))
			_label_timer.text = "%d:%02d" % [saat / 60, saat % 60]
		else:
			_label_timer.text = "--:--"
