extends CharacterBody2D

const SkripPeta := preload("res://scene/level_3/navigation/PetaNavigasi.gd")
const SkripReka := preload("res://scene/robot/RekaRobot.gd")
# Saiz lukisan badan robot (pose terbang mendatar, ~38 x 17 unit).
const SKALA_BADAN: float = 0.5

## Robot pekerja perlombongan.
## Dibuat di Fabricator. Selepas itu ia bekerja sendiri tanpa pemain:
## cari meteorit terdekat, terbang ke sana, lombong sampai hancur, cas
## tenaga sendiri bila tenaga rendah, baiki HP (30 HP dalam 3 saat) dan
## lalu pintu tanpa perlu pemain klik pintu itu.

@export_group("Pergerakan")
@export var kelajuan: float = 34.0
# Meteorit berjejari ~26 unit dan robot sendiri ~5 unit, jadi robot tidak
# boleh mendekat lebih daripada ~31 unit (collision). Julat ini mesti lebih
# besar daripada jarak berdiri, kalau tidak robot akan terus menolak meteor.
@export var julat_lombong: float = 40.0
# Jarak berdiri semasa melombong: badan robot berhenti di luar permukaan
# meteorit, hanya hujung gerudi yang masuk sedikit ke dalam batu.
@export var jarak_berdiri: float = 34.0
@export var jarak_pintu: float = 30.0
@export var masa_scan: float = 0.6
# Kalau dinding kedap dalam jarak ini pada keempat-empat arah, robot
# anggap ia terkurung dalam bilik dan cari pintu untuk keluar dulu.
@export var jarak_bilik: float = 100.0

@export_group("Tenaga")
@export var tenaga_maks: float = 100.0
# Terbang/berjalan tidak memakai tenaga: hanya melombong dan membaiki HP.
@export var kos_lombong: float = 5.0   # 5 ketukan = 25 tenaga untuk satu meteorit
@export var ambang_rehat: float = 18.0
# Robot balik ke base mencari Charging Station selepas melombong bilangan
# meteorit ini, cas sampai penuh, baru keluar semula mencari meteorit.
@export var meteor_sebelum_cas: int = 3
@export var jarak_cas: float = 26.0
@export var kadar_cas_stesen: float = 25.0

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
# Kiraan meteorit yang sudah dihancurkan semenjak cas penuh terakhir.
var _kira_meteor: int = 0
var _sasaran_dilombong: bool = false
# Stesen cas terdekat (group "StesenCas") dan titik base asal robot.
var _stesen_cas: Node2D = null
var _masa_stesen_baki: float = 0.0
var _pos_base: Vector2 = Vector2.ZERO
# Laluan yang dikira oleh sistem navigasi (grid + pintu).
var _laluan: Array = []
var _laluan_indeks: int = 0
var _laluan_destinasi: Vector2 = Vector2(INF, INF)
var _masa_laluan_baki: float = 0.0
var _peta = null
var _masa_peta: float = 0.0
var _masa_lombong: float = 0.0
var _masa_larang_pintu: float = 0.0
# Pintu terakhir yang baru dilalui: jangan teleport melalui pintu yang sama
# berulang kali dalam tempoh larangan.
var _pintu_terakhir: Node2D = null
var _masa_semak_bilik: float = 0.0
var _bilik_terkurung: bool = false
var _menuju_pintu: bool = false
var _perlu_pintasan: bool = false
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
# Jam animasi ringkas (terbang / melombong / cas).
var _masa_anim: float = 0.0
# Arah badan robot (radian): 0 = kepala ke atas, PI = kepala ke bawah.
# Badan berpusing ikut arah gerakan, jadi robot menghadap arah ia terbang.
var _arah_badan: float = 0.0
var _sudah_mati: bool = false

# Warna teras robot: biasa / melombong / cas / baiki.
var _warna_aksen: Color = SkripReka.AKSEN


func _ready() -> void:
	add_to_group("RobotPekerja")
	tenaga = tenaga_maks
	hp = hp_maks
	_pos_semak = global_position
	_pos_base = global_position
	_sambung_penderia_bahaya()


func _sambung_penderia_bahaya() -> void:
	var penderia := get_node_or_null("PenderiaBahaya") as Area2D
	if penderia == null:
		return
	penderia.body_entered.connect(_on_bahaya_masuk)
	penderia.body_exited.connect(_on_bahaya_keluar)
	penderia.area_entered.connect(_on_bahaya_masuk)
	penderia.area_exited.connect(_on_bahaya_keluar)


# Pusing badan perlahan-lahan ke arah gerakan semasa.
func _kemas_arah(delta: float) -> void:
	if velocity.length() < 1.0:
		return
	# Pose reka bentuk menghala ke +x, jadi sudut badan = sudut vektor laju:
	#   kanan  -> 0, bawah -> +PI/2, kiri -> PI, atas -> -PI/2
	var sasaran := atan2(velocity.y, velocity.x)
	_arah_badan = lerp_angle(_arah_badan, sasaran, minf(1.0, delta * 7.0))


func _process(_delta: float) -> void:
	if _sudah_mati:
		return
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _sudah_mati:
		return

	_kemas_bahaya(delta)
	_kemas_kilat(delta)
	_masa_anim += delta
	_kemas_arah(delta)
	_kemas_bilik(delta)
	if _masa_larang_pintu > 0.0:
		_masa_larang_pintu = maxf(0.0, _masa_larang_pintu - delta)
	if _masa_peta > 0.0:
		_masa_peta = maxf(0.0, _masa_peta - delta)
	if _masa_laluan_baki > 0.0:
		_masa_laluan_baki = maxf(0.0, _masa_laluan_baki - delta)

	# Tiada cas pasif: tenaga robot hanya pulih di Charging Station.

	# 1. Kuota meteorit penuh atau tenaga rendah: balik ke base dulu,
	#    cari Charging Station dan cas sampai penuh.
	if _perlu_cas:
		_kemas_cas(delta)
		_kemas_visual()
		return
	if tenaga <= ambang_rehat:
		_perlu_cas = true
		_kemas_cas(delta)
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

	if not is_instance_valid(_sasaran) or _sasaran.is_queued_for_deletion():
		_sasaran = null
		_sedang_lombong = false
		# Meteorit yang sedang dilombong sudah hancur: kira satu.
		if _sasaran_dilombong:
			_sasaran_dilombong = false
			_kira_meteor += 1
			if _kira_meteor >= meteor_sebelum_cas:
				_perlu_cas = true
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
		# Menuju titik berdiri, bukan pusat meteorit, supaya robot tidak
		# terbang menembusi meteor itu.
		var titik_hampiri := _titik_hampiri(_sasaran.global_position)
		# Meteor di sebalik dinding: ikut laluan yang dikira sistem navigasi.
		if not _ada_jarak_lihat(_sasaran.global_position) and _minta_laluan(titik_hampiri):
			if _ikut_laluan(delta):
				_kemas_visual()
				return
		_bergerak_ke(titik_hampiri, delta)
		_kemas_visual()
		return

	# Sudah dekat: berhenti pada jarak berdiri dan ketuk meteor setiap 1 saat.
	_sedang_lombong = true
	_sasaran_dilombong = true
	if jarak < jarak_berdiri:
		# Terlalu dekat (laluan lalu atas meteorit): undur sedikit dulu.
		var undur := global_position - _sasaran.global_position
		if undur.length() > 0.5:
			velocity = undur.normalized() * kelajuan * 0.7
			move_and_slide()
		else:
			_berhenti()
	else:
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
	# Terkurung dalam bilik, atau destinasi (base/stesen) terhalang dinding.
	if not _bilik_terkurung and not _perlu_pintasan:
		return false
	# Teleport pintu hanya dibenarkan semasa robot benar-benar mengikut
	# laluan navigasi. Tanpa semakan ini, robot yang cuma terbang biasa
	# (contohnya pulang ke stesen cas) akan teleport masuk dan keluar pintu
	# berulang-ulang kerana _perlu_pintasan dikira semula setiap frame.
	if not _dalam_mod_laluan():
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
		_pintu_terakhir = _pintu
		_masa_larang_pintu = 4.0
		_bilik_terkurung = false
		_perlu_pintasan = false
		_masa_semak_bilik = 0.4
		_berhenti()
		return true

	# Betul-betul depan pintu sahaja elak dinding dimatikan, supaya robot
	# boleh sampai ke pusat pintu tanpa terpesong oleh badan pintu itu.
	_menuju_pintu = global_position.distance_to(_pintu.global_position) < 35.0
	_bergerak_ke(_pintu.global_position, delta)
	_menuju_pintu = false
	return true


# Robot sedang mengikut laluan yang dikira sistem navigasi?
func _dalam_mod_laluan() -> bool:
	return not _laluan.is_empty() and _laluan_indeks < _laluan.size()


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


# ==========================================================
# CAS DI BASE: robot balik ke Charging Station (atau titik base) dan
# tunggu sampai tenaga penuh sebelum bekerja semula.
# ==========================================================
func _kemas_cas(delta: float) -> void:
	_sedang_rehat = true
	_sedang_baiki = false
	_sedang_lombong = false
	_sasaran = null
	_sasaran_dilombong = false
	_perlu_pintasan = false

	if not is_instance_valid(_stesen_cas) or _stesen_cas.is_queued_for_deletion():
		_stesen_cas = null
		_masa_stesen_baki -= delta
		if _masa_stesen_baki <= 0.0:
			_masa_stesen_baki = 0.6
			_stesen_cas = _cari_stesen_cas()

	var titik_cas: Vector2 = _pos_base
	if is_instance_valid(_stesen_cas):
		titik_cas = _stesen_cas.global_position

	# 1. Laluan penuh (termasuk pintu) dikira oleh sistem navigasi.
	if _minta_laluan(titik_cas):
		if _ikut_laluan(delta):
			return

	# 2. Sandaran: kalau grid tiada laluan, guna logik pintu lama.
	_perlu_pintasan = global_position.distance_to(titik_cas) > jarak_cas and not _ada_jarak_lihat(titik_cas)
	if _cuba_lalu_pintu(delta):
		return

	if global_position.distance_to(titik_cas) > jarak_cas:
		_bergerak_ke(titik_cas, delta)
		return

	# Sudah di stesen: cas sampai penuh. Hanya Charging Station yang
	# berkuasa memberi tenaga - tiada cas pasif di tempat lain.
	_berhenti()
	var kadar := 0.0
	if is_instance_valid(_stesen_cas):
		var stesen_berkuasa: bool = not ("has_power" in _stesen_cas) or bool(_stesen_cas.has_power)
		if stesen_berkuasa:
			kadar = kadar_cas_stesen
	tenaga = minf(tenaga_maks, tenaga + kadar * delta)
	if tenaga >= tenaga_maks:
		_perlu_cas = false
		_kira_meteor = 0
		_sedang_rehat = false
		_perlu_pintasan = false
		_masa_scan_baki = 0.0
		_bersih_laluan()


func _cari_stesen_cas() -> Node2D:
	var terbaik: Node2D = null
	var jarak_terbaik := INF
	var senarai: Array = get_tree().get_nodes_in_group("StesenCas")
	for nod in senarai:
		if not (nod is Node2D) or not is_instance_valid(nod) or nod.is_queued_for_deletion():
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
# LALUAN (dikira oleh sistem navigasi)
# ==========================================================
# Minta laluan penuh dari kedudukan sekarang ke destinasi. Sistem akan
# imbas kawasan, kira jalan terpendek, dan sertakan pintu sebagai pautan.
func _minta_laluan(ke: Vector2) -> bool:
	var destinasi_sama: bool = _laluan_destinasi.distance_to(ke) < 12.0
	if destinasi_sama:
		if _laluan.size() > 0 and _laluan_indeks < _laluan.size():
			return true
		# Jangan kira semula setiap frame; tunggu kitaran seterusnya.
		if _masa_laluan_baki > 0.0:
			return false
	elif _masa_laluan_baki > 0.0 and _laluan.size() > 0 and _laluan_indeks < _laluan.size() and _laluan_destinasi.distance_to(ke) < 40.0:
		return true

	var ruang := get_world_2d().direct_space_state
	if ruang == null:
		return false
	var senarai_pintu: Array = get_tree().get_nodes_in_group("Pintu")
	var kawasan := _kawasan_laluan(ke, senarai_pintu)
	if _peta == null or _masa_peta <= 0.0 or not _peta.kotak.encloses(kawasan):
		_peta = SkripPeta.new()
		_peta.bina(ruang, kawasan.grow(8.0), [get_rid()])
		_masa_peta = 3.0

	var laluan_baru: Array = _peta.cari_laluan(global_position, ke, senarai_pintu)
	if laluan_baru.is_empty():
		# Cuba semula dengan kawasan lebih luas sebelum menyerah.
		_peta = SkripPeta.new()
		_peta.bina(ruang, kawasan.grow(64.0), [get_rid()])
		_masa_peta = 3.0
		laluan_baru = _peta.cari_laluan(global_position, ke, senarai_pintu)

	_masa_laluan_baki = 0.5
	_laluan_destinasi = ke
	_laluan_indeks = 0
	if laluan_baru.is_empty():
		_laluan = []
		return false
	_laluan = laluan_baru
	return true


# Ikut laluan yang sudah dikira. Titik yang ada "pintu" bermaksud robot
# kena panggil lalu_automatik() pada pintu itu.
func _ikut_laluan(delta: float) -> bool:
	while _laluan_indeks < _laluan.size():
		var langkah: Dictionary = _laluan[_laluan_indeks]
		var pintu = langkah.get("pintu")
		if pintu != null and is_instance_valid(pintu):
			if not pintu.has_method("lalu_automatik"):
				_laluan_indeks += 1
				continue
			# Langkah pintu: teleport sebaik robot sampai di titik sisi pintu
			# itu. Jarak ke pusat pintu tak boleh dijadikan ukuran tunggal
			# kerana dinding tebal menghalang robot menghampirinya.
			var pos_pintu: Vector2 = langkah["pos"]
			var dekat_titik := global_position.distance_to(pos_pintu) <= 10.0
			var dekat_pintu := global_position.distance_to(pintu.global_position) <= jarak_pintu
			# Baru sahaja melalui pintu ini: jangan teleport berulang-ulang.
			var larang: bool = _masa_larang_pintu > 0.0 and bool(pintu == _pintu_terakhir)
			if (dekat_titik or dekat_pintu) and not larang:
				pintu.call("lalu_automatik", self)
				_pintu_terakhir = pintu as Node2D
				_laluan_indeks += 1
				_masa_laluan_baki = 0.0
				_masa_larang_pintu = 3.0
				_berhenti()
				return true
			_bergerak_ke(pos_pintu, delta, false)
			return true

		var pos: Vector2 = langkah["pos"]
		if global_position.distance_to(pos) <= 7.0:
			_laluan_indeks += 1
			continue
		_bergerak_ke(pos, delta, false)
		return true
	return false


func _bersih_laluan() -> void:
	_laluan = []
	_laluan_indeks = 0
	_masa_laluan_baki = 0.0
	_peta = null
	_masa_peta = 0.0


# Kotak kawasan yang perlu diimbas: merangkumi robot, destinasi dan
# semua sisi pintu, ditambah margin supaya jalan memutar pun dapat dicari.
func _kawasan_laluan(ke: Vector2, senarai_pintu: Array) -> Rect2:
	var min_x: float = minf(global_position.x, ke.x)
	var max_x: float = maxf(global_position.x, ke.x)
	var min_y: float = minf(global_position.y, ke.y)
	var max_y: float = maxf(global_position.y, ke.y)
	for nod in senarai_pintu:
		if not (nod is Node2D) or not nod.has_method("titik_pintasan"):
			continue
		for titik in nod.call("titik_pintasan"):
			var p: Vector2 = titik
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
			min_y = minf(min_y, p.y)
			max_y = maxf(max_y, p.y)
	var kotak := Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	kotak = kotak.grow(36.0)
	if kotak.size.x < 48.0 or kotak.size.y < 48.0:
		kotak = kotak.grow(24.0)
	return kotak


# ==========================================================
# PERGERAKAN
# ==========================================================
# Titik berdiri sejauh jarak_berdiri dari sasaran, pada arah robot sekarang.
func _titik_hampiri(ke: Vector2) -> Vector2:
	var arah := global_position - ke
	if arah.length() < 0.5:
		return ke + Vector2(0.0, -jarak_berdiri)
	return ke + arah.normalized() * jarak_berdiri


func _bergerak_ke(posisi: Vector2, delta: float, elak: bool = true) -> void:
	var arah := posisi - global_position
	if arah.length() < 2.0:
		_berhenti()
		return
	arah = arah.normalized()
	if _baki_elak > 0.0:
		_baki_elak -= delta
		arah = _arah_elak
	elif elak and not _menuju_pintu:
		# Mengelilingi dinding, bukan merempuh dinding.
		arah = _elak_dinding(arah)
	velocity = arah * kelajuan
	# Terbang ke sasaran tidak memakai tenaga (hanya melombong/membaiki).
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
		# Tersangkut: tukar sisi ikut dinding, buang laluan lama dan minta
		# laluan baru dari sistem navigasi.
		_sisi_elak = -_sisi_elak
		_baki_elak = 0.8
		_arah_elak = arah.orthogonal() * _sisi_elak
		_pos_semak = global_position
		_masa_semak = 0.0
		if not _laluan.is_empty():
			_bersih_laluan()


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
	Sfx.mainkan_di("lombong", global_position, -9.0, 0.8)
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
	Sfx.mainkan_di("pecah", global_position, -6.0)

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
	queue_redraw()


func _kemas_visual() -> void:
	if _kilat_baki > 0.0:
		return
	if _sedang_baiki:
		_warna_aksen = SkripReka.AKSEN_BAIKI
	elif _sedang_rehat:
		_warna_aksen = SkripReka.AKSEN_CAS
	elif _sedang_lombong:
		_warna_aksen = SkripReka.AKSEN_LOMBONG
	else:
		_warna_aksen = SkripReka.AKSEN
	queue_redraw()


# Badan robot gaya vektor + bar HP (hijau) dan tenaga (biru) di atasnya.
func _draw() -> void:
	# Badan robot dari skrip reka bentuk yang sama dengan ikon Fabricator.
	var kilat := 1.0 if _kilat_baki > 0.0 else 0.0

	# Robot terbang mendatar gaya superman; animasi ikut keadaan:
	#   terbang — api penyembur di belakang kaki, lebih panjang bila bergerak
	#   haba    — badan terapung naik-turun halus sepanjang masa
	#   lombong — gerudi menolak ke hadapan berulang, badan gegar halus
	#   cas     — teras berdenyut dan badan terapung lebih perlahan
	var bergerak := velocity.length() > 1.0
	var terbang := 0.45
	if _sedang_lombong:
		terbang = 0.6
	elif bergerak:
		terbang = 1.0
	# Api berkerdip sedikit supaya nampak hidup.
	terbang *= 0.85 + 0.15 * sin(_masa_anim * 27.0)

	var gerudi := 0.0
	var gegar := 0.0
	if _sedang_lombong:
		gerudi = absf(sin(_masa_anim * 7.0)) * 1.6
		gegar = sin(_masa_anim * 38.0) * 0.35

	var degup := 0.0
	if _sedang_rehat:
		degup = 0.5 + 0.5 * sin(_masa_anim * 3.2)

	# Terapung perlahan sepanjang masa (tiada graviti).
	var angkat := -absf(sin(_masa_anim * 2.4)) * 0.9

	# Seluruh badan berpusing ikut arah gerakan: kepala dan gerudi sentiasa
	# menghala ke arah ia terbang.
	draw_set_transform(Vector2(gegar, angkat), _arah_badan, Vector2.ONE)
	for lapisan in SkripReka.bentuk(SKALA_BADAN, _warna_aksen, kilat, terbang, gerudi, degup):
		if str(lapisan.get("jenis", "")) == "bulatan":
			draw_circle(lapisan["pusat"], float(lapisan["jejari"]), lapisan["warna"], true, -1.0, true)
		else:
			draw_colored_polygon(lapisan["titik"], lapisan["warna"])
	# Bar HP/tenaga tidak ikut gegar atau terapung.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var lebar := 14.0
	var tinggi := 1.8
	var asas_y := -14.0

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
