extends Node

# ==========================================================
# SERANGAN BALAS HUSK
#
# Setiap HuskLurker yang dibunuh di kawasan TheAquaHusk menambah
# SATU penyerang. Serangan dijadualkan 5 minit selepas bunuhan
# pertama; bila tiba masanya, semua penyerang yang terkumpul
# bergerak menyerang pangkalan pemain.
#
# Komponen ini autoload supaya kiraan tidak hilang bila scene
# dimuat semula. HuskLurker hanya perlu lapor kematiannya.
# ==========================================================

signal serangan_dijadualkan(masa_serang: float)
signal serangan_bermula(bilangan: int)

# Masa menunggu sebelum serangan balas bermula (5 minit).
const MASA_SERANGAN: float = 300.0
# Jarak penyerang dianggap sudah tiba di pangkalan.
const JEJARI_TIBA: float = 26.0

# Zon TheAquaHusk dalam koordinat dunia (sama dengan zona_batas HuskLurker).
@export var zona_aquahusk: Rect2 = Rect2(-470.0, -1530.0, 880.0, 1460.0)
# Pusat pangkalan pemain (kawasan bina di atas asteroid).
@export var posisi_pangkalan: Vector2 = Vector2(141.0, 228.0)
# Penyerang muncul dalam bulatan mengelilingi pangkalan, di luar skrin.
@export var jejari_spawn: float = 240.0
@export var jejari_kolider_spawn: float = 10.0
@export var scene_penyerang: PackedScene = preload("res://scene/Mob/HuskLurker/HuskLurker.tscn")

# Bilangan penyerang yang menunggu masa serangan.
var bilangan_husk_dibunuh: int = 0
# Baki masa sehingga serangan; < 0 bermaksud tiada serangan dijadualkan.
var baki_masa: float = -1.0

var _masa_papar_notis: float = 0.0
var _kanvas: CanvasLayer
var _label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_sedia_hud()

# Dipanggil oleh HuskLurker yang tumbang. Posisi digunakan untuk memastikan
# hanya bunuhan di dalam kawasan TheAquaHusk yang dikira.
func daftar_bunuh_husk(posisi: Vector2) -> void:
	if not zona_aquahusk.has_point(posisi):
		return

	bilangan_husk_dibunuh += 1

	if baki_masa < 0.0:
		baki_masa = MASA_SERANGAN
		print("SeranganBalas: husk tumbang, serangan balas dalam %.0f saat" % MASA_SERANGAN)
		serangan_dijadualkan.emit(MASA_SERANGAN)

	_sedia_hud()
	_kemas_kini_label()
	if is_instance_valid(_label):
		_label.visible = true

func _process(delta: float) -> void:
	if baki_masa >= 0.0:
		baki_masa -= delta
		if baki_masa <= 0.0:
			_lancar_serangan()
		else:
			_kemas_kini_label()

	if _masa_papar_notis > 0.0:
		_masa_papar_notis -= delta
		if _masa_papar_notis <= 0.0 and is_instance_valid(_label):
			_label.visible = false

# Hantar semua penyerang terkumpul ke pangkalan.
func _lancar_serangan() -> void:
	baki_masa = -1.0
	var jumlah: int = bilangan_husk_dibunuh
	bilangan_husk_dibunuh = 0

	if jumlah <= 0:
		_sembunyi_label()
		return

	var scene_utama := get_tree().current_scene
	var bekas: Node = scene_utama.get_node_or_null("Y_Sort_Container") if scene_utama != null else null
	if bekas == null or scene_penyerang == null:
		# Bukan dalam level permainan (contoh: menu) - cuba lagi sekejap lagi.
		bilangan_husk_dibunuh = jumlah
		baki_masa = 1.0
		return

	for i in range(jumlah):
		var penyerang := scene_penyerang.instantiate() as Node2D
		if penyerang == null:
			continue
		# Mod penyerang: abaikan sarang/zon dungeon, tuju pangkalan pemain.
		penyerang.set("mod_penyerang", true)
		penyerang.set("posisi_pangkalan", posisi_pangkalan)
		bekas.add_child(penyerang)
		penyerang.global_position = _posisi_spawn(i, jumlah)

	print("SeranganBalas: %d penyerang husk menyerang pangkalan di %s" % [jumlah, posisi_pangkalan])
	serangan_bermula.emit(jumlah)
	_tunjuk_notis("%d husk attacker%s heading to your base!" % [jumlah, "" if jumlah == 1 else "s"])

# Titik spawn dalam bulatan sekeliling pangkalan. Jika titik terkena dinding,
# cuba sudut lain supaya penyerang tidak tersangkut dalam batu.
func _posisi_spawn(indeks: int, jumlah: int) -> Vector2:
	var jumlah_selamat: int = maxi(1, jumlah)
	for _cubaan in range(8):
		var sudut: float = TAU * float(indeks) / float(jumlah_selamat) + randf_range(-0.25, 0.25)
		var jarak: float = jejari_spawn + randf_range(-24.0, 24.0)
		var calon: Vector2 = posisi_pangkalan + Vector2.RIGHT.rotated(sudut) * jarak
		if not _dalam_dinding(calon):
			return calon

	var sudut_asas: float = TAU * float(indeks) / float(jumlah_selamat)
	return posisi_pangkalan + Vector2.RIGHT.rotated(sudut_asas) * jejari_spawn

func _dalam_dinding(titik: Vector2) -> bool:
	var dunia := get_viewport().find_world_2d() if get_viewport() != null else null
	if dunia == null:
		return false
	var bentuk := CircleShape2D.new()
	bentuk.radius = jejari_kolider_spawn
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = bentuk
	query.transform = Transform2D(0.0, titik)
	query.collision_mask = 2  # Layer dinding
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not dunia.direct_space_state.intersect_shape(query, 1).is_empty()

# ---------- HUD ----------
func _sedia_hud() -> void:
	if _kanvas != null and is_instance_valid(_kanvas):
		return

	_kanvas = CanvasLayer.new()
	_kanvas.name = "HudSeranganBalas"
	_kanvas.layer = 95
	add_child(_kanvas)

	_label = Label.new()
	_label.name = "LabelSeranganBalas"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.09, 0.95))
	_label.add_theme_constant_override("outline_size", 3)
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 44.0
	_label.visible = false
	_kanvas.add_child(_label)

func _kemas_kini_label() -> void:
	if not is_instance_valid(_label):
		return
	var saat_baki: int = maxi(0, ceili(baki_masa))
	var m: int = saat_baki / 60
	var s: int = saat_baki % 60
	_label.text = "Husk counterattack in %d:%02d  (%d attacker%s)" % [
		m, s, bilangan_husk_dibunuh, "" if bilangan_husk_dibunuh == 1 else "s",
	]

func _tunjuk_notis(teks: String) -> void:
	_sedia_hud()
	if not is_instance_valid(_label):
		return
	_label.text = teks
	_label.visible = true
	_masa_papar_notis = 6.0

func _sembunyi_label() -> void:
	if is_instance_valid(_label):
		_label.visible = false
