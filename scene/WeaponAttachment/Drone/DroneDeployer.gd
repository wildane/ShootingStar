extends Button

# --- SLOT INSPECTOR ---
# Senarai jenis dron yang boleh dipilih (3 jenis)
@export var drone_scenes: Array[PackedScene] = []
@export var drone_names: Array[String] = []
# ID item dalam beg yang membuka setiap jenis dron (selari dengan drone_scenes).
# Jenis hanya boleh dipilih selepas dron itu dibuat di Fabricator.
# Biarkan kosong untuk jenis yang sentiasa terbuka.
@export var drone_item_ids: Array[String] = []
@export var spawn_icon: Texture2D

# --- KEADAAN ---
# Hanya SATU dron boleh aktif pada satu masa
var active_drone: Node2D = null
var active_index: int = -1

var _opsi: HBoxContainer
var _butang_jenis: Dictionary = {} # indeks dron -> Button
var _kumpulan: ButtonGroup

# Warna ikon setiap jenis (sama dengan warna dron dalam game)
const WARNA_JENIS: Array[Color] = [Color(0.45, 0.95, 1.0), Color.WHITE, Color(1.0, 0.65, 0.25)]
# Warna ikon semasa dron OFF: kelabu pertengahan supaya nampak atas
# background gelap (hitam) dan juga background cerah
const WARNA_OFF: Color = Color(0.62, 0.66, 0.72, 0.95)


func _ready() -> void:
	pressed.connect(_on_self_pressed)
	if spawn_icon:
		icon = spawn_icon
	# Belum ada dron dipilih: ikon butang utama jadi kelabu (OFF)
	self_modulate = WARNA_OFF
	# _ready() boleh berlaku semasa induk masih menyediakan anak-anak,
	# jadi bina baris pilihan secara deferred supaya add_child() tak gagal.
	_bina_pemilih.call_deferred()
	_sambung_inventori.call_deferred()


func _induk_ui() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n is CanvasLayer:
			return n
		n = n.get_parent()
	return get_tree().current_scene


func _inventori():
	return get_node_or_null("/root/InventoryManager")


# Dron hanya muncul dalam senarai bila item dron itu ada dalam beg
func _sambung_inventori() -> void:
	var inv = _inventori()
	if inv and inv.has_signal("inventory_dikemaskini"):
		if not inv.inventory_dikemaskini.is_connected(_on_inventori_berubah):
			inv.inventory_dikemaskini.connect(_on_inventori_berubah)


func _on_inventori_berubah() -> void:
	_isi_butang_jenis()
	# Dron yang sedang aktif hilang kebenaran (cth. item dibuang) -> matikan
	if active_index >= 0 and not _butang_jenis.has(active_index):
		_matikan_drone()
	_susun_tanda_aktif()


func _ada_dalam_beg(id_item: String) -> bool:
	var inv = _inventori()
	if inv == null:
		return false
	for barang in inv.senarai_barang:
		if barang.get("id") == id_item and int(barang.get("kuantiti", 0)) > 0:
			return true
	return false


# Senarai indeks jenis dron yang sudah dibuat oleh player
func _jenis_terbuka() -> Array:
	var hasil: Array = []
	for i in drone_scenes.size():
		if drone_scenes[i] == null:
			continue
		var id_item: String = drone_item_ids[i] if i < drone_item_ids.size() else ""
		if id_item != "" and not _ada_dalam_beg(id_item):
			continue
		hasil.append(i)
	return hasil


func _nama_jenis(i: int) -> String:
	if i < drone_names.size() and drone_names[i] != "":
		return drone_names[i]
	var s := drone_scenes[i]
	if s != null:
		return s.resource_path.get_file().get_basename()
	return "Drone %d" % (i + 1)


func _warna_jenis(i: int) -> Color:
	return WARNA_JENIS[i % WARNA_JENIS.size()]


# Baris butang pilihan jenis dron - gaya sama dengan butang build (32x32, expand ke kanan)
func _bina_pemilih() -> void:
	var induk := _induk_ui()
	if induk == null or drone_scenes.is_empty():
		return

	_opsi = HBoxContainer.new()
	_opsi.visible = false
	_opsi.modulate.a = 0.0
	_opsi.scale.x = 0.0
	_opsi.z_index = 100
	_opsi.add_theme_constant_override("separation", 2)

	induk.add_child(_opsi)
	_isi_butang_jenis()

	# Kemas kini baris bila dron baru siap dibuat di Fabricator
	_sambung_inventori()
	_susun_tanda_aktif()
	print("Pemilih dron dibina: ", _jenis_terbuka().size(), " jenis terbuka")


# Isi semula baris dengan jenis dron yang sudah dibuat sahaja
func _isi_butang_jenis() -> void:
	if _opsi == null:
		return

	for anak in _opsi.get_children():
		_opsi.remove_child(anak)
		anak.queue_free()
	_butang_jenis.clear()

	_kumpulan = ButtonGroup.new()
	_kumpulan.allow_unpress = true # tekan jenis yang sama = matikan dron

	for i in _jenis_terbuka():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _kumpulan
		b.custom_minimum_size = Vector2(32, 32)
		b.flat = true # sama macam butang build: tiada latar
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true # ikon 409x437 dikecilkan ke 32x32
		b.icon = spawn_icon
		b.self_modulate = _warna_jenis(i)
		b.tooltip_text = _nama_jenis(i)
		b.toggled.connect(_on_jenis_ditukar.bind(i))
		_opsi.add_child(b)
		_butang_jenis[i] = b


# Butang utama:
# - Dron aktif  -> tekan = matikan dron (ikon jadi kelabu semula)
# - Dron OFF    -> tekan = buka baris pilihan jenis dron yang sudah dibuat
func _on_self_pressed() -> void:
	if active_index >= 0:
		_matikan_drone()
		tutup_menu()
		return

	if _opsi == null:
		return

	if _jenis_terbuka().is_empty():
		tutup_menu()
		_tunjuk_hint("Craft a drone at the Fabricator first")
		return

	if _opsi.visible:
		tutup_menu()
		return

	# Tutup panel bina / inventori dulu supaya tak bertindih
	_tutup_menu_lain()

	# Segarkan senarai setiap kali menu dibuka (dron baru mungkin baru siap)
	_isi_butang_jenis()
	_susun_tanda_aktif()

	# Letak baris tepat di kanan butang ini
	_opsi.position = global_position + Vector2(size.x + 2.0, 0.0)
	_opsi.pivot_offset = Vector2.ZERO
	_opsi.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_opsi, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_opsi, "modulate:a", 1.0, 0.2)


func _tutup_menu_lain() -> void:
	var induk := get_parent()
	if induk == null:
		return
	for nod in induk.get_children():
		if nod == self:
			continue
		if nod.has_method("tutup_menu_cepat"):
			nod.tutup_menu_cepat()
		elif nod.has_method("tutup_menu"):
			nod.tutup_menu()


func tutup_menu() -> void:
	if _opsi == null:
		return
	_opsi.scale.x = 0.0
	_opsi.modulate.a = 0.0
	_opsi.visible = false


func _on_jenis_ditukar(ditekan: bool, i: int) -> void:
	if ditekan:
		_aktifkan(i)
	elif active_index == i:
		_matikan_drone()


# Aktifkan jenis dron i (jenis lain automatik dimatikan)
func _aktifkan(i: int) -> void:
	if i < 0 or i >= drone_scenes.size() or drone_scenes[i] == null:
		print("Gagal: Dron pada slot %d tiada di Inspector butang!" % i)
		return

	if not _butang_jenis.has(i):
		_tunjuk_hint(_nama_jenis(i) + " has not been crafted yet")
		return

	_kosongkan_drone()

	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		print("Gagal: Node Player tidak dijumpai dalam group 'Player'")
		return

	var dron: Node2D = drone_scenes[i].instantiate()
	dron.global_position = player.global_position
	get_tree().current_scene.add_child(dron)

	active_drone = dron
	active_index = i
	_susun_tanda_aktif()
	tutup_menu()
	print("Dron aktif (", _nama_jenis(i), ") - ", dron.name)


func _matikan_drone() -> void:
	_kosongkan_drone()
	active_index = -1
	_susun_tanda_aktif()
	print("Dron telah dipadam (OFF)")


func _kosongkan_drone() -> void:
	if is_instance_valid(active_drone):
		active_drone.queue_free()
	active_drone = null


# Kemas kini ikon butang utama + tanda jenis yang sedang aktif
func _susun_tanda_aktif() -> void:
	for i in _butang_jenis.keys():
		var b: Button = _butang_jenis[i]
		b.set_pressed_no_signal(i == active_index)
		b.modulate = Color.WHITE if i == active_index else Color(0.55, 0.55, 0.55, 0.85)

	# Butang utama ikut jenis dron yang sedang aktif; OFF = kelabu
	if active_index >= 0 and _butang_jenis.has(active_index):
		icon = _butang_jenis[active_index].icon
		self_modulate = _warna_jenis(active_index)
	else:
		if spawn_icon:
			icon = spawn_icon
		self_modulate = WARNA_OFF


# Mesej pendek pada panel info (tutup sendiri selepas 2 saat)
func _tunjuk_hint(teks: String) -> void:
	print("Dron: ", teks)
	var adegan := get_tree().current_scene
	if adegan == null:
		return
	var lbl := adegan.find_child("InfoText", true, false) as Label
	if lbl == null:
		return
	lbl.text = teks
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(lbl) and lbl.text == teks:
		lbl.text = ""
