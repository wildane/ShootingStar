extends Button

# --- SLOT INSPECTOR ---
# Senarai jenis dron yang boleh dipilih (3 jenis)
@export var drone_scenes: Array[PackedScene] = []
@export var drone_names: Array[String] = []
@export var spawn_icon: Texture2D

# --- KEADAAN ---
# Hanya SATU dron boleh aktif pada satu masa
var active_drone: Node2D = null
var active_index: int = -1

var _opsi: HBoxContainer
var _butang_jenis: Array[Button] = []
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


func _induk_ui() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n is CanvasLayer:
			return n
		n = n.get_parent()
	return get_tree().current_scene


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

	_kumpulan = ButtonGroup.new()
	_kumpulan.allow_unpress = true # tekan jenis yang sama = matikan dron

	_opsi = HBoxContainer.new()
	_opsi.visible = false
	_opsi.modulate.a = 0.0
	_opsi.scale.x = 0.0
	_opsi.z_index = 100
	_opsi.add_theme_constant_override("separation", 2)

	for i in drone_scenes.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _kumpulan
		b.custom_minimum_size = Vector2(32, 32)
		b.flat = true # sama macam butang build: tiada latar
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true # ikon 409x437 dikecilkan ke 32x32
		b.icon = spawn_icon
		b.self_modulate = _warna_jenis(i)
		b.toggled.connect(_on_jenis_ditukar.bind(i))
		_opsi.add_child(b)
		_butang_jenis.append(b)

	induk.add_child(_opsi)
	_susun_tanda_aktif()
	print("Pemilih dron dibina: ", drone_scenes.size(), " jenis")


# Butang utama:
# - Dron aktif  -> tekan = matikan dron (ikon jadi hitam semula)
# - Dron OFF    -> tekan = buka baris pilihan jenis dron
func _on_self_pressed() -> void:
	if active_index >= 0:
		_matikan_drone()
		tutup_menu()
		return

	if _opsi == null:
		_aktifkan(0)
		return

	if _opsi.visible:
		tutup_menu()
		return

	# Letak baris tepat di kanan butang ini
	_opsi.position = global_position + Vector2(size.x + 2.0, 0.0)
	_opsi.pivot_offset = Vector2.ZERO
	_opsi.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_opsi, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_opsi, "modulate:a", 1.0, 0.2)


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
	for i in _butang_jenis.size():
		_butang_jenis[i].set_pressed_no_signal(i == active_index)
		_butang_jenis[i].modulate = Color.WHITE if i == active_index else Color(0.55, 0.55, 0.55, 0.85)

	# Butang utama ikut jenis dron yang sedang aktif; OFF = kelabu
	if active_index >= 0 and active_index < _butang_jenis.size():
		icon = _butang_jenis[active_index].icon
		self_modulate = _warna_jenis(active_index)
	else:
		if spawn_icon:
			icon = spawn_icon
		self_modulate = WARNA_OFF
