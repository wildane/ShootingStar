extends Node

## Butang "threat" (logo mata merah) dalam group ikon menegak kiri (Build,
## Weapon, Home ...). Bila ditekan, menu gaya perabot terbuka: ikon husk di
## kiri, info threat di tengah (peratus, bilangan husk dibunuh, anggaran
## penyerang) dan pemasa serangan balas di kanan.

const TemaPerabot := preload("res://scene/ui/TemaPerabot.gd")
# Ikon dimuat ketika runtime (bukan preload) supaya skrip ini tidak gagal
# dikompil jika PNG belum diimport pada peranti lain.
const LALUAN_IKON_THREAT: String = "res://scene/ui/threat_icon.png"
const LALUAN_IKON_HUSK: String = "res://scene/Mob/HuskLurker/Image_husk.png"
const LALUAN_BEKAS: String = "CanvasLayer/MarginContainer/VBoxContainer"
# Nama butang HUD lain dalam group ikon, untuk mengesan VBox yang betul.
const TANDA_BEKAS: Array[String] = ["WeaponAttachment", "InventoryButton", "BuildSystem"]
const SAIZ_BUTANG: float = 32.0
const LEBAR_MENU: float = 248.0
# Setiap husk yang dibunuh menaikkan threat sebanyak ini (10 husk = 100%).
const THREAT_SETIAP_BUNUH: int = 10
const SELA_CARI_BEKAS: float = 0.25
const SELA_UI: float = 0.1

var serangan: Node = null

var _kanvas: CanvasLayer
var _butang: Button
var _menu: PanelContainer
var _label_status: Label
var _label_threat: Label
var _label_bunuh: Label
var _label_raider: Label
var _label_timer: Label
var _tick: float = 0.0
var _cari_tick: float = 0.0
var _ikon_threat: Texture2D = null
var _ikon_husk: Texture2D = null

func pasang(sumber: Node) -> void:
	serangan = sumber
	# Sentiasa berjalan supaya butang tetap dicari walaupun pokok scene dipause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ikon_threat = _muat_ikon(LALUAN_IKON_THREAT)
	_ikon_husk = _muat_ikon(LALUAN_IKON_HUSK)

	if _kanvas == null or not is_instance_valid(_kanvas):
		_kanvas = CanvasLayer.new()
		_kanvas.name = "HudThreat"
		_kanvas.layer = 95
		add_child(_kanvas)
	_sedia_butang()
	_sedia_menu()

func _muat_ikon(laluan: String) -> Texture2D:
	if not ResourceLoader.exists(laluan):
		return null
	return load(laluan) as Texture2D

func _process(delta: float) -> void:
	# Butang hilang bila tukar scene; cari bekasnya semula sekali-sekala.
	_cari_tick += delta
	if _cari_tick >= SELA_CARI_BEKAS:
		_cari_tick = 0.0
		if _butang == null or not is_instance_valid(_butang) or not _butang.is_inside_tree():
			_sedia_butang()
		else:
			# BuildGrid menambah ikon rumah kemudian; pastikan butang threat
			# kekal di bawah sekali dalam group ikon.
			_susun_bawah_ikon_home()

	if _menu == null or not is_instance_valid(_menu) or not _menu.visible:
		return
	_tick += delta
	if _tick < SELA_UI:
		return
	_tick = 0.0
	_kemas_kini_label()

# Dipanggil SeranganBalas bila kiraan berubah: segarkan menu serta-merta.
func kemas_kini(_delta: float = 0.0) -> void:
	_sedia_butang()
	if _menu != null and is_instance_valid(_menu) and _menu.visible:
		_kemas_kini_label()
		_tick = 0.0

# ==========================================================
# BUTANG DALAM GROUP IKON KIRI
# ==========================================================
func _sedia_butang() -> void:
	if _butang != null and is_instance_valid(_butang) and _butang.is_inside_tree():
		return

	# Butang dalam scene (ButangThreat.gd) diutamakan; ia ada dalam level_3.tscn
	# supaya sentiasa kelihatan macam butang HUD lain.
	var sedia := _cari_butang_sedia()
	if sedia != null:
		# Butang scene sudah sambung isyaratnya sendiri (ButangThreat.gd) ke
		# buka_menu_threat, jadi jangan sambung di sini (elak toggle berganda).
		_butang = sedia
		return

	var bekas := _cari_bekas_ikon()
	if bekas == null:
		return

	_butang = Button.new()
	_butang.name = "ButangThreat"
	_butang.text = ""
	_butang.tooltip_text = "Husk Threat"
	_butang.focus_mode = Control.FOCUS_NONE
	_butang.custom_minimum_size = Vector2(SAIZ_BUTANG, SAIZ_BUTANG)
	_butang.size = Vector2(SAIZ_BUTANG, SAIZ_BUTANG)
	_butang.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_butang.theme = _tema_butang()
	if _ikon_threat != null:
		_butang.icon = _ikon_threat
		_butang.expand_icon = true
		_butang.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		# Ikon tidak dapat dimuat (PNG belum diimport): still nampak sebagai "!".
		_butang.text = "!"
		_butang.add_theme_font_size_override("font_size", 16)
		_butang.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3, 1.0))
	_butang.pressed.connect(_tukar_menu)

	# Anak terakhir VBox = di bawah ikon rumah.
	bekas.add_child(_butang)
	print("ThreatHud: butang threat ditambah ke ", bekas.get_path())

func _cari_butang_sedia() -> Button:
	var scene_utama := get_tree().current_scene
	if scene_utama == null:
		return null
	return scene_utama.find_child("ButangThreat", true, false) as Button

# Letak butang threat sebagai anak terakhir group ikon (bawah ikon rumah).
func _susun_bawah_ikon_home() -> void:
	if _butang == null or not is_instance_valid(_butang):
		return
	var ibu := _butang.get_parent()
	if ibu == null:
		return
	if _butang.get_index() != ibu.get_child_count() - 1:
		ibu.move_child(_butang, -1)

# Cari VBox ikon menegah kiri: utamakan laluan tepat, kemudian VBox yang
# mengandungi butang HUD yang dikenali.
func _cari_bekas_ikon() -> Control:
	var scene_utama := get_tree().current_scene
	if scene_utama == null:
		return null

	var lurus := scene_utama.get_node_or_null(LALUAN_BEKAS) as Control
	if lurus != null:
		return lurus

	for nod in scene_utama.find_children("*", "VBoxContainer", true, false):  # owned=false: termasuk nod runtime
		for nama in TANDA_BEKAS:
			if nod.get_node_or_null(nama) != null:
				return nod as Control

	# Sandaran terakhir: CanvasLayer dengan butang HUD, cari VBox di dalamnya.
	for lapis in scene_utama.find_children("*", "CanvasLayer", true, false):
		for nod in lapis.find_children("*", "VBoxContainer", true, false):
			for nama in TANDA_BEKAS:
				if nod.get_node_or_null(nama) != null:
					return nod as Control
	return null

func _tema_butang() -> Theme:
	# Latar gelap merah nipis supaya butang sentiasa kelihatan walaupun ikon
	# gagal dimuatkan.
	var tema := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.35, 0.08, 0.1, 0.55)
	normal.border_color = Color(0.9, 0.25, 0.25, 0.75)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(4.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.6, 0.14, 0.17, 0.8)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.8, 0.2, 0.2, 0.9)
	tema.set_stylebox("normal", "Button", normal)
	tema.set_stylebox("hover", "Button", hover)
	tema.set_stylebox("pressed", "Button", pressed)
	tema.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return tema

# ==========================================================
# MENU THREAT (gaya menu perabot)
# ==========================================================
func _sedia_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		return

	_menu = PanelContainer.new()
	_menu.name = "MenuThreat"
	_menu.visible = false
	TemaPerabot.pasang(_menu)
	_kanvas.add_child(_menu)

	var akar := VBoxContainer.new()
	akar.add_theme_constant_override("separation", 4)
	_menu.add_child(akar)

	# Header: tajuk + butang tutup.
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
	butang_tutup.pressed.connect(tutup_menu_cepat)
	header.add_child(butang_tutup)

	# Isi: husk (kiri) | info threat (tengah) | pemasa (kanan).
	var isi := HBoxContainer.new()
	isi.add_theme_constant_override("separation", 6)
	akar.add_child(isi)

	var kiri := VBoxContainer.new()
	kiri.custom_minimum_size = Vector2(58, 0)
	kiri.add_theme_constant_override("separation", 2)
	isi.add_child(kiri)

	var ikon := TextureRect.new()
	ikon.texture = _ikon_husk
	ikon.custom_minimum_size = Vector2(48, 48)
	ikon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ikon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ikon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sprite husk asalnya gelap; cerahkan supaya jelas atas panel gelap.
	ikon.modulate = Color(1.9, 1.9, 1.9)
	kiri.add_child(ikon)

	var nama := Label.new()
	nama.text = "Husk Lurker"
	nama.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nama.add_theme_font_size_override("font_size", 6)
	nama.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0, 1.0))
	kiri.add_child(nama)

	var tengah := VBoxContainer.new()
	tengah.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tengah.add_theme_constant_override("separation", 2)
	isi.add_child(tengah)

	_label_status = _buat_label(tengah, "", 6, Color(0.72, 0.93, 1.0, 1.0))
	_label_threat = _buat_label(tengah, "Threat 0%", 9, Color(1.0, 0.55, 0.45, 1.0))
	_label_bunuh = _buat_label(tengah, "Husk kills: 0", 7, Color(0.82, 0.95, 1.0, 1.0))
	_label_raider = _buat_label(tengah, "Est. raiders: 0", 7, Color(0.82, 0.95, 1.0, 1.0))

	var kanan := VBoxContainer.new()
	kanan.custom_minimum_size = Vector2(64, 0)
	kanan.add_theme_constant_override("separation", 2)
	isi.add_child(kanan)

	var label_pemasa := _buat_label(kanan, "Next wave", 6, Color(0.72, 0.9, 1.0, 1.0))
	label_pemasa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_timer = _buat_label(kanan, "--:--", 14, Color(1.0, 0.8, 0.45, 1.0))
	_label_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var butang_tutup_bawah := Button.new()
	butang_tutup_bawah.text = "Close"
	butang_tutup_bawah.focus_mode = Control.FOCUS_NONE
	butang_tutup_bawah.pressed.connect(tutup_menu_cepat)
	akar.add_child(butang_tutup_bawah)

func _buat_label(ibu: Node, teks: String, saiz: int, warna: Color) -> Label:
	var label := Label.new()
	label.text = teks
	label.add_theme_font_size_override("font_size", saiz)
	label.add_theme_color_override("font_color", warna)
	ibu.add_child(label)
	return label

func _tukar_menu() -> void:
	if _menu != null and is_instance_valid(_menu) and _menu.visible:
		_menu.visible = false
		return
	buka_menu()

# Buka menu di tengah skrin (dipanggil butang scene atau butang sendiri).
func buka_menu() -> void:
	if _menu == null or not is_instance_valid(_menu):
		_sedia_menu()
	if _menu == null or not is_instance_valid(_menu):
		return
	_kemas_kini_label()
	_menu.reset_size()
	var saiz_vp: Vector2 = get_viewport().get_visible_rect().size
	_menu.size = Vector2(LEBAR_MENU, maxf(_menu.get_combined_minimum_size().y, 60.0))
	_menu.position = ((saiz_vp - _menu.size) * 0.5).floor()
	_menu.visible = true

# Dipanggil menu HUD jiran (BuildGrid) supaya menu tidak bertindih.
func tutup_menu_cepat() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.visible = false

func tutup_menu() -> void:
	tutup_menu_cepat()

func _kemas_kini_label() -> void:
	if serangan == null or not is_instance_valid(serangan):
		return
	var bunuh: int = int(serangan.get("bilangan_husk_dibunuh"))
	var baki: float = float(serangan.get("baki_masa"))
	var peratus: int = clampi(bunuh * THREAT_SETIAP_BUNUH, 0, 100)

	if _label_threat:
		_label_threat.text = "Threat %d%%" % peratus
	if _label_bunuh:
		_label_bunuh.text = "Husk kills: %d" % bunuh
	if _label_raider:
		# Setiap husk yang dibunuh menjadi satu penyerang.
		_label_raider.text = "Est. raiders: %d" % bunuh
	if _label_status:
		if baki >= 0.0:
			_label_status.text = "Wave incoming"
			_label_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45, 1.0))
		elif bunuh > 0:
			_label_status.text = "Raiders ready"
			_label_status.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45, 1.0))
		else:
			_label_status.text = "No threat"
			_label_status.add_theme_color_override("font_color", Color(0.62, 0.95, 0.7, 1.0))
	if _label_timer:
		if baki >= 0.0:
			var saat: int = maxi(0, ceili(baki))
			_label_timer.text = "%d:%02d" % [saat / 60, saat % 60]
		else:
			_label_timer.text = "--:--"
