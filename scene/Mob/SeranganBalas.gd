extends Node

# ==========================================================
# SERANGAN BALAS HUSK
#
# Setiap HuskLurker yang dibunuh di mana-mana menambah SATU
# penyerang. Serangan dijadualkan 5 minit selepas bunuhan pertama;
# bila tiba masanya, semua penyerang yang terkumpul bergerak
# menyerang pangkalan pemain.
#
# Komponen ini autoload supaya kiraan tidak hilang bila scene
# dimuat semula. HuskLurker hanya perlu lapor kematiannya.
# ==========================================================

signal serangan_dijadualkan(masa_serang: float)
signal serangan_bermula(bilangan: int)

# Masa menunggu sebelum serangan balas bermula (5 saat, sementara untuk ujian).
const MASA_SERANGAN: float = 5.0
# Jarak penyerang dianggap sudah tiba di pangkalan.
const JEJARI_TIBA: float = 26.0
# Skrip HUD (butang threat + menu info husk).
const scene_hud_threat: Script = preload("res://scene/ui/ThreatHud.gd")

# Pusat pangkalan pemain (kawasan bina di atas asteroid).
@export var posisi_pangkalan: Vector2 = Vector2(141.0, 228.0)
# Penyerang muncul dalam bulatan mengelilingi player (untuk ujian).
@export var jejari_spawn: float = 90.0
@export var jejari_kolider_spawn: float = 10.0
@export var scene_penyerang: PackedScene = preload("res://scene/Mob/HuskLurker/HuskLurker.tscn")

# Bilangan penyerang yang menunggu masa serangan.
var bilangan_husk_dibunuh: int = 0
# Baki masa sehingga serangan; < 0 bermaksud tiada serangan dijadualkan.
var baki_masa: float = -1.0

# HUD threat: butang dalam group ikon kiri + menu info husk.
var _hud: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_sedia_hud()

# Dipanggil oleh HuskLurker yang tumbang. Setiap bunuhan dikira,
# tidak kira di mana husk itu dibunuh. Posisi dikekalkan dalam
# tandatangan untuk keserasian pemanggil.
func daftar_bunuh_husk(_posisi: Vector2 = Vector2.ZERO) -> void:
	bilangan_husk_dibunuh += 1

	if baki_masa < 0.0:
		baki_masa = MASA_SERANGAN
		print("SeranganBalas: husk tumbang, serangan balas dalam %.0f saat" % MASA_SERANGAN)
		serangan_dijadualkan.emit(MASA_SERANGAN)

	_kemas_hud(0.0)

func _process(delta: float) -> void:
	if baki_masa >= 0.0:
		baki_masa -= delta
		if baki_masa <= 0.0:
			_lancar_serangan()

	_kemas_hud(delta)

# Hantar semua penyerang terkumpul ke pangkalan.
func _lancar_serangan() -> void:
	baki_masa = -1.0
	var jumlah: int = bilangan_husk_dibunuh
	bilangan_husk_dibunuh = 0

	if jumlah <= 0:
		return

	var scene_utama := get_tree().current_scene
	var bekas: Node = null
	if scene_utama != null:
		bekas = scene_utama.get_node_or_null("Y_Sort_Container")
		# Kalau scene ini tiada Y_Sort_Container, guna scene utama terus.
		if bekas == null:
			bekas = scene_utama
	if bekas == null or scene_penyerang == null:
		# Bukan dalam level permainan (contoh: menu) - cuba lagi sekejap lagi.
		print("SeranganBalas: tiada scene/penyerang, cuba lagi (scene=", scene_utama, ")")
		bilangan_husk_dibunuh = jumlah
		baki_masa = 1.0
		return

	# Untuk ujian: penyerang muncul dekat player, bukan di sekeliling pangkalan.
	var player: Node2D = _cari_player()
	var pusat: Vector2 = posisi_pangkalan
	if is_instance_valid(player):
		pusat = player.global_position

	for i in range(jumlah):
		var penyerang := scene_penyerang.instantiate() as Node2D
		if penyerang == null:
			continue
		# Mod penyerang: abaikan sarang/zon dungeon, tuju tempat player berada.
		penyerang.set("mod_penyerang", true)
		penyerang.set("posisi_pangkalan", pusat)
		bekas.add_child(penyerang)
		penyerang.global_position = _posisi_spawn(i, jumlah, pusat)
		print("SeranganBalas: penyerang muncul di ", penyerang.global_position, " (player di ", pusat, ")")

	print("SeranganBalas: %d penyerang husk muncul dekat player di %s" % [jumlah, pusat])
	serangan_bermula.emit(jumlah)

# Player pemain (group "Player" atau nod SpaceShip dalam scene semasa).
func _cari_player() -> Node2D:
	var player: Node2D = get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		var scene_utama := get_tree().current_scene
		if scene_utama != null:
			player = scene_utama.find_child("SpaceShip", true, false) as Node2D
	return player

# Titik spawn dalam bulatan sekeliling pusat (player). Jika titik terkena dinding,
# cuba sudut lain supaya penyerang tidak tersangkut dalam batu.
func _posisi_spawn(indeks: int, jumlah: int, pusat: Vector2) -> Vector2:
	var jumlah_selamat: int = maxi(1, jumlah)
	for _cubaan in range(8):
		var sudut: float = TAU * float(indeks) / float(jumlah_selamat) + randf_range(-0.25, 0.25)
		var jarak: float = jejari_spawn + randf_range(-16.0, 16.0)
		var calon: Vector2 = pusat + Vector2.RIGHT.rotated(sudut) * jarak
		if not _dalam_dinding(calon):
			return calon

	var sudut_asas: float = TAU * float(indeks) / float(jumlah_selamat)
	return pusat + Vector2.RIGHT.rotated(sudut_asas) * jejari_spawn

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
# Butang threat + menu dibina oleh ThreatHud. Ia membina semula butangnya
# sendiri selepas tukar scene dan mengemas kini menu hanya bila dibuka.
func _sedia_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		return
	_hud = scene_hud_threat.new()
	_hud.name = "ThreatHud"
	add_child(_hud)
	_hud.pasang(self)

# Dipanggil butang threat dalam scene (ButangThreat.gd).
func buka_menu_threat() -> void:
	_sedia_hud()
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("buka_menu"):
		_hud.buka_menu()

func _kemas_hud(delta: float) -> void:
	_sedia_hud()
	if _hud != null and is_instance_valid(_hud):
		_hud.kemas_kini(delta)
