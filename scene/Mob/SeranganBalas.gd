extends Node

# ==========================================================
# SERANGAN BALAS HUSK
#
# Setiap HuskLurker yang dibunuh di mana-mana menaikkan threat 1%.
# Serangan dijadualkan 3 minit selepas bunuhan pertama; bila tiba
# masanya, bilangan penyerang ikut threat semasa (lihat StorThreat).
# Threat dan baki masa disimpan ke cakera, jadi ia kekal selepas game
# ditutup. Selepas gelombang, pemasa hanya bermula semula apabila
# pemain membunuh husk lagi.
#
# Nod ini duduk dalam level_3.tscn (bukan autoload) supaya ia pasti
# dimuatkan pada semua peranti.
# ==========================================================

signal serangan_dijadualkan(masa_serang: float)
signal serangan_bermula(bilangan: int)

# Jarak penyerang dianggap sudah tiba di pangkalan.
const JEJARI_TIBA: float = 26.0

# Pusat pangkalan pemain (kawasan bina di atas asteroid).
@export var posisi_pangkalan: Vector2 = Vector2(141.0, 228.0)
# Penyerang muncul di keliling batu asteroid yang pemain guna sebagai pangkalan:
# sedikit di luar tepi batu, jadi mereka datang dari semua arah.
@export var tambahan_jarak_spawn: float = 24.0
@export var jarak_min_spawn: float = 8.0
@export var jejari_kolider_spawn: float = 10.0
@export # Penyerang gelombang guna HuskLurker Raider (hijau, lendir kuning, tiada drop).
var scene_penyerang: PackedScene = preload("res://scene/Mob/HuskLurkerRaider/HuskLurkerRaider.tscn")

var _simpan_tick: float = 2.0

# Kiraan dan baki masa disimpan pada stor static (dikongsi menu threat),
# supaya menu tetap menunjukkan angka terbaru walaupun nilai di sini hilang.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Sambung semula threat + baki masa yang disimpan sebelum ini.
	StorThreat.muat()
	if StorThreat.masa_serang >= 0.0:
		print("SeranganBalas: sambung pemasa, baki %.1f saat (threat %d%%)" % [StorThreat.masa_serang, StorThreat.peratus()])

# Dipanggil oleh HuskLurker yang tumbang. Setiap bunuhan dikira,
# tidak kira di mana husk itu dibunuh. Posisi dikekalkan dalam
# tandatangan untuk keserasian pemanggil.
func daftar_bunuh_husk(_posisi: Vector2 = Vector2.ZERO) -> void:
	# StorThreat.daftar_bunuh() (dipanggil HuskLurker) sudah menaikkan threat dan
	# memulakan pemasa kalau belum berjalan; di sini kita cuma beri notis.
	if StorThreat.masa_serang > 0.0:
		print("SeranganBalas: threat %d%%, serangan balas dalam %.0f saat" % [StorThreat.peratus(), StorThreat.masa_serang])
		emit_signal("serangan_dijadualkan", StorThreat.masa_serang)


func _process(delta: float) -> void:
	if StorThreat.masa_serang < 0.0:
		return

	StorThreat.masa_serang -= delta
	if StorThreat.masa_serang <= 0.0:
		_lancar_serangan()
		return

	# Simpan baki masa sekali-sekala supaya pemasa kekal selepas game ditutup.
	_simpan_tick -= delta
	if _simpan_tick <= 0.0:
		_simpan_tick = 2.0
		StorThreat.simpan()

# Hantar semua penyerang terkumpul ke pangkalan.
# Bilangan penyerang ikut threat semasa (10% = 1 ... 100% = 6).
func _lancar_serangan() -> void:
	var jumlah: int = StorThreat.bilangan_raider()

	if jumlah <= 0:
		StorThreat.selesai_gelombang()
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
		StorThreat.masa_serang = 1.0
		return

	# Penyerang muncul di keliling asteroid yang ada pangkalan pemain, bukan
	# dekat player. Dari situ mereka menyerang dinding/lantai/pintu/perabot.
	var kawasan: Dictionary = _kawasan_pangkalan()
	var pusat_asteroid: Vector2 = kawasan.get("pusat", posisi_pangkalan)
	var jejari_asteroid: float = float(kawasan.get("jejari", 120.0))
	var pusat_bina: Vector2 = kawasan.get("pusat_bina", pusat_asteroid)

	for i in range(jumlah):
		var penyerang := scene_penyerang.instantiate() as Node2D
		if penyerang == null:
			continue
		# Mod penyerang: abaikan sarang/zon dungeon, tuju pangkalan pemain.
		penyerang.set("mod_penyerang", true)
		penyerang.set("posisi_pangkalan", pusat_bina)
		bekas.add_child(penyerang)
		penyerang.global_position = _posisi_spawn(i, jumlah, pusat_asteroid, jejari_asteroid)
		print("SeranganBalas: penyerang muncul di ", penyerang.global_position, " (pangkal ", pusat_bina, ")")

	print("SeranganBalas: %d penyerang husk muncul di keliling asteroid %s (threat %d%%)" % [jumlah, pusat_asteroid, StorThreat.peratus()])
	# Gelombang sudah dilancarkan: pemasa berhenti, threat dikekalkan untuk
	# gelombang seterusnya yang bermula pada bunuhan husk berikutnya.
	StorThreat.selesai_gelombang()
	serangan_bermula.emit(jumlah)

# Pusat dan jejari asteroid pangkalan, serta pusat binaan pemain di atasnya.
# Asteroid dipilih yang paling hampir dengan pusat binaan (atau posisi pangkalan
# lalai kalau pemain belum membina apa-apa).
func _kawasan_pangkalan() -> Dictionary:
	var pusat_bina: Vector2 = posisi_pangkalan
	var grid := get_tree().get_first_node_in_group("BuildGrid")
	if grid != null and grid.has_method("pusat_binaan"):
		var pusat: Vector2 = grid.call("pusat_binaan")
		if pusat != Vector2.ZERO:
			pusat_bina = pusat

	var asteroid: Node2D = null
	var jarak_terbaik := INF
	for calon in get_tree().get_nodes_in_group("Asteroid"):
		var nod := calon as Node2D
		if nod == null or not is_instance_valid(nod):
			continue
		var jarak: float = nod.global_position.distance_to(pusat_bina)
		if jarak < jarak_terbaik:
			jarak_terbaik = jarak
			asteroid = nod

	if asteroid == null:
		return {"pusat": pusat_bina, "jejari": 120.0, "pusat_bina": pusat_bina}
	var jejari: float = float(asteroid.get("jejari"))
	if jejari <= 0.0:
		jejari = 120.0
	return {"pusat": asteroid.global_position, "jejari": jejari, "pusat_bina": pusat_bina}

# Player pemain (group "Player" atau nod SpaceShip dalam scene semasa).
func _cari_player() -> Node2D:
	var player: Node2D = get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		var scene_utama := get_tree().current_scene
		if scene_utama != null:
			player = scene_utama.find_child("SpaceShip", true, false) as Node2D
	return player

# Titik spawn rawak di keliling asteroid (sedikit di luar tepi batu) supaya
# penyerang datang dari semua arah. Jika titik terkena dinding, cuba sudut lain
# supaya penyerang tidak tersangkut dalam batu.
func _posisi_spawn(indeks: int, jumlah: int, pusat: Vector2, jejari: float) -> Vector2:
	var jumlah_selamat: int = maxi(1, jumlah)
	for _cubaan in range(10):
		var sudut: float = TAU * float(indeks) / float(jumlah_selamat) + randf_range(-0.35, 0.35)
		var jarak: float = jejari + randf_range(jarak_min_spawn, maxf(jarak_min_spawn, tambahan_jarak_spawn))
		var calon: Vector2 = pusat + Vector2.RIGHT.rotated(sudut) * jarak
		if not _dalam_dinding(calon):
			return calon

	var sudut_asas: float = TAU * float(indeks) / float(jumlah_selamat)
	return pusat + Vector2.RIGHT.rotated(sudut_asas) * (jejari + jarak_min_spawn)

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
