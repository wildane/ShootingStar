class_name Tutorial
extends CanvasLayer

# ==========================================================
# TUTORIAL PEMAIN BAHARU (SENARAI SEMAK + COACH MARK)
#
# Setiap langkah ada syarat sendiri (Callable), jadi tutorial maju ikut
# apa yang pemain buat — bukan ikut masa atau teks yang dipaksa.
# Untuk tambah langkah baharu, cukup tambah satu entri dalam
# _senarai_langkah(); UI dan penyimpanan status tidak perlu diubah.
#
# Status tutorial disimpan dalam user://tutorial.json (bebas daripada slot
# simpanan), jadi ia lepas sekali sahaja dan di-reset oleh
# SaveManager.mula_permainan_baru().
# ==========================================================

signal tamat

const LALUAN_STATUS: String = "user://tutorial.json"
const LAYER_TUTORIAL: int = 100  # bawah SaveMenu (101) supaya menu menutupinya

const FON_TAJUK: int = 7
const FON_TEKS: int = 9
const FON_SENARAI: int = 7

# Jarak pemain mesti bergerak sebelum langkah pertama dikira lulus.
const JARAK_BERGERAK: float = 40.0
# Jaring keselamatan: langkah tidak boleh menyekat pemain selama-lamanya.
const MASA_MAKS_LANGKAH: float = 25.0
# Beri masa fade hitam level_3 habis sebelum tutorial muncul.
const JEDA_MULA: float = 1.6
# Jarak pemain ke stesen cas yang dikira "sudah sampai".
const JARAK_CAS: float = 34.0

const WARNA_AKSEN: Color = Color(0.40, 0.80, 0.92)
const WARNA_TEKS: Color = Color(0.86, 0.95, 1.0)
const WARNA_REDUP: Color = Color(0.55, 0.65, 0.75, 0.80)
const WARNA_SIAP: Color = Color(0.45, 0.85, 0.55, 0.90)

var _akar: Control
var _kad: PanelContainer
var _label_teks: Label
var _cincin: Control
var _senarai_semak: PanelContainer
var _butang_langkau: Button
var _baris: Array[Label] = []

var _langkah_semua: Array = []
var _langkah: int = 0
var _masa_langkah: float = 0.0
var _aktif: bool = false
var _tamat: bool = false

var _pemain: Node2D = null
var _pos_asal: Vector2 = Vector2.ZERO
# Kiraan penggunaan objek semasa langkah bermula (pintu, meteor).
var _pintu_awal: int = 0
var _meteorit_awal: int = 0
# Tenaga pemain semasa langkah tenaga bermula.
var _tenaga_awal: float = 0.0


# Cincin berdenyut yang menunjuk tempat pemain patut tekan/drag.
class CincinTunjuk:
	extends Control

	var masa: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		masa += delta
		queue_redraw()

	func _draw() -> void:
		var pusat: Vector2 = size * 0.5
		var denyut: float = 0.5 + 0.5 * sin(masa * 3.0)
		var jejari: float = 22.0 + denyut * 9.0
		# Warna aksen ditulis terus kerana kelas dalaman tidak nampak const induk.
		var warna := Color(0.40, 0.80, 0.92)
		draw_arc(pusat, jejari, 0.0, TAU, 48, Color(warna, 0.85), 2.0, true)
		draw_circle(pusat, 3.0, Color(warna, 0.95))


func _ready() -> void:
	layer = LAYER_TUTORIAL
	# Tutorial ikut pause permainan (default INHERIT): bila menu dibuka,
	# langkah tidak terus berdetik di belakang panel.
	if Tutorial.selesai():
		queue_free()
		return

	_bina_ui()
	set_process(false)
	await _tunggu_pemain()
	if not is_inside_tree():
		return
	_mula_tutorial()


# ==========================================================
# LANGKAH TUTORIAL
# ==========================================================
# Setiap entri: id, label (senarai semak), teks (coach mark),
# cincin (Callable -> Vector2 skrin, pilihan) dan syarat (Callable -> bool).
func _senarai_langkah() -> Array:
	return [
		{
			"id": "bergerak",
			"label": "Move the astronaut",
			"teks": "Drag anywhere to move.\nTap the screen to go there.",
			"cincin": Callable(self, "_cincin_tengah"),
			"syarat": Callable(self, "_semak_bergerak"),
		},
		{
			"id": "pintu",
			"label": "Use the doorway",
			"teks": "Get close to an object and it glows green.\nWalk to the doorway, then tap it.",
			"sasaran_dunia": Callable(self, "_pos_dunia_pintu"),
			"mula": Callable(self, "_rekod_pintu"),
			"syarat": Callable(self, "_semak_pintu"),
			"masa_maks": 45.0,
		},
		{
			"id": "lombong",
			"label": "Mine a meteorite",
			"teks": "Fly into a meteorite to mine it.\nStay close — it takes a few hits.",
			"sasaran_dunia": Callable(self, "_pos_dunia_meteorit"),
			"mula": Callable(self, "_rekod_meteorit"),
			"syarat": Callable(self, "_semak_meteorit"),
			"masa_maks": 60.0,
		},
		{
			"id": "tenaga",
			"label": "Charge your energy",
			"teks": "Flying and drone shots drain your energy.\nThe charging station next to the doorway refills it —\nfollow the ring and stand beside it.",
			"sasaran_dunia": Callable(self, "_pos_dunia_stesen_cas"),
			"mula": Callable(self, "_rekod_tenaga"),
			"syarat": Callable(self, "_semak_tenaga"),
			"masa_maks": 60.0,
		},
	]


func _cincin_tengah() -> Vector2:
	return get_viewport().get_visible_rect().size * Vector2(0.5, 0.52)


func _semak_bergerak() -> bool:
	if not is_instance_valid(_pemain):
		return false
	return _pemain.global_position.distance_to(_pos_asal) > JARAK_BERGERAK


# Nod dalam kumpulan yang paling dekat dengan pemain, atau null.
func _nod_terdekat(kumpulan: String) -> Node2D:
	if not is_instance_valid(_pemain):
		return null

	var terbaik: Node2D = null
	var jarak_terbaik: float = INF
	for nod in get_tree().get_nodes_in_group(kumpulan):
		if not (nod is Node2D):
			continue
		var jarak: float = (nod as Node2D).global_position.distance_to(_pemain.global_position)
		if jarak < jarak_terbaik:
			jarak_terbaik = jarak
			terbaik = nod
	return terbaik


# Posisi dunia sasaran supaya cincin tutorial boleh menunjuk ke sana.
# Vector2.INF bermakna tiada objek dalam kumpulan itu.
func _pos_dunia_kumpulan(kumpulan: String, ofset: Vector2) -> Vector2:
	var nod := _nod_terdekat(kumpulan)
	if nod == null:
		return Vector2.INF
	return nod.global_position + ofset


# Jumlah kiraan penggunaan bagi semua nod dalam kumpulan (cth. berapa kali
# pintu dipakai atau meteor dipukul).
func _jumlah_kumpulan(kumpulan: String, kunci: String) -> int:
	var jumlah: int = 0
	for nod in get_tree().get_nodes_in_group(kumpulan):
		if kunci in nod:
			jumlah += int(nod.get(kunci))
	return jumlah


# Sprite pintu dilukis 8 px di atas asal nod.
func _pos_dunia_pintu() -> Vector2:
	return _pos_dunia_kumpulan("Pintu", Vector2(0.0, -8.0))


func _rekod_pintu() -> void:
	_pintu_awal = _jumlah_kumpulan("Pintu", "jumlah_digunakan")


func _semak_pintu() -> bool:
	return _jumlah_kumpulan("Pintu", "jumlah_digunakan") > _pintu_awal


func _pos_dunia_meteorit() -> Vector2:
	return _pos_dunia_kumpulan("Meteorit", Vector2.ZERO)


func _rekod_meteorit() -> void:
	_meteorit_awal = _jumlah_kumpulan("Meteorit", "jumlah_dilombong")


func _semak_meteorit() -> bool:
	return _jumlah_kumpulan("Meteorit", "jumlah_dilombong") > _meteorit_awal


# Sprite stesen cas lebih kurang 16 unit tinggi, jadi cincin dinaikkan sedikit.
func _pos_dunia_stesen_cas() -> Vector2:
	return _pos_dunia_kumpulan("StesenCas", Vector2(0.0, -8.0))


func _tenaga_pemain() -> float:
	if not is_instance_valid(_pemain):
		return 0.0
	var tenaga: Node = _pemain.get_node_or_null("EnergyComponent")
	if tenaga == null or not ("tenaga" in tenaga):
		return 0.0
	return float(tenaga.get("tenaga"))


func _rekod_tenaga() -> void:
	_tenaga_awal = _tenaga_pemain()


# Cukup apabila pemain sampai ke stesen cas (atau tenaganya sudah bertambah).
func _semak_tenaga() -> bool:
	if _tenaga_pemain() > _tenaga_awal + 0.5:
		return true
	var stesen := _nod_terdekat("StesenCas")
	if stesen != null and is_instance_valid(_pemain):
		return stesen.global_position.distance_to(_pemain.global_position) <= JARAK_CAS
	return false


func _tunggu_pemain() -> void:
	# Player di-spawn oleh level_3 selepas JSON selesai dimuatkan, jadi
	# tutorial kena tunggu dia wujud dahulu.
	await get_tree().create_timer(JEDA_MULA).timeout
	var cubaan: int = 20
	while cubaan > 0:
		_pemain = get_tree().get_first_node_in_group("Player") as Node2D
		if is_instance_valid(_pemain):
			return
		cubaan -= 1
		await get_tree().create_timer(0.25).timeout


func _mula_tutorial() -> void:
	_pos_asal = _pemain.global_position
	_akar.visible = true
	_akar.modulate.a = 1.0
	set_process(true)
	_tunjuk_langkah(0)


func _tunjuk_langkah(indeks: int) -> void:
	if indeks >= _langkah_semua.size():
		_tutup_tutorial()
		return

	_langkah = indeks
	_masa_langkah = 0.0
	_aktif = true
	_label_teks.text = str(_langkah_semua[indeks].get("teks", ""))

	# Langkah boleh sediakan nilai awal sendiri (cth. kiraan pintu).
	var sediakan: Callable = _langkah_semua[indeks].get("mula", Callable())
	if sediakan.is_valid():
		sediakan.call()

	_letak_cincin(indeks)
	_segarkan_senarai()
	print("[Tutorial] Langkah %d: %s" % [indeks + 1, str(_langkah_semua[indeks].get("id", ""))])


func _process(delta: float) -> void:
	if not _aktif:
		return

	_masa_langkah += delta

	# Cincin ikut sasaran dalam dunia (pintu/perabot) setiap bingkai, jadi ia
	# kekal di tempat betul walaupun kamera bergerak.
	var sasaran: Callable = _langkah_semua[_langkah].get("sasaran_dunia", Callable())
	if sasaran.is_valid():
		_letak_cincin_dunia(sasaran.call())

	var syarat: Callable = _langkah_semua[_langkah].get("syarat", Callable())
	var lulus: bool = syarat.is_valid() and bool(syarat.call())
	var masa_maks: float = float(_langkah_semua[_langkah].get("masa_maks", MASA_MAKS_LANGKAH))
	if lulus or _masa_langkah >= masa_maks:
		_lulus_langkah()


func _lulus_langkah() -> void:
	if not _aktif:
		return
	_aktif = false
	_langkah += 1
	_simpan_status()
	Sfx.mainkan("klik", -7.0)
	_tunjuk_langkah(_langkah)


func _tutup_tutorial() -> void:
	if _tamat:
		return

	_aktif = false
	_tamat = true
	set_process(false)
	_simpan_status()
	Sfx.mainkan("menu_tutup", -7.0)
	tamat.emit()

	var tween := create_tween()
	tween.tween_property(_akar, "modulate:a", 0.0, 0.35)
	await tween.finished
	queue_free()


# ==========================================================
# UI
# ==========================================================
func _bina_ui() -> void:
	_akar = Control.new()
	_akar.name = "AkarTutorial"
	_akar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_akar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_akar.visible = false
	add_child(_akar)

	# Tiada lapisan gelap: glow hijau pada pintu/perabot mesti kekal jelas
	# kelihatan, jadi hanya kad teks dan cincin yang dilukis.
	_bina_senarai_semak()
	_bina_kad()

	_cincin = CincinTunjuk.new()
	_cincin.visible = false
	_akar.add_child(_cincin)


# Kotak gaya gelap berbingkai biru, sama rupa dengan peta dan panel menu.
func _kotak_gaya() -> StyleBoxFlat:
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = Color(0.04, 0.06, 0.10, 0.88)
	gaya.border_color = Color(WARNA_AKSEN, 0.55)
	gaya.set_border_width_all(1)
	gaya.set_corner_radius_all(6)
	gaya.content_margin_left = 7.0
	gaya.content_margin_right = 7.0
	gaya.content_margin_top = 5.0
	gaya.content_margin_bottom = 6.0
	return gaya


func _bina_senarai_semak() -> void:
	_langkah_semua = _senarai_langkah()

	_senarai_semak = PanelContainer.new()
	_senarai_semak.name = "SenaraiSemak"
	_senarai_semak.position = Vector2(8.0, 8.0)
	_senarai_semak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_senarai_semak.add_theme_stylebox_override("panel", _kotak_gaya())
	_akar.add_child(_senarai_semak)

	var susunan := VBoxContainer.new()
	susunan.add_theme_constant_override("separation", 3)
	_senarai_semak.add_child(susunan)

	var baris_tajuk := HBoxContainer.new()
	baris_tajuk.add_theme_constant_override("separation", 6)
	susunan.add_child(baris_tajuk)

	var tajuk := Label.new()
	tajuk.text = "GETTING STARTED"
	tajuk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tajuk.add_theme_font_size_override("font_size", FON_TAJUK)
	tajuk.add_theme_color_override("font_color", WARNA_AKSEN)
	baris_tajuk.add_child(tajuk)

	_butang_langkau = Button.new()
	_butang_langkau.text = "Skip"
	_butang_langkau.flat = true
	_butang_langkau.focus_mode = Control.FOCUS_NONE
	_butang_langkau.add_theme_font_size_override("font_size", FON_TAJUK)
	_butang_langkau.add_theme_color_override("font_color", WARNA_REDUP)
	_butang_langkau.pressed.connect(_tutup_tutorial)
	baris_tajuk.add_child(_butang_langkau)

	_baris.clear()
	for data in _langkah_semua:
		var label := Label.new()
		label.text = "[ ] " + str(data.get("label", ""))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(168.0, 0.0)
		label.add_theme_font_size_override("font_size", FON_SENARAI)
		label.add_theme_color_override("font_color", WARNA_REDUP)
		susunan.add_child(label)
		_baris.append(label)

	Sfx.pasang_klik(self)
	_kemas_senarai()


# PanelContainer ikut saiz kandungan, bukan saiz anchor.
func _kemas_senarai() -> void:
	await get_tree().process_frame
	if is_instance_valid(_senarai_semak):
		_senarai_semak.size = _senarai_semak.get_combined_minimum_size()


func _bina_kad() -> void:
	_kad = PanelContainer.new()
	_kad.name = "KadTeks"
	_kad.anchor_left = 0.5
	_kad.anchor_right = 0.5
	_kad.anchor_top = 1.0
	_kad.anchor_bottom = 1.0
	_kad.offset_left = -124.0
	_kad.offset_right = 124.0
	_kad.offset_top = -104.0
	_kad.offset_bottom = -14.0
	_kad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kad.add_theme_stylebox_override("panel", _kotak_gaya())
	_akar.add_child(_kad)

	_label_teks = Label.new()
	_label_teks.text = ""
	_label_teks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_teks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_teks.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_teks.add_theme_font_size_override("font_size", FON_TEKS)
	_label_teks.add_theme_color_override("font_color", WARNA_TEKS)
	_label_teks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kad.add_child(_label_teks)


func _letak_cincin(indeks: int) -> void:
	var pusat: Vector2 = get_viewport().get_visible_rect().size * Vector2(0.5, 0.52)
	var pautan: Callable = _langkah_semua[indeks].get("cincin", Callable())
	if pautan.is_valid():
		var hasil = pautan.call()
		if hasil is Vector2:
			pusat = hasil

	# Langkah yang menunjuk objek dalam dunia dikemas kini setiap bingkai.
	var sasaran: Callable = _langkah_semua[indeks].get("sasaran_dunia", Callable())
	if sasaran.is_valid():
		_letak_cincin_dunia(sasaran.call())
		return

	_cincin.size = Vector2(72.0, 72.0)
	_cincin.position = pusat - _cincin.size * 0.5
	_cincin.visible = true


# Tukar posisi dunia ke posisi skrin, dan rapatkan ke tepi skrin bila sasaran
# berada di luar pandangan supaya pemain tahu arah yang perlu dituju.
func _letak_cincin_dunia(pos_dunia) -> void:
	if not (pos_dunia is Vector2) or pos_dunia == Vector2.INF:
		_cincin.visible = false
		return

	var saiz_skrin: Vector2 = get_viewport().get_visible_rect().size
	var skrin: Vector2 = get_viewport().get_canvas_transform() * pos_dunia
	skrin.x = clampf(skrin.x, 28.0, saiz_skrin.x - 28.0)
	skrin.y = clampf(skrin.y, 28.0, saiz_skrin.y - 28.0)
	_cincin.size = Vector2(72.0, 72.0)
	_cincin.position = skrin - _cincin.size * 0.5
	_cincin.visible = true


func _segarkan_senarai() -> void:
	for i in _baris.size():
		var label: Label = _baris[i]
		var nama: String = str(_langkah_semua[i].get("label", ""))
		if i < _langkah:
			label.text = "[x] " + nama
			label.add_theme_color_override("font_color", WARNA_SIAP)
		elif i == _langkah:
			label.text = "> " + nama
			label.add_theme_color_override("font_color", WARNA_AKSEN)
		else:
			label.text = "[ ] " + nama
			label.add_theme_color_override("font_color", WARNA_REDUP)


# ==========================================================
# STATUS TUTORIAL (user://tutorial.json)
# ==========================================================
# Bebas daripada slot simpanan: tutorial lepas sekali sahaja untuk
# pemasangan ini, dan di-reset bila pemain mula permainan baharu.
static func selesai() -> bool:
	return bool(_baca_status().get("selesai", false))


static func _baca_status() -> Dictionary:
	if not FileAccess.file_exists(LALUAN_STATUS):
		return {}
	var fail := FileAccess.open(LALUAN_STATUS, FileAccess.READ)
	if fail == null:
		return {}
	var teks := fail.get_as_text()
	fail.close()
	var data = JSON.parse_string(teks)
	return data if data is Dictionary else {}


# Dipanggil SaveManager semasa "New Game" supaya tutorial bermula semula.
static func reset() -> void:
	if FileAccess.file_exists(LALUAN_STATUS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LALUAN_STATUS))


func _simpan_status() -> void:
	var fail := FileAccess.open(LALUAN_STATUS, FileAccess.WRITE)
	if fail == null:
		return
	fail.store_string(JSON.stringify({"selesai": _tamat, "langkah": _langkah}))
	fail.close()
