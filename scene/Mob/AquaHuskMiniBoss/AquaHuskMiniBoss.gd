extends CharacterBody2D

# ==========================================================
# AQUA HUSK MINI BOSS - penjaga TheAquaHusk (starting zone)
#
# Tiga keadaan:
#   DUDUK  - diam di titik spawn, langsung tak tembak lendir
#   KEJAR  - player dekat, kejar dan tembak volley lendir
#   BALIK  - player dah jauh, jalan balik ke titik spawn
#
# Penting: masa MATI dia keluar dari group "enemy"/"enemies"
# supaya dron dan lock-on berhenti sasarkan dia. Bila respawn,
# dia masuk balik group tersebut.
# ==========================================================

enum Keadaan { DUDUK, KEJAR, BALIK }

@export_group("Pengawasan")
@export_flags_2d_physics var layer_penghalang_penglihatan: int = 2  # Layer dinding
@export var jarak_jaga: float = 320.0      # Player dalam jarak ini -> mula kejar
@export var jarak_lepas: float = 380.0     # (1) Jauh dari SARANG -> balik
@export var jarak_lepas_player: float = 520.0  # (2) Player dah jauh dari boss -> balik
@export var masa_ingat_sasaran: float = 2.0   # Ingatan bila pandangan terlindung sementara
@export var jarak_kawasan: float = 620.0   # Player dalam jarak ini dari SARANG -> ambien kawasan AquaHusk

@export_group("Pergerakan")
@export var kelajuan_kejar: float = 78.0
@export var kelajuan_balik: float = 92.0

@export_group("Serangan (masa mengejar sahaja)")
@export var jarak_serang: float = 320.0
@export var cooldown_tembak: float = 2.3
@export var bilangan_peluru: int = 3
@export var serakan_peluru: float = 0.22
@export var kerosakan_lendir: int = 2
@export var telegraf_tembak: float = 0.35
@export var peluru_lendir: PackedScene

@export_group("Kesihatan")
@export var max_hp: int = 14

@export_group("Respawn")
@export var respawn_time: float = 60.0

@export_group("Fasa Marah (HP separuh)")
@export var ambang_marah: float = 0.5
@export var gandaan_laju_marah: float = 1.3
@export var gandaan_cooldown_marah: float = 0.65
@export var tambahan_peluru_marah: int = 2

@export_group("Visual")
@export var warna_biasa: Color = Color(0.62, 0.9, 1.0)
@export var warna_marah: Color = Color(1.0, 0.45, 0.4)

var hp: int = 14
var titik_asal: Vector2 = Vector2.ZERO   # Titik spawn = titik respawn = "rumah"
var keadaan: int = Keadaan.DUDUK
var arah_hadap: Vector2 = Vector2.DOWN
var cooldown_lendir: float = 0.0
var telegraf: float = 0.0
var sedang_marah: bool = false
var sedang_mati: bool = false
var fasa_renang: float = 0.0
var kilat: float = 0.0
var nampak_player: bool = false
var masa_hilang_pandangan: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

var skala_asas: Vector2 = Vector2.ONE

func _ready() -> void:
	_masuk_group_musuh(true)

	if sprite:
		skala_asas = sprite.scale

	call_deferred("_tetapkan_titik_asal")
	_sedia_hidup(true)

func _tetapkan_titik_asal() -> void:
	# Titik spawn = rumah = titik respawn
	titik_asal = global_position
	print("AquaHuskMiniBoss: bertugas di ", titik_asal, " (HP ", max_hp, ")")

# ---------- GROUP ----------
func _masuk_group_musuh(termasuk_enemies: bool) -> void:
	if not is_in_group("enemy"):
		add_to_group("enemy")
	if termasuk_enemies and not is_in_group("enemies"):
		add_to_group("enemies")
	if not is_in_group("miniboss"):
		add_to_group("miniboss")

func _keluar_dari_group_musuh() -> void:
	# Dron sasarkan group "enemy", lock-on & peluru player pula "enemies".
	# Keluarkan diri dari kedua-duanya masa mati.
	remove_from_group("enemy")
	remove_from_group("enemies")

func _physics_process(delta: float) -> void:
	if sedang_mati:
		return

	if cooldown_lendir > 0.0:
		cooldown_lendir -= delta

	var player := _cari_player()
	var jarak: float = 999999.0
	if is_instance_valid(player):
		jarak = global_position.distance_to(player.global_position)

	# Penglihatan: dinding halang = tak nampak
	nampak_player = is_instance_valid(player) and _boleh_nampak(player)
	if nampak_player:
		masa_hilang_pandangan = 0.0
	else:
		masa_hilang_pandangan += delta

	_kemas_kawasan(player)
	_kemas_keadaan(player, jarak)
	_jalankan_gerak(delta, player, jarak)
	_animasi(delta)

# Ambien kawasan: bila player hampiri sarang AquaHusk, ambien angkasa bertukar
# jadi versi perlahan muzik boss. Boss mula mengejar -> muzik boss penuh ambil alih.
func _kemas_kawasan(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	var dalam: bool = titik_asal.distance_to(player.global_position) <= jarak_kawasan
	Sfx.kawasan_bos(dalam)

func _exit_tree() -> void:
	# Jangan tinggalkan ambien kawasan hidup bila scene ditukar.
	Sfx.kawasan_bos(false)
	Sfx.muzik_bos(false)

func _kemas_keadaan(player: Node2D, jarak: float) -> void:
	# Leash dikira dari SARANG, bukan dari player - sebab itu boss tak boleh
	# dipancing jauh: bila dia tersasar melebihi jarak_lepas dari titik_asal,
	# dia WAJIB patah balik walau player ada betul-betul di depan hidungnya.
	var jarak_dari_sarang: float = global_position.distance_to(titik_asal)
	var keadaan_lama: int = keadaan

	match keadaan:
		Keadaan.DUDUK:
			# Bangun bila player masuk kawasan jagaan DAN kelihatan (bukan sebalik dinding)
			if is_instance_valid(player) and jarak <= jarak_jaga and nampak_player:
				keadaan = Keadaan.KEJAR
				masa_hilang_pandangan = 0.0
				print("AquaHuskMiniBoss: player menghampiri, mula mengejar")

		Keadaan.KEJAR:
			# Dua sebab untuk balik - mana-mana satu cukup:
			# (1) boss tersasar jauh dari SARANG
			# (2) player dah jauh dari BOSS (atau hilang pandangan lama)
			if not is_instance_valid(player):
				keadaan = Keadaan.BALIK
				telegraf = 0.0
				print("AquaHuskMiniBoss: hilang sasaran, patah balik ke sarang")
			elif jarak_dari_sarang > jarak_lepas:
				keadaan = Keadaan.BALIK
				telegraf = 0.0
				print("AquaHuskMiniBoss: tersasar ", jarak_dari_sarang, " dari sarang, patah balik")
			elif jarak > jarak_lepas_player:
				keadaan = Keadaan.BALIK
				telegraf = 0.0
				print("AquaHuskMiniBoss: player dah jauh (", jarak, "), patah balik")
			elif masa_hilang_pandangan > masa_ingat_sasaran:
				keadaan = Keadaan.BALIK
				telegraf = 0.0
				print("AquaHuskMiniBoss: pandangan terlindung terlalu lama, patah balik")

		Keadaan.BALIK:
			# Tak ambil kira player langsung masa pulang - sampai dulu,
			# baru boleh aggro semula (elak dia terjuntai depan player terus).
			if global_position.distance_to(titik_asal) <= 8.0:
				keadaan = Keadaan.DUDUK
				masa_hilang_pandangan = 0.0
				_pulihkan_darah()
				print("AquaHuskMiniBoss: kembali bertugas di ", titik_asal)

	# Muzik rancak hanya masa boss betul-betul menyerang.
	if keadaan != keadaan_lama:
		Sfx.muzik_bos(keadaan == Keadaan.KEJAR)

func _jalankan_gerak(delta: float, player: Node2D, jarak: float) -> void:
	var gandaan_laju: float = gandaan_laju_marah if sedang_marah else 1.0
	var arah_gerak: Vector2 = Vector2.ZERO
	var laju: float = 0.0

	if keadaan == Keadaan.KEJAR and is_instance_valid(player):
		arah_hadap = (player.global_position - global_position).normalized()
		# Terus kejar tanpa henti - tembak sambil bergerak, bukan berhenti
		arah_gerak = arah_hadap
		laju = kelajuan_kejar * gandaan_laju

		# Tembak hanya bila player kelihatan - jangan tembus dinding
		if jarak <= jarak_serang and nampak_player:
			_sedia_tembak(delta, player)
		else:
			telegraf = 0.0

	elif keadaan == Keadaan.BALIK:
		var ke_rumah: Vector2 = titik_asal - global_position
		if ke_rumah.length() > 0.5:
			arah_hadap = ke_rumah.normalized()
			arah_gerak = arah_hadap
			laju = kelajuan_balik
		telegraf = 0.0

	else:
		# DUDUK - langsung tak gerak, tak tembak lendir.
		# Hadap player cuma kalau kelihatan (jangan "tengok" menembus dinding).
		telegraf = 0.0
		if is_instance_valid(player) and nampak_player:
			arah_hadap = (player.global_position - global_position).normalized()

	velocity = arah_gerak * laju
	move_and_slide()

	if arah_hadap != Vector2.ZERO:
		rotation = lerp_angle(rotation, arah_hadap.angle() + PI * 0.5, 4.0 * delta)

# ---------- PEMULIHAN ----------
func _pulihkan_darah() -> void:
	# Sampai di sarang -> HP penuh semula, fasa marah direset
	if hp >= max_hp and not sedang_marah:
		return

	hp = max_hp
	sedang_marah = false
	telegraf = 0.0
	cooldown_lendir = 0.0
	print("AquaHuskMiniBoss: pulih sepenuhnya di sarang (HP ", hp, "/", max_hp, ")")

# ---------- PENGLIHATAN ----------
func _boleh_nampak(player: Node2D) -> bool:
	# Ada dinding antara boss dan player -> tak nampak (tak boleh aggro/tembak)
	var dunia := get_world_2d()
	if dunia == null:
		return true

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position,
		layer_penghalang_penglihatan,
		[get_rid()]
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hasil: Dictionary = dunia.direct_space_state.intersect_ray(query)
	return hasil.is_empty()

func _cari_player() -> Node2D:
	var player: Node2D = get_tree().get_first_node_in_group("Player")
	if player == null and get_tree().current_scene:
		player = get_tree().current_scene.find_child("SpaceShip", true, false)
	return player

func _sedia_tembak(delta: float, player: Node2D) -> void:
	if telegraf > 0.0:
		telegraf -= delta
		if telegraf <= 0.0:
			_lepaskan_volley(player)
		return

	if cooldown_lendir <= 0.0:
		telegraf = telegraf_tembak

func _lepaskan_volley(player: Node2D) -> void:
	if peluru_lendir == null or not is_instance_valid(player):
		return

	var jumlah: int = bilangan_peluru + (tambahan_peluru_marah if sedang_marah else 0)
	var asas: Vector2 = (player.global_position - global_position).normalized()
	var mula: float = -serakan_peluru * float(jumlah - 1) * 0.5
	var ibu: Node = get_parent()
	if ibu == null:
		ibu = get_tree().current_scene

	for i in range(jumlah):
		var hala: Vector2 = asas.rotated(mula + serakan_peluru * float(i))
		var lendir := peluru_lendir.instantiate()
		if lendir == null:
			continue

		# LendirBoss.tscn bawa sifat khasnya sendiri (jauh, merah, trail)
		ibu.add_child(lendir)
		if lendir is Node2D:
			lendir.global_position = global_position + hala * 16.0
		if lendir.has_method("tembak"):
			lendir.tembak(hala, kerosakan_lendir)

	cooldown_lendir = cooldown_tembak * (gandaan_cooldown_marah if sedang_marah else 1.0)
	print("AquaHuskMiniBoss: volley ", jumlah, " lendir")

func _animasi(delta: float) -> void:
	fasa_renang += delta * (3.2 + (2.0 if keadaan == Keadaan.KEJAR else 0.0))
	kilat = max(0.0, kilat - delta * 8.0)

	if sprite:
		var denyut: float = sin(fasa_renang) * 0.04
		var tarik: float = 0.18 if telegraf > 0.0 else 0.0
		sprite.scale = skala_asas * Vector2(1.0 + tarik - denyut, 1.0 + tarik + denyut)
		sprite.position = Vector2(0.0, sin(fasa_renang * 0.8) * 2.5)

		var kilau: float = 1.0 + 0.08 * sin(fasa_renang * 1.4) + 2.4 * kilat
		var asas_warna: Color = warna_marah if sedang_marah else warna_biasa
		sprite.modulate = Color(
			asas_warna.r * kilau,
			asas_warna.g * kilau,
			asas_warna.b * kilau,
			sprite.modulate.a
		)

func take_damage(amount: float) -> void:
	if sedang_mati:
		return

	hp -= int(amount)
	kilat = 1.0
	print("AquaHuskMiniBoss: HP ", hp, "/", max_hp)

	if hp <= 0:
		_mati()
		return

	if not sedang_marah and float(hp) <= float(max_hp) * ambang_marah:
		sedang_marah = true
		print("AquaHuskMiniBoss: MARAH! Serangan dipercepatkan")

func _mati() -> void:
	sedang_mati = true
	Sfx.muzik_bos(false)
	Sfx.mainkan_di("letupan", global_position, -4.0, 0.8)
	keadaan = Keadaan.DUDUK
	telegraf = 0.0
	cooldown_lendir = 0.0
	velocity = Vector2.ZERO

	# Dron & lock-on berhenti sasarkan dia dari saat ini
	_keluar_dari_group_musuh()

	# Jangan boleh ditembak lagi
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	print("AquaHuskMiniBoss: tumbang, respawn dalam ", respawn_time, "s")

	if sprite:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "modulate", Color(2.4, 2.4, 2.4, 1.0), 0.12)
		tw.tween_property(sprite, "scale", skala_asas * 1.35, 0.12)
		await tw.finished

		var tw2 := create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(sprite, "modulate:a", 0.0, 0.45)
		tw2.tween_property(sprite, "scale", skala_asas * 0.25, 0.45)
		await tw2.finished
		sprite.visible = false

	await get_tree().create_timer(max(1.0, respawn_time)).timeout
	if not is_inside_tree():
		return

	# Muncul semula di titik asal yang SAMA
	_sedia_hidup(false)

func _sedia_hidup(pertama_kali: bool) -> void:
	Sfx.muzik_bos(false)
	sedang_mati = false
	sedang_marah = false
	keadaan = Keadaan.DUDUK
	hp = max_hp
	telegraf = 0.0
	cooldown_lendir = 0.0
	velocity = Vector2.ZERO
	kilat = 0.0
	nampak_player = false
	masa_hilang_pandangan = 0.0

	if not pertama_kali:
		global_position = titik_asal
		rotation = 0.0

	# Boleh ditembak & disasarkan semula
	_masuk_group_musuh(true)
	set_deferred("collision_layer", 128)
	set_deferred("collision_mask", 3)

	if sprite:
		sprite.visible = true
		sprite.modulate = Color(warna_biasa.r, warna_biasa.g, warna_biasa.b, 1.0)
		sprite.scale = skala_asas

	if not pertama_kali:
		print("AquaHuskMiniBoss: muncul semula di ", global_position)
