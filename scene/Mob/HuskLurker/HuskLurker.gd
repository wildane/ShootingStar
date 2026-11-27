extends CharacterBody2D

# ==========================================================
# HUSK LURKER - binatang gua TheAquaHusk
# Merayau perlahan, kejar player bila nampak, tembak lendir dari jauh, lepas tu balik sarang.
# ==========================================================

@export_group("Pergerakan")
@export var wander_speed: float = 28.0
@export var chase_speed: float = 95.0
@export var home_speed: float = 60.0
@export var wander_change_time: float = 2.5

@export_group("AI & Serangan Lendir")
@export var detection_radius: float = 220.0
@export var jarak_berhenti: float = 80.0       # Berhenti dekat-dekat player, tak sentuh
@export var jarak_tembak: float = 150.0        # Lendir jarak dekat, jadi kena dekat dulu
@export var cooldown_tembak: float = 1.6
@export var kerosakan_lendir: int = 1
@export var peluru_lendir: PackedScene

@export_group("Kesihatan & Sempadan")
@export var max_hp: int = 10
@export var max_radius: float = 520.0
@export var home_arrival_radius: float = 40.0

@export_group("Serangan Balas Pangkalan")
# true bila husk ini dihantar sistem serangan balas untuk menyerang pangkalan
# pemain. Ia abaikan sarang/zon dungeon dan terus menuju pangkalan.
@export var mod_penyerang: bool = false
@export var posisi_pangkalan: Vector2 = Vector2(141.0, 228.0)

@export_group("Zon Kurungan (Dungeon)")
# Kotak kawasan dungeon dalam koordinat dunia. Husk Lurker TIDAK boleh keluar dari sini.
@export var zona_batas: Rect2 = Rect2(-470, -1530, 880, 1460)
@export var jarak_amaran_sempadan: float = 40.0

@export_group("Pintu Masuk Dungeon")
# Posisi pintu masuk dalam koordinat dunia. Bila Husk Lurker dekat sini, ia patah balik.
@export var pintu_masuk: Vector2 = Vector2(-40, -140)
@export var jarak_pintu: float = 110.0

@export_group("Penglihatan (Mata)")
# Layer yang menyekat penglihatan (2 = wall). Player di sebalik layer ini tidak nampak.
@export_flags_2d_physics var layer_penghalang_penglihatan: int = 2
@export var masa_hilang_pandangan: float = 0.5

@export_group("Visual")
@export var chase_color: Color = Color(1.0, 0.45, 0.35)

var hp: int = 3
var rumah: Vector2 = Vector2.ZERO
var arah: Vector2 = Vector2.RIGHT
var timer_rawak: float = 0.0
var cooldown_lendir: float = 0.0
var sedang_mati: bool = false
var sedang_balik: bool = false
var sedang_kejar: bool = false
var timer_hilang_pandangan: float = 0.0

# Tembus dinding semasa balik
var mask_asal: int = 3
var sedang_tembus: bool = false

# Pergerakan licin (anti-tersentak)
var arah_sasaran: Vector2 = Vector2.RIGHT
var kelajuan_semasa: float = 0.0
var berhenti_menembak: bool = false

# Animasi prosedur
var skala_asas: Vector2 = Vector2.ONE
var warna_semasa: Color = Color.WHITE
var denyut_fasa: float = 0.0
var lendir_fasa: float = 0.0
var kilat: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	hp = max_hp
	mask_asal = collision_mask
	# Gabung dalam kedua-dua group supaya kena tembak bullet player DAN dron
	if not is_in_group("enemy"):
		add_to_group("enemy")
	if not is_in_group("enemies"):
		add_to_group("enemies")
	skala_asas = sprite.scale if sprite else Vector2.ONE
	call_deferred("_tetapkan_rumah")
	pilih_arah_rawak()
	print("HuskLurker: muncul di ", global_position)

func _tetapkan_rumah() -> void:
	rumah = global_position

func _physics_process(delta: float) -> void:
	if sedang_mati:
		return

	if cooldown_lendir > 0.0:
		cooldown_lendir -= delta

	var player: Node2D = get_tree().get_first_node_in_group("Player")
	if player == null and get_tree().current_scene:
		player = get_tree().current_scene.find_child("SpaceShip", true, false)

	var jarak: float = 999999.0
	if is_instance_valid(player):
		jarak = global_position.distance_to(player.global_position)

	var jarak_sarang: float = global_position.distance_to(rumah)

	# --- STATE ---
	# Keluar dari kotak dungeon? Patah balik serta-merta.
	var luar_zona: bool = not zona_batas.has_point(global_position)
	var dekat_sempadan: bool = _dekat_sempadan()
	# Dah dekat pintu masuk? Patah balik awal, jangan sampai keluar dungeon.
	var dekat_pintu: bool = global_position.distance_to(pintu_masuk) <= jarak_pintu

	# Penyerang pangkalan tidak terikat pada sarang atau zon dungeon.
	if not mod_penyerang and (luar_zona or dekat_sempadan or dekat_pintu or jarak_sarang > max_radius):
		sedang_balik = true
		sedang_kejar = false

	if sedang_balik and jarak_sarang < home_arrival_radius:
		# Jangan normal semula kalau badan masih bertindih dengan dinding
		if _dalam_dinding():
			rumah = _cari_titik_selamat(global_position)
		else:
			sedang_balik = false
			pilih_arah_rawak()

	# Kalau tersangkut dalam dinding (sebab apa pun), keluar dulu sebelum normal
	if not mod_penyerang and not sedang_balik and _dalam_dinding():
		sedang_balik = true
		rumah = _cari_titik_selamat(global_position)

	# Tembus semua benda semasa balik, normal semula bila betul-betul selamat
	_set_tembus(sedang_balik)

	# --- MATA: hanya nampak player kalau tiada dinding menyekat ---
	var nampak_player: bool = false
	if is_instance_valid(player) and jarak <= detection_radius:
		nampak_player = _boleh_nampak(player)

	if nampak_player:
		timer_hilang_pandangan = 0.0
	else:
		timer_hilang_pandangan += delta

	var masih_ingat_player: bool = timer_hilang_pandangan <= masa_hilang_pandangan

	if not sedang_balik and not luar_zona:
		sedang_kejar = nampak_player or (is_instance_valid(player) and masih_ingat_player and jarak <= detection_radius)
	else:
		sedang_kejar = false

	var kelajuan_sasaran: float = wander_speed

	if mod_penyerang:
		kelajuan_sasaran = _gerak_penyerang(delta, player, jarak, nampak_player)
	elif sedang_kejar and is_instance_valid(player):
		var arah_ke_player: Vector2 = (player.global_position - global_position).normalized()
		arah = arah.lerp(arah_ke_player, 7.0 * delta).normalized()

		# Histerisis: berhenti bila dekat, mula gerak balik hanya bila player jauh sikit.
		# Ini elak ia berhenti-bergerak-berhenti setiap frame.
		if jarak <= jarak_berhenti:
			berhenti_menembak = true
		elif jarak >= jarak_berhenti + 45.0:
			berhenti_menembak = false
		kelajuan_sasaran = 0.0 if berhenti_menembak else chase_speed

		if nampak_player and jarak <= jarak_tembak:
			_tembak_lendir(player)
	elif sedang_balik:
		kelajuan_sasaran = home_speed
		arah = arah.lerp((rumah - global_position).normalized(), 5.0 * delta).normalized()
	else:
		timer_rawak += delta
		if timer_rawak >= wander_change_time:
			pilih_arah_rawak()
		# Belok beransur, bukan pusing serta-merta
		arah = arah.lerp(arah_sasaran, 2.5 * delta).normalized()

	# Pecutan / nyahpecutan licin
	kelajuan_semasa = lerp(kelajuan_semasa, kelajuan_sasaran, 4.0 * delta)
	if kelajuan_semasa < 0.6:
		kelajuan_semasa = 0.0

	# --- ANIMASI: badan meriang masa gerak, regangan bila tembak, kilau bila kena tembak ---
	denyut_fasa += delta * (5.0 + kelajuan_semasa * 0.08)
	lendir_fasa = max(0.0, lendir_fasa - delta * 4.0)
	kilat = max(0.0, kilat - delta * 8.0)

	if sprite:
		var amplitud: float = 0.10 if kelajuan_semasa > 5.0 else 0.04
		var denyut: float = sin(denyut_fasa) * amplitud
		var regang_x: float = 1.0 + 0.30 * lendir_fasa
		var regang_y: float = 1.0 - 0.22 * lendir_fasa
		sprite.scale = skala_asas * Vector2(regang_x * (1.0 - denyut), regang_y * (1.0 + denyut))
		sprite.position = Vector2(0.0, sin(denyut_fasa * 2.0) * 1.5)
		sprite.rotation = sin(denyut_fasa * 0.5) * 0.12

		warna_semasa = warna_semasa.lerp(chase_color if sedang_kejar else Color.WHITE, 6.0 * delta)
		var kilau: float = 1.0 + 0.10 * sin(denyut_fasa * 1.5) + 2.6 * kilat
		sprite.modulate = Color(
			warna_semasa.r * kilau,
			warna_semasa.g * kilau,
			warna_semasa.b * kilau,
			1.0
		)

	# --- FIZIK ---
	velocity = arah * kelajuan_semasa
	move_and_slide()

	if arah != Vector2.ZERO and kelajuan_semasa > 0.5:
		rotation = lerp_angle(rotation, arah.angle(), 6.0 * delta)

# ---------- PENYERANG PANGKALAN ----------
# Bergerak menuju pangkalan pemain. Bila player kelihatan, tukar sasaran
# kepadanya supaya serangan terasa hidup, bukan sekadar berbaris di pangkalan.
func _gerak_penyerang(delta: float, player: Node2D, jarak: float, nampak: bool) -> float:
	sedang_kejar = true

	var sasaran: Vector2 = posisi_pangkalan
	var dekat_sasaran: float = global_position.distance_to(posisi_pangkalan)

	if is_instance_valid(player) and nampak and jarak <= detection_radius:
		sasaran = player.global_position
		dekat_sasaran = jarak
		if jarak <= jarak_tembak:
			_tembak_lendir(player)

	var ke_sasaran: Vector2 = sasaran - global_position
	if ke_sasaran.length() > 0.5:
		var arah_sasaran: Vector2 = ke_sasaran.normalized()
		# lerp antara arah bertentangan tepat (180 darjah) tidak berpusing;
		# pusing terus bila sudutnya terlalu lebar.
		if arah.dot(arah_sasaran) < -0.95:
			arah = arah_sasaran
		else:
			arah = arah.lerp(arah_sasaran, 6.0 * delta).normalized()

	if dekat_sasaran <= 26.0:
		return 0.0
	return chase_speed

func _boleh_nampak(player: Node2D) -> bool:
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

func _dekat_sempadan() -> bool:
	var margin: float = jarak_amaran_sempadan
	return (
		global_position.x - zona_batas.position.x < margin
		or zona_batas.end.x - global_position.x < margin
		or global_position.y - zona_batas.position.y < margin
		or zona_batas.end.y - global_position.y < margin
	)

func _set_tembus(aktif: bool) -> void:
	if aktif == sedang_tembus:
		return
	sedang_tembus = aktif
	collision_mask = 0 if aktif else mask_asal

func _buat_query_dinding(pos: Vector2) -> PhysicsShapeQueryParameters2D:
	var bentuk := CircleShape2D.new()
	bentuk.radius = 8.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = bentuk
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 2  # Layer dinding
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return query

func _dalam_dinding() -> bool:
	var dunia := get_world_2d()
	if dunia == null:
		return false
	var query := _buat_query_dinding(global_position)
	return not dunia.direct_space_state.intersect_shape(query, 1).is_empty()

func _cari_titik_selamat(dari: Vector2) -> Vector2:
	# Cari titik terdekat yang tidak bertindih dengan dinding
	var dunia := get_world_2d()
	if dunia == null:
		return dari
	var query := _buat_query_dinding(dari)
	for jarak in range(10, 241, 10):
		for i in range(16):
			var calon: Vector2 = dari + Vector2.RIGHT.rotated(TAU * float(i) / 16.0) * float(jarak)
			query.transform = Transform2D(0.0, calon)
			if dunia.direct_space_state.intersect_shape(query, 1).is_empty():
				return calon
	return dari

func pilih_arah_rawak() -> void:
	timer_rawak = 0.0
	arah_sasaran = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

func _tembak_lendir(player: Node2D) -> void:
	if cooldown_lendir > 0.0 or not is_instance_valid(player) or peluru_lendir == null:
		return

	cooldown_lendir = cooldown_tembak
	lendir_fasa = 1.0

	var lendir := peluru_lendir.instantiate()
	if lendir == null:
		return

	var hala: Vector2 = (player.global_position - global_position).normalized()
	# Sedikit serakan supaya tak 100% tepat setiap kali
	hala = hala.rotated(randf_range(-0.12, 0.12))

	get_tree().current_scene.add_child(lendir)
	if lendir is Node2D:
		lendir.global_position = global_position + hala * 12.0
	if lendir.has_method("tembak"):
		lendir.tembak(hala, kerosakan_lendir)

	print("HuskLurker: tembak lendir ke player")

# Dipanggil oleh bullet player / dron
func take_damage(amount: float) -> void:
	if sedang_mati:
		return
	hp -= int(amount)
	print("HuskLurker: HP ", hp, "/", max_hp)

	if hp <= 0:
		_mati()
	else:
		kilat = 1.0

func _mati() -> void:
	sedang_mati = true
	Sfx.mainkan_di("letupan", global_position, -8.0)

	# Setiap husk yang tumbang di kawasan TheAquaHusk menambah seorang
	# penyerang untuk serangan balas ke pangkalan pemain. Penyerang yang
	# dihantar oleh sistem tidak dikira semula.
	if not mod_penyerang:
		# Kiraan disimpan pada stor static, jadi menu threat tetap berubah
		# walaupun autoload SeranganBalas belum siap.
		StorThreat.daftar_bunuh()
		print("HuskLurker: lapor bunuh, jumlah husk=", StorThreat.bunuh)
		var serangan := get_node_or_null("/root/SeranganBalas")
		if serangan != null and serangan.has_method("daftar_bunuh_husk"):
			serangan.daftar_bunuh_husk(global_position)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	velocity = Vector2.ZERO
	print("HuskLurker: musnah")

	# Drop 1 Husk Slime (100% chance)
	var drop := get_node_or_null("DropComponent")
	if drop != null and drop.has_method("trigger_drop"):
		drop.trigger_drop()

	if sprite:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.45)
		tw.tween_property(sprite, "scale", Vector2(0.4, 0.4), 0.45)
	await get_tree().create_timer(0.45).timeout
	queue_free()
