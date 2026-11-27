extends "res://scene/Mob/HuskLurker/HuskLurker.gd"

# ==========================================================
# HUSK LURKER RAIDER
#
# Sama seperti HuskLurker biasa (stat, AI, lendir) tetapi:
#   - badan hijau, lendir kuning (aset berasingan)
#   - mati tidak menjatuhkan apa-apa (scene tiada DropComponent)
#   - masa muncul: animasi teleport (sama seperti pintu) + bunyi
#     teleport, kemudian baru badan kelihatan dan mula bergerak
# ==========================================================

const KESAN_TELEPORT := preload("res://scene/level_3/build_system/doorway/KesanTeleport.gd")
const BAR_HP := preload("res://scene/level_3/build_system/BarHpStruktur.gd")

## Tempoh animasi teleport sebelum badan benar-benar muncul.
@export var masa_teleport: float = 0.4

# --- Serangan pangkalan ---
## Jarak untuk memusnahkan sasaran: raider tembak struktur (dinding/lantai/pintu/
## perabot) dari jauh, tak perlu sentuh dulu.
@export var jarak_serang: float = 120.0
## Jarak carian sasaran di sekeliling raider.
@export var jarak_cari_sasaran: float = 520.0
## Sela semakan semula sasaran (saat).
@export var sela_cari_sasaran: float = 0.35
## Jeda antara dua tembakan lendir ke struktur pangkalan (saat).
@export var jeda_serang: float = 2.0
## HP perabot: berapa kali lendir kena sebelum perabot pecah.
@export var hp_perabot: int = 2

# Kumpulan nod yang boleh dimusnahkan: perabot, pintu, panel solar, inverter.
const KUMPULAN_SASARAN: Array[String] = ["Furniture", "Pintu", "SolarModule", "PowerInverter"]

var _dalam_teleport: bool = false
var _layer_asal: int = 128
var _mask_asal: int = 11

var _sasaran: Dictionary = {}
var _timer_cari: float = 0.0
var _cooldown_serang: float = 0.0
# Kesan raider tersangkut pada dinding (tak bergerak walaupun sepatutnya berjalan).
var _pos_terakhir: Vector2 = Vector2.ZERO
var _masa_tersangkut: float = 0.0

func _ready() -> void:
	super._ready()
	_layer_asal = collision_layer
	_mask_asal = collision_mask
	# Badan belum wujud sehingga animasi teleport habis.
	_dalam_teleport = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	if sprite:
		sprite.visible = false
	# Spawner menetapkan posisi selepas add_child, jadi kesan teleport mesti
	# dimulakan selepas itu (deferred) supaya berlaku di tempat yang betul.
	call_deferred("_mula_teleport")

func _physics_process(delta: float) -> void:
	# Semasa berteleport raider belum wujud pada skrin: jangan bergerak,
	# jangan menembak, dan jangan boleh ditembak.
	if _dalam_teleport:
		return
	super._physics_process(delta)

# Kesan teleport + bunyi dimainkan dahulu, badan disembunyikan.
func _mula_teleport() -> void:
	_dalam_teleport = true
	set_physics_process(false)
	if sprite:
		sprite.visible = false
	collision_layer = 0
	collision_mask = 0

	var pusat: Vector2 = global_position
	_main_kesan(pusat)
	Sfx.mainkan_di("teleport", pusat, -5.0)
	print("Raider: teleport masuk di ", pusat)

	await get_tree().create_timer(masa_teleport).timeout
	if not is_instance_valid(self) or sedang_mati:
		return
	_keluar_dari_teleport()

func _main_kesan(pada: Vector2) -> void:
	var induk := get_parent()
	if induk == null or not is_instance_valid(induk):
		return
	var kesan := KESAN_TELEPORT.new()
	kesan.muncul = true
	induk.add_child(kesan)
	kesan.global_position = pada

# Badan muncul semula dengan kilau singkat, kemudian AI berjalan seperti biasa.
func _keluar_dari_teleport() -> void:
	_dalam_teleport = false
	_pos_terakhir = global_position
	_masa_tersangkut = 0.0
	collision_layer = _layer_asal
	collision_mask = _mask_asal
	# sprite.modulate dikawal oleh animasi HuskLurker setiap frame, jadi
	# kilau muncul cukup dengan menyembunyi/menunjukkan sprite.
	if sprite:
		sprite.visible = true
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		sprite.scale = skala_asas
	set_physics_process(true)
	print("Raider: muncul dan mula bergerak")

# ==========================================================
# SERANGAN PANGKALAN
# Raider menuju pangkalan, kemudian memusnahkan dinding/lantai/pintu dan
# perabot yang paling hampir. Satu serangan = satu sasaran hancur.
# ==========================================================
func _gerak_penyerang(delta: float, player: Node2D, jarak: float, nampak: bool) -> float:
	if _cooldown_serang > 0.0:
		_cooldown_serang -= delta

	# Raider sengaja TIDAK masuk mod chase: jalan biasa sahaja, tak memecut
	# bila nampak player dan tetap berjalan walaupun sedang menembak.
	sedang_kejar = false

	# Masih tembak player kalau dia nampak, macam husk biasa - tetapi satu
	# serangan sahaja setiap kitaran (jangan tembak player + struktur serentak).
	if is_instance_valid(player) and nampak and jarak <= jarak_tembak:
		_tembak_player(player)

	# Tersangkut pada dinding? Raider berhenti di tempat yang sama walaupun
	# sepatutnya berjalan: musnahkan tile dinding terdekat supaya laluan terbuka,
	# jangan duduk diam sambil menembak player dari jauh.
	var gerak_nyata: float = global_position.distance_to(_pos_terakhir)
	_pos_terakhir = global_position
	if gerak_nyata < 0.4:
		_masa_tersangkut += delta
	else:
		_masa_tersangkut = 0.0
	if _masa_tersangkut >= 0.3:
		var sasaran_dinding: Dictionary = _sasaran_terdekat_grid(48.0)
		if not sasaran_dinding.is_empty():
			_sasaran = sasaran_dinding
			_timer_cari = 0.0
			_masa_tersangkut = 0.0

	_timer_cari -= delta
	if _timer_cari <= 0.0:
		_timer_cari = sela_cari_sasaran
		_sasaran = _cari_sasaran()
	elif not _sasaran_sah():
		_sasaran = {}

	# Tiada apa-apa untuk dimusnahkan di sekitar: jalan ke pangkalan.
	var posisi: Vector2 = posisi_pangkalan
	if not _sasaran.is_empty():
		posisi = _sasaran.get("posisi", posisi_pangkalan)

	var jarak_sasaran: float = global_position.distance_to(posisi)
	_hala_ke(posisi, delta)

	# Sasaran sudah dalam jarak tembak: berhenti di tempat dan tembak lendir
	# dari jauh, tak perlu dekat lagi. Berdiri sambil menembak bukan "tersangkut".
	if not _sasaran.is_empty() and jarak_sasaran <= jarak_serang:
		if _cooldown_serang <= 0.0:
			_serang_sasaran()
		_pos_terakhir = global_position
		_masa_tersangkut = 0.0
		return 0.0

	# Tiada sasaran struktur tetapi player dalam jarak tembak: tembak saja
	# dari tempat sekarang.
	if _sasaran.is_empty() and is_instance_valid(player) \
		and global_position.distance_to(player.global_position) <= jarak_tembak:
		_hala_ke(player.global_position, delta)
		return 0.0

	# Tak ada apa nak dimusnahkan: dekati player (sambil menembak dia),
	# jangan duduk diam. Laju macam husk biasa (wander_speed), bukan chase_speed.
	if _sasaran.is_empty() and is_instance_valid(player):
		_hala_ke(player.global_position, delta)
	return wander_speed

# Tile grid (dinding/lantai/pintu) paling hampir dengan raider dalam jejari tertentu.
func _sasaran_terdekat_grid(jarak_maks: float) -> Dictionary:
	var grid := get_tree().get_first_node_in_group("BuildGrid")
	if grid == null or not grid.has_method("sasaran_terdekat"):
		return {}
	return grid.call("sasaran_terdekat", global_position, jarak_maks)

# Pusing badan ke arah sasaran (logik sama seperti _gerak_penyerang asal).
func _hala_ke(posisi: Vector2, delta: float) -> void:
	sedang_kejar = false
	var ke: Vector2 = posisi - global_position
	if ke.length() <= 0.5:
		return
	var arah_sasaran: Vector2 = ke.normalized()
	# Lerp antara arah bertentangan tepat (180 darjah) tidak berpusing.
	if arah.dot(arah_sasaran) < -0.95:
		arah = arah_sasaran
	else:
		arah = arah.lerp(arah_sasaran, 6.0 * delta).normalized()

# Sasaran terdekat: tile grid (lantai/dinding/pintu) atau perabot berhampiran.
func _cari_sasaran() -> Dictionary:
	var terbaik: Dictionary = {}
	var jarak_terbaik: float = jarak_cari_sasaran

	var grid := get_tree().get_first_node_in_group("BuildGrid")
	if grid != null and grid.has_method("sasaran_terdekat"):
		var calon: Dictionary = grid.call("sasaran_terdekat", global_position, jarak_terbaik)
		if not calon.is_empty():
			terbaik = calon
			jarak_terbaik = global_position.distance_to(calon.get("posisi", global_position))

	for kumpulan in KUMPULAN_SASARAN:
		for calon in get_tree().get_nodes_in_group(kumpulan):
			var nod := calon as Node2D
			if nod == null or not is_instance_valid(nod) or nod == self:
				continue
			var jarak: float = global_position.distance_to(nod.global_position)
			if jarak < jarak_terbaik:
				jarak_terbaik = jarak
				terbaik = {"jenis": "nod", "nod": nod, "posisi": nod.global_position}
	return terbaik

func _sasaran_sah() -> bool:
	if _sasaran.is_empty():
		return false
	if str(_sasaran.get("jenis", "")) == "grid":
		var grid := get_tree().get_first_node_in_group("BuildGrid")
		return grid != null and is_instance_valid(grid)
	# Guna Variant: nod yang sudah dibebaskan tidak boleh di-cast.
	var nod: Variant = _sasaran.get("nod")
	return nod != null and is_instance_valid(nod)

# Satu serangan: tembak lendir ke arah struktur. Struktur barulah hancur
# bila lendir itu pecah (kena dinding atau sampai di sasaran).
# Tembak player dengan had serangan yang sama seperti serangan struktur.
func _tembak_player(player: Node2D) -> void:
	if _cooldown_serang > 0.0 or cooldown_lendir > 0.0:
		return
	_tembak_lendir(player)
	if cooldown_lendir > 0.0:
		_cooldown_serang = jeda_serang

func _serang_sasaran() -> void:
	if _sasaran.is_empty():
		return
	_cooldown_serang = jeda_serang
	var sasaran: Dictionary = _sasaran
	_sasaran = {}
	_timer_cari = 0.0

	var posisi: Vector2 = sasaran.get("posisi", global_position)
	var ke: Vector2 = posisi - global_position
	var jarak: float = maxf(1.0, ke.length())

	var lendir: Node = null
	if peluru_lendir != null:
		lendir = peluru_lendir.instantiate()
	if lendir == null:
		# Lendir tak dapat dicipta: hancurkan terus supaya serangan tak tersekat.
		_hancurkan_sasaran(sasaran, null)
		return

	get_tree().current_scene.add_child(lendir)
	if lendir is Node2D:
		(lendir as Node2D).global_position = global_position + ke.normalized() * 10.0
	if lendir.has_method("tembak_struktur"):
		# Lendir hanya tahu "pecah": sasaran yang disimpan di sini ikut hancur.
		var bila_pecah := func(badan: Node) -> void: _hancurkan_sasaran(sasaran, badan)
		lendir.call("tembak_struktur", ke.normalized(), jarak, bila_pecah)
	else:
		_hancurkan_sasaran(sasaran, null)

# Dipanggil lendir semasa pecah: hancurkan struktur yang kena.
func _hancurkan_sasaran(sasaran: Dictionary, badan_kena: Node = null) -> void:
	# Lendir terlanggar dinding grid: musnahkan tile dinding itu sendiri, bukan
	# sasaran jauh di sebaliknya.
	var grid := get_tree().get_first_node_in_group("BuildGrid")
	if badan_kena is Node2D and grid != null and badan_kena.get_parent() == grid:
		var sel: Variant = badan_kena.get_meta("grid_sel", null)
		if sel is Vector2i and grid.has_method("kena_serangan"):
			grid.call("kena_serangan", sel)
			return
		var bahagian: PackedStringArray = str(badan_kena.name).split("_")
		if bahagian.size() == 3 and grid.has_method("kena_serangan"):
			grid.call("kena_serangan", Vector2i(int(bahagian[1]), int(bahagian[2])))
			return

	var jenis: String = str(sasaran.get("jenis", ""))
	if jenis == "grid":
		if grid != null and grid.has_method("kena_serangan"):
			grid.call("kena_serangan", sasaran.get("grid", Vector2i.ZERO))
	else:
		var nod: Variant = sasaran.get("nod")
		if nod != null and is_instance_valid(nod):
			_serang_nod(nod as Node)

# Perabot ada HP (default 2): lendir pertama cuma cedera, lendir kedua baru pecah.
func _serang_nod(nod: Node) -> void:
	var baki: int = int(nod.get_meta("hp_serangan", hp_perabot)) - 1
	if baki <= 0:
		nod.set_meta("hp_serangan", 0)
		print("Raider: musnahkan ", nod.name)
		nod.queue_free()
		return
	nod.set_meta("hp_serangan", baki)
	# Player nampak baki HP perabot sebelum ia pecah; HP maks turut disimpan
	# supaya bar boleh dipulihkan selepas load.
	if nod is Node2D:
		nod.set_meta("hp_sasaran_maks", hp_perabot)
		BAR_HP.papar(nod as Node2D, baki, hp_perabot)
	print("Raider: %s kena lendir, HP tinggal %d/%d" % [nod.name, baki, hp_perabot])
