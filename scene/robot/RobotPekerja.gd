extends CharacterBody2D

## Robot pekerja perlombongan.
## Dibuat di Fabricator. Selepas itu ia bekerja sendiri tanpa pemain:
## cari meteorit terdekat, terbang ke sana, lombong sampai hancur, cas
## tenaga sendiri bila tenaga rendah, baiki HP (30 HP dalam 3 saat) dan
## lalu pintu tanpa perlu pemain klik pintu itu.

@export_group("Pergerakan")
@export var kelajuan: float = 34.0
@export var julat_lombong: float = 20.0
@export var jarak_pintu: float = 22.0
@export var masa_scan: float = 0.6
# Kalau dinding kedap dalam jarak ini pada keempat-empat arah, robot
# anggap ia terkurung dalam bilik dan cari pintu untuk keluar dulu.
@export var jarak_bilik: float = 100.0

@export_group("Tenaga")
@export var tenaga_maks: float = 100.0
@export var kos_gerak_sesaat: float = 1.4
@export var kos_lombong: float = 2.5
@export var cas_tenang_sesaat: float = 3.0
@export var cas_rehat_sesaat: float = 12.0
@export var ambang_rehat: float = 18.0

@export_group("HP dan Pembaikan")
@export var hp_maks: float = 60.0
@export var pulih_hp_sesaat: float = 10.0   # 30 HP dalam 3 saat
@export var kos_tenaga_baiki: float = 10.0  # tenaga sesaat semasa membaiki
@export var ambang_baiki: float = 25.0      # tenaga minimum sebelum mula baiki
@export var damage_musuh_sesaat: float = 8.0

var tenaga: float = 100.0
var hp: float = 60.0

var _sasaran: Node2D = null
var _pintu: Node2D = null
var _masa_scan_baki: float = 0.0
var _masa_pintu_baki: float = 0.0
var _masa_lombong: float = 0.0
var _masa_larang_pintu: float = 0.0
var _masa_semak_bilik: float = 0.0
var _bilik_terkurung: bool = false
var _menuju_pintu: bool = false
var _sisi_elak: float = 1.0
var _perlu_cas: bool = false
var _sedang_baiki: bool = false
var _sedang_rehat: bool = false
var _sedang_lombong: bool = false

var _musuh_dekat: Array[Node] = []
var _masa_bahaya: float = 0.0

var _masa_semak: float = 0.0
var _pos_semak: Vector2 = Vector2.ZERO
var _baki_elak: float = 0.0
var _arah_elak: Vector2 = Vector2.ZERO

var _kilat_baki: float = 0.0
var _sudah_mati: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	add_to_group("RobotPekerja")
	tenaga = tenaga_maks
	hp = hp_maks
	_pos_semak = global_position
	_sambung_penderia_bahaya()


func _sambung_penderia_bahaya() -> void:
	var penderia := get_node_or_null("PenderiaBahaya") as Area2D
	if penderia == null:
		return
	penderia.body_entered.connect(_on_bahaya_masuk)
	penderia.body_exited.connect(_on_bahaya_keluar)
	penderia.area_entered.connect(_on_bahaya_masuk)
	penderia.area_exited.connect(_on_bahaya_keluar)


func _process(_delta: float) -> void:
	if _sudah_mati:
		return
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _sudah_mati:
		return

	_kemas_bahaya(delta)
	_kemas_kilat(delta)
	_kemas_bilik(delta)
	if _masa_larang_pintu > 0.0:
		_masa_larang_pintu = maxf(0.0, _masa_larang_pintu - delta)

	# Panel solar kecil: cas perlahan sepanjang masa.
	if tenaga < tenaga_maks:
		tenaga = minf(tenaga_maks, tenaga + cas_tenang_sesaat * delta)

	# 1. Cas sendiri bila tenaga rendah, sampai penuh dulu.
	if _perlu_cas:
		_sedang_rehat = true
		_sedang_baiki = false
		_sedang_lombong = false
		_berhenti()
		tenaga = minf(tenaga_maks, tenaga + cas_rehat_sesaat * delta)
		if tenaga >= tenaga_maks:
			_perlu_cas = false
		_kemas_visual()
		return
	if tenaga <= ambang_rehat:
		_perlu_cas = true
		_sedang_rehat = true
		_sedang_baiki = false
		_sedang_lombong = false
		_berhenti()
		_kemas_visual()
		return

	# 2. Baiki HP guna tenaga: 10 HP sesaat = 30 HP dalam 3 saat.
	if hp < hp_maks and tenaga > ambang_baiki:
		_sedang_baiki = true
		_sedang_rehat = false
		_sedang_lombong = false
		_berhenti()
		hp = minf(hp_maks, hp + pulih_hp_sesaat * delta)
		tenaga = maxf(0.0, tenaga - kos_tenaga_baiki * delta)
		_kemas_visual()
		return
	_sedang_baiki = false

	# 3. Kerja: cari dan lombong meteorit.
	_masa_scan_baki -= delta
	if _masa_scan_baki <= 0.0:
		_masa_scan_baki = masa_scan
		_pilih_sasaran()

	if not is_instance_valid(_sasaran):
		_sasaran = null
		_sedang_lombong = false
		_berhenti()
		_kemas_visual()
		return

	if _cuba_lalu_pintu(delta):
		_sedang_lombong = false
		_kemas_visual()
		return

	var jarak := global_position.distance_to(_sasaran.global_position)
	if jarak > julat_lombong:
		_sedang_lombong = false
		_bergerak_ke(_sasaran.global_position, delta)
		_kemas_visual()
		return

	# Sudah dekat: berhenti dan ketuk meteor setiap 1 saat.
	_sedang_lombong = true
	_berhenti()
	_masa_lombong += delta
	if _masa_lombong >= 1.0 and tenaga >= kos_lombong:
		_masa_lombong = 0.0
		tenaga = maxf(0.0, tenaga - kos_lombong)
		_kilat()
		if _sasaran.has_method("take_damage"):
			_sasaran.call("take_damage")
	_kemas_visual()


func _pilih_sasaran() -> void:
	var calon_lihat: Node2D = null
	var jarak_lihat := INF
	var calon_dekat: Node2D = null
	var jarak_dekat := INF
	# Array tanpa jenis: setiap nod diperiksa secara dinamik ("hp" hanya
	# ada pada meteorit, bukan pada semua Node).
	var senarai_musuh: Array = get_tree().get_nodes_in_group("enemies")
	for nod in senarai_musuh:
		if not is_instance_valid(nod) or nod.is_queued_for_deletion():
			continue
		# Hanya meteorit: Area2D yang ada hp dan fungsi take_damage.
		if not (nod is Area2D) or not nod.has_method("take_damage"):
			continue
		if not ("hp" in nod):
			continue
		if int(nod.hp) <= 0:
			continue
		var nod2d := nod as Node2D
		var jarak: float = global_position.distance_squared_to(nod2d.global_position)
		if jarak < jarak_dekat:
			jarak_dekat = jarak
			calon_dekat = nod2d
		# Utamakan meteorit yang boleh dilihat terus (tiada dinding).
		if jarak < jarak_lihat and _ada_jarak_lihat(nod2d.global_position):
			jarak_lihat = jarak
			calon_lihat = nod2d
	# Kalau tiada satu pun kelihatan, simpan sasaran terdekat; logik pintu
	# di bawah akan bawa robot keluar bilik dulu sebelum mengejarnya.
	_sasaran = calon_lihat if calon_lihat != null else calon_dekat


# ==========================================================
# PINTU: robot kesan ia terkurung, keluar ikut pintu, baru cari meteor.
# ==========================================================
# Pintu yang pemain kena klik itu satu-satunya jalan keluar. Robot tidak
# lagi mengejar meteorit yang di belakang dinding: ia periksa dinding di
# sekeliling, cari pintu, lalu keluar dari bilik dahulu.
func _cuba_lalu_pintu(delta: float) -> bool:
	if not _bilik_terkurung:
		return false
	if _masa_larang_pintu > 0.0:
		return false

	if not is_instance_valid(_pintu):
		_masa_pintu_baki -= delta
		if _masa_pintu_baki > 0.0:
			return false
		_masa_pintu_baki = 1.0
		_pintu = _cari_pintu()
		if _pintu == null:
			return false

	if global_position.distance_to(_pintu.global_position) <= jarak_pintu:
		if not _pintu.has_method("lalu_automatik"):
			return false
		_pintu.call("lalu_automatik", self)
		# Jangan terus pusing balik masuk pintu yang sama.
		_masa_larang_pintu = 4.0
		_bilik_terkurung = false
		_masa_semak_bilik = 0.4
		_berhenti()
		return true

	# Betul-betul depan pintu sahaja elak dinding dimatikan, supaya robot
	# boleh sampai ke pusat pintu tanpa terpesong oleh badan pintu itu.
	_menuju_pintu = global_position.distance_to(_pintu.global_position) < 35.0
	_bergerak_ke(_pintu.global_position, delta)
	_menuju_pintu = false
	return true


func _cari_pintu() -> Node2D:
	var terbaik: Node2D = null
	var jarak_terbaik := INF
	var senarai_pintu: Array = get_tree().get_nodes_in_group("Pintu")
	for nod in senarai_pintu:
		if not (nod is Node2D) or not is_instance_valid(nod):
			continue
		var jarak: float = global_position.distance_squared_to((nod as Node2D).global_position)
		if jarak < jarak_terbaik:
			jarak_terbaik = jarak
			terbaik = nod
	return terbaik


# ----------------------------------------------------------
# PENGESANAN BILIK DAN DINDING
# ----------------------------------------------------------
# Terkurung = ada dinding dalam jarak_bilik pada keempat-empat arah
# (kiri, kanan, atas, bawah). Ini menandakan robot ada di dalam bilik
# berpagar yang cuma boleh keluar melalui pintu.
func _kemas_bilik(delta: float) -> void:
	_masa_semak_bilik -= delta
	if _masa_semak_bilik > 0.0:
		return
	_masa_semak_bilik = 0.4
	var arah_uji: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var bilangan_dinding := 0
	for arah in arah_uji:
		if not _sinar_dinding(global_position, arah, jarak_bilik).is_empty():
			bilangan_dinding += 1
	_bilik_terkurung = bilangan_dinding >= 4


func _sinar_dinding(dari: Vector2, arah: Vector2, jarak: float) -> Dictionary:
	var ruang := get_world_2d().direct_space_state
	if ruang == null:
		return {}
	# Mask 2 = layer dinding. Robot sendiri dikecualikan.
	var pertanyaan := PhysicsRayQueryParameters2D.create(dari, dari + arah * jarak, 2)
	var kecuali: Array[RID] = [get_rid()]
	pertanyaan.exclude = kecuali
	pertanyaan.collide_with_areas = false
	pertanyaan.collide_with_bodies = true
	return ruang.intersect_ray(pertanyaan)


# Ada laluan lurus bebas dinding ke titik itu?
func _ada_jarak_lihat(posisi: Vector2) -> bool:
	var arah := posisi - global_position
	if arah.length() < 4.0:
		return true
	return _sinar_dinding(global_position, arah.normalized(), arah.length()).is_empty()


# ==========================================================
# PERGERAKAN
# ==========================================================
func _bergerak_ke(posisi: Vector2, delta: float) -> void:
	var arah := posisi - global_position
	if arah.length() < 2.0:
		_berhenti()
		return
	arah = arah.normalized()
	if _baki_elak > 0.0:
		_baki_elak -= delta
		arah = _arah_elak
	elif not _menuju_pintu:
		# Mengelilingi dinding, bukan merempuh dinding.
		arah = _elak_dinding(arah)
	velocity = arah * kelajuan
	tenaga = maxf(0.0, tenaga - kos_gerak_sesaat * delta)
	move_and_slide()
	_semak_tersangkut(delta, arah)


# Kalau ada dinding di hadapan, pusing ikut permukaan dinding ke arah
# yang masih menghala ke sasaran (wall following ringkas).
func _elak_dinding(arah: Vector2) -> Vector2:
	var hasil := _sinar_dinding(global_position, arah, 26.0)
	if hasil.is_empty():
		return arah
	var normal: Vector2 = hasil.get("normal", Vector2.ZERO)
	if normal == Vector2.ZERO:
		return arah
	# Buang komponen yang menuju ke dinding, kekalkan arah selari.
	var selari := arah - normal * arah.dot(normal)
	if selari.length() > 0.2:
		return (selari.normalized() + normal * 0.35).normalized()
	# Dinding tepat di hadapan: ikut satu sisi dinding secara konsisten.
	var tangen := Vector2(-normal.y, normal.x) * _sisi_elak
	return (tangen + normal * 0.35).normalized()


func _berhenti() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


# Kalau robot tersangkut pada dinding, bergerak ke sisi seketika.
func _semak_tersangkut(delta: float, arah: Vector2) -> void:
	_masa_semak += delta
	if _masa_semak < 0.9:
		return
	if global_position.distance_to(_pos_semak) < 2.0:
		# Tersangkut juga: tukar sisi ikut dinding dan cuba laluan lain.
		_sisi_elak = -_sisi_elak
		_baki_elak = 0.8
		_arah_elak = arah.orthogonal() * _sisi_elak
	_pos_semak = global_position
	_masa_semak = 0.0


# ==========================================================
# HP / BAHAYA
# ==========================================================
func _on_bahaya_masuk(nod: Node2D) -> void:
	if nod == null or not is_instance_valid(nod):
		return
	if not nod.is_in_group("enemy"):
		return
	if not _musuh_dekat.has(nod):
		_musuh_dekat.append(nod)


func _on_bahaya_keluar(nod: Node2D) -> void:
	_musuh_dekat.erase(nod)


func _kemas_bahaya(delta: float) -> void:
	_masa_bahaya += delta
	if _masa_bahaya < 1.0:
		return
	_masa_bahaya = 0.0
	for i in range(_musuh_dekat.size() - 1, -1, -1):
		var nod = _musuh_dekat[i]
		if not is_instance_valid(nod) or nod.is_queued_for_deletion():
			_musuh_dekat.remove_at(i)
	if not _musuh_dekat.is_empty():
		take_damage(damage_musuh_sesaat)


func take_damage(amount: float) -> void:
	if _sudah_mati or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_kilat()
	Sfx.mainkan("lombong", -9.0, 0.8)
	if hp <= 0.0:
		_mati()


func _mati() -> void:
	if _sudah_mati:
		return
	_sudah_mati = true
	velocity = Vector2.ZERO
	_sedang_lombong = false
	_sedang_baiki = false
	_sedang_rehat = false
	set_physics_process(false)
	queue_redraw()
	Sfx.mainkan("pecah", -6.0)

	var induk := get_parent()
	if induk != null:
		var bunga := CPUParticles2D.new()
		bunga.amount = 14
		bunga.lifetime = 0.45
		bunga.one_shot = true
		bunga.explosiveness = 1.0
		bunga.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		bunga.emission_sphere_radius = 8.0
		bunga.direction = Vector2(0, -1)
		bunga.spread = 180.0
		bunga.gravity = Vector2.ZERO
		bunga.initial_velocity_min = 30.0
		bunga.initial_velocity_max = 70.0
		bunga.scale_amount_min = 0.3
		bunga.scale_amount_max = 0.8
		bunga.color = Color(0.55, 1.0, 0.65)
		induk.add_child(bunga)
		bunga.global_position = global_position
		bunga.emitting = true
		bunga.finished.connect(bunga.queue_free)

	# Buang robot dari pokok dahulu supaya auto-save tidak menyimpannya lagi.
	var simpan = get_node_or_null("/root/SaveManager")
	if induk != null:
		induk.remove_child(self)
	if simpan != null:
		simpan.save_game()
	queue_free()


# ==========================================================
# PAPARAN
# ==========================================================
func _kemas_kilat(delta: float) -> void:
	if _kilat_baki <= 0.0:
		return
	_kilat_baki -= delta
	if _kilat_baki <= 0.0:
		_kilat_baki = 0.0
		_kemas_visual()


func _kilat() -> void:
	_kilat_baki = 0.08
	if sprite:
		sprite.modulate = Color(2.4, 2.4, 2.4)


func _kemas_visual() -> void:
	if sprite == null or _kilat_baki > 0.0:
		return
	if _sedang_baiki:
		sprite.modulate = Color(0.55, 1.0, 0.6)
	elif _sedang_rehat:
		sprite.modulate = Color(0.45, 0.85, 1.0)
	elif _sedang_lombong:
		sprite.modulate = Color(1.0, 0.82, 0.35)
	else:
		sprite.modulate = Color.WHITE


# Bar HP (hijau) dan tenaga (biru) di atas robot.
func _draw() -> void:
	var lebar := 14.0
	var tinggi := 1.8
	var asas_y := -13.0

	draw_rect(Rect2(Vector2(-lebar * 0.5, asas_y), Vector2(lebar, tinggi)), Color(0.0, 0.0, 0.0, 0.7))
	var nisbah_hp := clampf(hp / maxf(1.0, hp_maks), 0.0, 1.0)
	if nisbah_hp > 0.0:
		draw_rect(
			Rect2(Vector2(-lebar * 0.5 + 0.5, asas_y + 0.5), Vector2((lebar - 1.0) * nisbah_hp, tinggi - 1.0)),
			Color(0.35, 1.0, 0.45)
		)

	var asas_tenaga := asas_y + tinggi + 1.0
	draw_rect(Rect2(Vector2(-lebar * 0.5, asas_tenaga), Vector2(lebar, tinggi)), Color(0.0, 0.0, 0.0, 0.7))
	var nisbah_tenaga := clampf(tenaga / maxf(1.0, tenaga_maks), 0.0, 1.0)
	if nisbah_tenaga > 0.0:
		draw_rect(
			Rect2(Vector2(-lebar * 0.5 + 0.5, asas_tenaga + 0.5), Vector2((lebar - 1.0) * nisbah_tenaga, tinggi - 1.0)),
			Color(0.4, 0.8, 1.0)
		)
