# ==========================================================
# FAIL: sfx.gd  (AUTOLOAD — nama singleton: Sfx)
# Semua bunyi dijana dalam kod: tiada fail aset, tiada import editor.
# Guna: Sfx.mainkan("tembakan", -7.0)
#
# Nota iPhone: Xogot/Godot guna sesi audio yang dihenyak oleh suis
# senyap (silent mode), jadi bunyi hanya keluar bila silent dimatikan.
# ==========================================================
extends Node

const KADAR: int = 22050
const PUNCAK: float = 32000.0
const BILANGAN_PEMAIN: int = 4  # supaya bunyi boleh bertindih
const TEMPOH_AMBIEN: float = 14.0
const KADAR_AMBIEN: int = 11025  # lebih rendah supaya penjanaan pantas
# Muzik lawan boss sengaja lebih kuat daripada ambien biasa.
const ISIPADU_BOS: float = 6.0
const ISIPADU_AMBIEN: float = -13.0
const ISIPADU_KAWASAN: float = -11.0

var _pemain: Dictionary = {}
var _giliran: Dictionary = {}
var _aliran: Dictionary = {}
var _ambien: AudioStreamPlayer = null
var _ambien_kawasan: AudioStreamPlayer = null
var _muzik_bos: AudioStreamPlayer = null
var _dalam_kawasan: bool = false
var _tween_ambien: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sedia("tembakan")
	_sedia("lombong")
	_sedia("lendir")
	_sedia("letupan")
	_sedia("lendir_boss")
	_sedia("pecah")
	_sedia("bina")
	_sedia("baiki")
	_sedia("roboh")
	_sedia("bina_siap")
	_sedia("baiki_siap")
	_sedia("roboh_siap")
	_sedia("rancang_ok")
	_sedia("rancang_gagal")
	_sedia("retak")
	_sedia("menu_relau")
	_sedia("menu_fabrikasi")
	_sedia("menu_dapur")
	_sedia("menu_cas")
	_sedia("menu_solar")
	_sedia("menu_inverter")
	_sedia("menu_kajian")
	_sedia("menu_tutup")
	_sedia("klik")
	_aliran["teleport"] = _jana_teleport()
	_mula_ambien()
	_mula_ambien_kawasan()
	_mula_muzik_bos()

# Pasang bunyi klik pada semua butang di bawah `akar`, termasuk butang yang
# dibina dalam kod. Panggil semula setiap kali senarai butang dibina semula.
func pasang_klik(akar: Node) -> void:
	for anak in akar.get_children():
		if anak is Button and not anak.pressed.is_connected(_bunyi_klik):
			anak.pressed.connect(_bunyi_klik)
		pasang_klik(anak)

func _bunyi_klik() -> void:
	mainkan("klik", -9.0)

func mainkan(nama: String, isipadu_db: float = -6.0, pic: float = 1.0) -> void:
	if not _pemain.has(nama):
		return
	var senarai: Array = _pemain[nama]
	if senarai.is_empty():
		return
	var idx: int = _giliran[nama]
	_giliran[nama] = (idx + 1) % senarai.size()
	var pemain: AudioStreamPlayer = senarai[idx]
	pemain.volume_db = isipadu_db
	pemain.pitch_scale = pic * randf_range(0.94, 1.06)
	pemain.play()


# SFX aksi dimainkan dari kedudukan sumber supaya bunyi jauh semakin perlahan.
func mainkan_di(nama: String, posisi: Vector2, isipadu_db: float = -6.0,
		pic: float = 1.0) -> void:
	if not _aliran.has(nama):
		return
	var pemain := AudioStreamPlayer2D.new()
	pemain.stream = _aliran[nama]
	pemain.volume_db = isipadu_db
	pemain.pitch_scale = pic * randf_range(0.94, 1.06)
	pemain.max_distance = 480.0
	pemain.attenuation = 1.2
	var induk := get_tree().current_scene
	if induk == null:
		induk = self
	induk.add_child(pemain)
	pemain.global_position = posisi
	pemain.finished.connect(pemain.queue_free)
	pemain.play()

# ---- Ambien: ruang angkasa + kawasan AquaHusk ------------------------

func _ambien_semasa() -> AudioStreamPlayer:
	return _ambien_kawasan if _dalam_kawasan else _ambien

# Player masuk/keluar kawasan AquaHusk: ambien angkasa bertukar jadi versi
# perlahan muzik boss. Muzik boss penuh mengatasinya bila boss menyerang.
func kawasan_bos(nyala: bool) -> void:
	if _dalam_kawasan == nyala:
		return
	_dalam_kawasan = nyala
	if _muzik_bos != null and _muzik_bos.playing:
		# Muzik boss sedang main; muzik_bos(false) nanti pilih ambien betul.
		return
	_tukar_ambien(_ambien_semasa(), 1.2)

func _tukar_ambien(sasaran: AudioStreamPlayer, masa: float) -> void:
	if _tween_ambien != null and _tween_ambien.is_valid():
		_tween_ambien.kill()
	for p in [_ambien, _ambien_kawasan]:
		if p == null or p == sasaran:
			continue
		if p.playing:
			p.stop()
	if sasaran == null:
		return
	var isipadu: float = ISIPADU_KAWASAN if sasaran == _ambien_kawasan else ISIPADU_AMBIEN
	sasaran.volume_db = -40.0
	if not sasaran.playing:
		sasaran.play()
	_tween_ambien = create_tween()
	_tween_ambien.tween_property(sasaran, "volume_db", isipadu, masa)

# Muzik rancak semasa boss menyerang.
func muzik_bos(nyala: bool) -> void:
	if _muzik_bos == null:
		return
	if nyala:
		if not _muzik_bos.playing:
			# Pudar masuk ringkas supaya masuk lawan boss terasa "meledak".
			_muzik_bos.volume_db = -12.0
			_muzik_bos.play()
			var naik := create_tween()
			naik.tween_property(_muzik_bos, "volume_db", ISIPADU_BOS, 0.7)
		# Ambien dimatikan sepenuhnya semasa muzik boss main.
		_tukar_ambien(null, 0.0)
	else:
		if _muzik_bos.playing:
			_muzik_bos.stop()
		# Balik ke ambien yang betul: kawasan AquaHusk atau ruang angkasa.
		_tukar_ambien(_ambien_semasa(), 0.9)

func _mula_muzik_bos() -> void:
	var stream := _jana_rancak()
	if stream == null:
		return
	_muzik_bos = AudioStreamPlayer.new()
	_muzik_bos.stream = stream
	_muzik_bos.volume_db = ISIPADU_BOS
	_muzik_bos.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_muzik_bos)

func ambien_aktif(nyala: bool) -> void:
	var p := _ambien_semasa()
	if p == null:
		return
	if nyala:
		p.play()
	else:
		p.stop()

func isipadu_ambien(db: float) -> void:
	var p := _ambien_semasa()
	if p:
		p.volume_db = db

func _mula_ambien() -> void:
	var stream := _jana_ambien()
	if stream == null:
		return
	_ambien = AudioStreamPlayer.new()
	_ambien.stream = stream
	_ambien.volume_db = ISIPADU_AMBIEN
	_ambien.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambien)
	_ambien.play()

func _mula_ambien_kawasan() -> void:
	var stream := _jana_kawasan_bos()
	if stream == null:
		return
	_ambien_kawasan = AudioStreamPlayer.new()
	_ambien_kawasan.stream = stream
	_ambien_kawasan.volume_db = -40.0
	_ambien_kawasan.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambien_kawasan)

# ---- Peralatan bunyi -------------------------------------------------

func _sedia(nama: String) -> void:
	var stream := _jana(nama)
	if stream == null:
		return
	var senarai: Array = []
	for i in BILANGAN_PEMAIN:
		var pemain := AudioStreamPlayer.new()
		pemain.stream = stream
		pemain.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(pemain)
		senarai.append(pemain)
	_pemain[nama] = senarai
	_aliran[nama] = stream
	_giliran[nama] = 0

# Penapis satu kutub ringkas (low-pass).
func _lulus_rendah(s: PackedFloat32Array, kekerapan: float) -> void:
	var a: float = clampf(TAU * kekerapan / float(KADAR), 0.0, 1.0)
	var y: float = 0.0
	for i in s.size():
		y += a * (s[i] - y)
		s[i] = y

# Gema ringkas supaya bunyi terasa seperti dalam ruang besar.
func _gema(s: PackedFloat32Array, lengah: float, kekuatan: float) -> void:
	var d: int = int(lengah * KADAR)
	if d <= 0 or d >= s.size():
		return
	for i in range(d, s.size()):
		s[i] += s[i - d] * kekuatan

func _normal(s: PackedFloat32Array, sasaran: float) -> void:
	var puncak: float = 0.0
	for i in s.size():
		var v: float = absf(s[i])
		if v > puncak:
			puncak = v
	if puncak < 0.0001:
		return
	var g: float = sasaran / puncak
	for i in s.size():
		s[i] *= g

func _ke_stream(s: PackedFloat32Array, gelung: bool, kadar: int = KADAR) -> AudioStreamWAV:
	var bait := PackedByteArray()
	bait.resize(s.size() * 2)
	for i in s.size():
		var nilai: float = clampf(s[i], -1.0, 1.0)
		var v: int = clampi(int(roundf(nilai * PUNCAK)), -32768, 32767)
		var u: int = v
		if u < 0:
			u += 65536
		bait[i * 2] = u & 0xFF
		bait[i * 2 + 1] = (u >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = kadar
	stream.stereo = false
	stream.data = bait
	if gelung:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = s.size()
	return stream

# ---- Bunyi tembakan: laser berlapis + gema ruang ----------------------

func _jana(nama: String) -> AudioStreamWAV:
	if nama == "tembakan":
		return _jana_tembakan()
	if nama == "lombong":
		return _jana_lombong()
	if nama == "lendir":
		return _jana_lendir()
	if nama == "letupan":
		return _jana_letupan()
	if nama == "lendir_boss":
		return _jana_lendir_boss()
	if nama == "pecah":
		return _jana_pecah()
	if nama == "bina":
		return _jana_bina()
	if nama == "baiki":
		return _jana_baiki()
	if nama == "roboh":
		return _jana_roboh()
	if nama == "bina_siap":
		return _jana_siap(523.25, 783.99, 0.26)
	if nama == "baiki_siap":
		return _jana_siap(659.25, 987.77, 0.12)
	if nama == "roboh_siap":
		return _jana_roboh_siap()
	if nama == "rancang_ok":
		return _jana_rancang_ok()
	if nama == "rancang_gagal":
		return _jana_rancang_gagal()
	if nama == "retak":
		return _jana_retak()
	if nama == "klik":
		return _jana_klik()
	# Tutup menu perabot: satu bunyi generik, sama untuk semua jenis menu.
	if nama == "menu_tutup":
		return _jana_menu_tutup()
	# Menu perabot: satu bunyi per jenis (lihat _jana_menu).
	if nama.begins_with("menu_"):
		return _jana_menu(nama)
	push_warning("Sfx: bunyi tidak dikenali - " + nama)
	return null

func _jana_tembakan() -> AudioStreamWAV:
	var tempoh: float = 0.26
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var fasa: float = 0.0
	var fasa_sub: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		var maju: float = t / tempoh
		# "Pew": frekuensi jatuh laju pada awal, perlahan kemudian.
		var f: float = lerpf(2100.0, 320.0, pow(maju, 0.55))
		fasa += TAU * f / float(KADAR)
		fasa_sub += TAU * (f * 0.5) / float(KADAR)
		# Sedikit vibrato + saturasi untuk badan bunyi yang padat.
		var vibrato: float = 0.06 * sin(TAU * 38.0 * t)
		var badan: float = sin(fasa + vibrato) + 0.4 * sin(fasa_sub)
		badan = clampf(badan * 1.5, -1.0, 1.0) * exp(-t * 15.0)
		# Desiran tekan udara pada saat peluru keluar.
		var desir: float = randf_range(-1.0, 1.0) * exp(-t * 110.0) * 0.55
		# "Thump" rendah untuk rasa berat.
		var dentum: float = sin(TAU * 95.0 * t) * exp(-t * 34.0) * 0.45
		s[i] = badan * 0.55 + desir + dentum
	_lulus_rendah(s, 5200.0)
	_gema(s, 0.045, 0.28)
	_gema(s, 0.095, 0.16)
	_normal(s, 0.9)
	return _ke_stream(s, false)

# ---- Bunyi melombong: ketukan batu + serpihan pecah -------------------

func _jana_lombong() -> AudioStreamWAV:
	# Bunyi batu hancur sepenuhnya berasaskan noise: tiada nada tetap,
	# jadi tiada langsung bunyi "dong".
	var tempoh: float = 0.30
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var a_tengah: float = clampf(TAU * 1800.0 / float(KADAR), 0.0, 1.0)
	var a_rendah: float = clampf(TAU * 200.0 / float(KADAR), 0.0, 1.0)
	var y_tengah: float = 0.0
	var y_rendah: float = 0.0
	var butir: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		var putih: float = randf_range(-1.0, 1.0)
		y_tengah += a_tengah * (putih - y_tengah)
		y_rendah += a_rendah * (putih - y_rendah)
		# Impak: noise penuh yang reput dalam beberapa milisaat.
		var impak: float = putih * exp(-t * 230.0) * 0.85
		# Hancur: julat pertengahan (band-pass kasar), lembap dan berat.
		var hancur: float = (y_tengah - y_rendah) * exp(-t * 24.0) * 1.7
		# Kerikil: butir rawak yang makin jarang (tekstur retak).
		if randf() < 0.22 * exp(-t * 10.0):
			butir = randf_range(-1.0, 1.0) * randf_range(0.3, 0.7)
		butir *= 0.86
		s[i] = impak + hancur + butir
	_lulus_rendah(s, 6000.0)
	_normal(s, 0.9)
	return _ke_stream(s, false)

# ---- Ambien angkasa: pad lembut + bintang berkelip --------------------

func _jana_ambien() -> AudioStreamWAV:
	var kadar: int = KADAR_AMBIEN
	var gelung: int = int(kadar * TEMPOH_AMBIEN)
	var silang: int = int(kadar * 1.0)  # crossfade untuk gelung licin
	var n: int = gelung + silang
	var s := PackedFloat32Array()
	s.resize(n)
	# Pad lembut: A2, E3, C4 — setiap satu dua oscillator detune supaya
	# ada "beating" perlahan seperti bunyi ambient angkasa.
	var nada := [110.0, 164.81, 261.63]
	var lfo_kadar := [1.0, 2.0, 3.0]
	for i in n:
		var t: float = float(i) / float(kadar)
		var pad: float = 0.0
		for j in nada.size():
			var f: float = nada[j]
			var am: float = 0.5 + 0.5 * sin(TAU * lfo_kadar[j] * t / TEMPOH_AMBIEN + float(j) * 1.7)
			pad += (sin(TAU * f * t) + 0.6 * sin(TAU * f * 1.004 * t)) * am
		pad /= float(nada.size()) * 1.6
		# Kilau tinggi yang berdenyut perlahan.
		var kilau: float = sin(TAU * 1046.5 * t + 1.5 * sin(TAU * 2.0 * t / TEMPOH_AMBIEN)) * 0.05
		kilau *= 0.5 + 0.5 * sin(TAU * 3.0 * t / TEMPOH_AMBIEN + 0.8)
		s[i] = pad * 0.9 + kilau
	# Bintang berkelip: loceng halus bertaburan sepanjang gelung.
	var nada_bintang := [1318.5, 1568.0, 1760.0, 2093.0]
	for _k in 12:
		var mula: float = randf_range(0.5, TEMPOH_AMBIEN - 2.0)
		var f2: float = nada_bintang.pick_random()
		var amp: float = randf_range(0.05, 0.11)
		var i0: int = int(mula * kadar)
		var panjang: int = int(2.0 * kadar)
		var fasa2: float = 0.0
		for i in panjang:
			var idx: int = i0 + i
			if idx >= n:
				break
			var t2: float = float(i) / float(kadar)
			fasa2 += TAU * f2 / float(kadar)
			s[idx] += sin(fasa2) * exp(-t2 * 2.0) * amp
	_normal(s, 0.5)
	# Crossfade hujung ke kepala supaya gelung tidak "pop".
	for i in silang:
		var w: float = float(i) / float(silang)
		s[i] = s[i] * w + s[n - silang + i] * (1.0 - w)
	var hasil := PackedFloat32Array()
	hasil.resize(gelung)
	for i in gelung:
		hasil[i] = s[i]
	return _ke_stream(hasil, true, kadar)

# ---- Bunyi teleport: whoosh tenaga + nada sci-fi ---------------------

func _jana_teleport() -> AudioStreamWAV:
	var tempoh: float = 0.48
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var fasa: float = 0.0
	var fasa_lapis: float = 0.0
	var noise_lulus: float = 0.0
	var a_noise: float = clampf(TAU * 1500.0 / float(KADAR), 0.0, 1.0)
	for i in n:
		var t: float = float(i) / float(KADAR)
		var maju: float = t / tempoh
		var f: float = lerpf(180.0, 1450.0, maju) if maju < 0.55 else lerpf(
			1450.0, 300.0, (maju - 0.55) / 0.45
		)
		fasa += TAU * f / float(KADAR)
		fasa_lapis += TAU * f * 1.51 / float(KADAR)
		var sampul: float = sin(PI * maju)
		var putih: float = randf_range(-1.0, 1.0)
		noise_lulus += a_noise * (putih - noise_lulus)
		var whoosh: float = (putih - noise_lulus) * sampul * 0.75
		var nada: float = (sin(fasa) + 0.35 * sin(fasa_lapis)) * sampul
		s[i] = whoosh + nada * 0.55
	_lulus_rendah(s, 5200.0)
	_gema(s, 0.075, 0.22)
	_normal(s, 0.88)
	return _ke_stream(s, false)

# ---- Bunyi lendir: "blup" basah + percikan ----------------------------

func _jana_lendir() -> AudioStreamWAV:
	var tempoh: float = 0.30
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var fasa: float = 0.0
	var lembap: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		var maju: float = t / tempoh
		# Blup basah: frekuensi jatuh 560 -> 150 Hz dengan getaran kecil.
		var f: float = lerpf(560.0, 150.0, pow(maju, 0.8))
		fasa += TAU * f / float(KADAR)
		var badan: float = sin(fasa + 0.25 * sin(TAU * 26.0 * t))
		badan = clampf(badan * 1.6, -1.0, 1.0) * exp(-t * 9.0)
		# Percikan lendir melekit.
		lembap = lembap * 0.6 + randf_range(-1.0, 1.0) * 0.4
		var percik: float = lembap * exp(-t * 20.0) * 0.5
		s[i] = badan * 0.75 + percik
	_lulus_rendah(s, 2600.0)
	_normal(s, 0.85)
	return _ke_stream(s, false)

# ---- Bunyi letupan musuh: debum rendah + serpihan --------------------

func _jana_letupan() -> AudioStreamWAV:
	var tempoh: float = 0.75
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var fasa: float = 0.0
	var gemuruh: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		var f: float = lerpf(115.0, 34.0, t / tempoh)
		fasa += TAU * f / float(KADAR)
		var debum: float = sin(fasa) * exp(-t * 6.5) * 0.9
		# Riuh rendah yang pecah (noise ditapis).
		gemuruh = gemuruh * 0.85 + randf_range(-1.0, 1.0) * 0.15
		var hancur: float = gemuruh * exp(-t * 13.0) * 1.6
		# Serpihan kecil bertaburan.
		var retak: float = 0.0
		if randf() < 0.12 * exp(-t * 5.0):
			retak = randf_range(-1.0, 1.0) * 0.6
		s[i] = debum + hancur + retak
	_lulus_rendah(s, 1900.0)
	_gema(s, 0.09, 0.22)
	_normal(s, 0.95)
	return _ke_stream(s, false)

# ---- Bunyi lendir boss: semburan api ---------------------------------

func _jana_lendir_boss() -> AudioStreamWAV:
	var tempoh: float = 0.55
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var a_badan: float = clampf(TAU * 1200.0 / float(KADAR), 0.0, 1.0)
	var a_udara: float = clampf(TAU * 5200.0 / float(KADAR), 0.0, 1.0)
	var y_badan: float = 0.0
	var y_udara: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		var putih: float = randf_range(-1.0, 1.0)
		y_badan += a_badan * (putih - y_badan)
		y_udara += a_udara * (putih - y_udara)
		var mula: float = 1.0 - exp(-t * 60.0)   # sembur keluar pantas
		var habis: float = exp(-t * 4.2)
		# Bergetar seperti api yang bergelogok.
		var layap: float = 0.8 + 0.2 * sin(TAU * 33.0 * t + 3.0 * sin(TAU * 7.0 * t))
		var sembur: float = (y_badan * 0.9 + (y_udara - y_badan) * 0.6) * mula * habis * layap
		var retak: float = 0.0
		if randf() < 0.04 * exp(-t * 3.0):
			retak = randf_range(-1.0, 1.0) * 0.35
		s[i] = sembur * 1.2 + retak
	_normal(s, 0.9)
	return _ke_stream(s, false)

# ---- Muzik rancak boss: gelung 8 ketukan -----------------------------

func _tambah_dentum(s: PackedFloat32Array, kadar: int, mula: float, f0: float, f1: float,
		panjang: float, amp: float, redam: float) -> void:
	var i0: int = int(mula * kadar)
	var jumlah: int = int(panjang * kadar)
	var fasa: float = 0.0
	for i in jumlah:
		var idx: int = (i0 + i) % s.size()  # bungkus supaya gelung licin
		var t: float = float(i) / float(kadar)
		fasa += TAU * lerpf(f0, f1, t / panjang) / float(kadar)
		s[idx] += sin(fasa) * exp(-t * redam) * amp

func _tambah_hitam(s: PackedFloat32Array, kadar: int, mula: float, panjang: float, amp: float) -> void:
	var i0: int = int(mula * kadar)
	var jumlah: int = int(panjang * kadar)
	var a: float = clampf(TAU * 1500.0 / float(kadar), 0.0, 1.0)
	var y: float = 0.0
	for i in jumlah:
		var idx: int = (i0 + i) % s.size()
		var t: float = float(i) / float(kadar)
		var putih: float = randf_range(-1.0, 1.0)
		y += a * (putih - y)
		s[idx] += (putih - y) * exp(-t * 75.0) * amp

func _tambah_nada(s: PackedFloat32Array, kadar: int, mula: float, f: float,
		panjang: float, amp: float, redam: float) -> void:
	var i0: int = int(mula * kadar)
	var jumlah: int = int(panjang * kadar)
	var fasa: float = 0.0
	for i in jumlah:
		var idx: int = (i0 + i) % s.size()
		var t: float = float(i) / float(kadar)
		fasa += TAU * f / float(kadar)
		var v: float = sin(fasa) + 0.5 * sin(fasa * 2.0) + 0.25 * sin(fasa * 3.0)
		var sampul: float = (1.0 - exp(-t * 90.0)) * exp(-t * redam)
		s[idx] += v * sampul * amp

func _tambah_kluster(s: PackedFloat32Array, kadar: int, mula: float, frekuensi: Array,
		panjang: float, amp: float, redam: float) -> void:
	var i0: int = int(mula * kadar)
	var jumlah: int = int(panjang * kadar)
	for i in jumlah:
		var idx: int = (i0 + i) % s.size()
		var t: float = float(i) / float(kadar)
		var v: float = 0.0
		for f in frekuensi:
			var fasa: float = TAU * float(f) * t
			v += sin(fasa) + 0.3 * sin(fasa * 3.0)
		v /= float(frekuensi.size())
		s[idx] += v * (1.0 - exp(-t * 120.0)) * exp(-t * redam) * amp

func _tambah_riser(s: PackedFloat32Array, kadar: int, mula: float, panjang: float, amp: float) -> void:
	var i0: int = int(mula * kadar)
	var jumlah: int = int(panjang * kadar)
	var a: float = clampf(TAU * 2000.0 / float(kadar), 0.0, 1.0)
	var y: float = 0.0
	var fasa: float = 0.0
	for i in jumlah:
		var idx: int = (i0 + i) % s.size()
		var t: float = float(i) / float(kadar)
		var maju: float = t / panjang
		var putih: float = randf_range(-1.0, 1.0)
		y += a * (putih - y)
		var tinggi: float = putih - y
		fasa += TAU * lerpf(120.0, 900.0, maju * maju) / float(kadar)
		s[idx] += (tinggi * 0.6 + sin(fasa) * 0.5) * pow(maju, 2.0) * amp

func _jana_rancak(bpm: float = 172.0, drive: float = 6.0, sasaran: float = 0.50) -> AudioStreamWAV:
	var kadar: int = KADAR_AMBIEN
	var ketuk: float = 60.0 / bpm
	var bil_ketuk: int = 8
	var tempoh: float = ketuk * bil_ketuk
	var n: int = int(kadar * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var langkah: float = ketuk * 0.25  # not keenam belas

	# Bass 16-hantaran dengan lompat oktaf: rasa kelam kabut dan gelisah.
	var bass := [55.0, 55.0, 110.0, 55.0, 77.78, 55.0, 73.42, 103.83]
	for i in 32:
		var mula: float = float(i) * langkah
		_tambah_nada(s, kadar, mula, bass[i % 8], langkah * 0.9, 0.30, 26.0)
		# Hi-hat setiap 16-hantaran, aksen pada ketuk.
		var aksen: float = 0.16 if i % 4 == 0 else 0.09
		_tambah_hitam(s, kadar, mula, 0.05, aksen)

	# Tendangan setiap ketuk + tendangan hantu antara ketuk.
	for b in bil_ketuk:
		var mula: float = float(b) * ketuk
		_tambah_dentum(s, kadar, mula, 160.0, 48.0, 0.22, 0.85, 18.0)
		_tambah_dentum(s, kadar, mula + ketuk * 0.35, 130.0, 45.0, 0.18, 0.58, 22.0)
		if b == 3 or b == 7:
			_tambah_dentum(s, kadar, mula + ketuk * 0.62, 150.0, 52.0, 0.10, 0.34, 34.0)

	# Snare utama + snare hantu supaya rentak terasa sesak.
	for b in [2, 6]:
		var mula: float = float(b) * ketuk
		_tambah_hitam(s, kadar, mula, 0.16, 0.40)
		_tambah_nada(s, kadar, mula, 190.0, 0.12, 0.28, 30.0)
	for b in [1, 5]:
		_tambah_hitam(s, kadar, float(b) * ketuk + ketuk * 0.5, 0.06, 0.14)

	# Kluster sumbang (A minor + tritone): biola histeria, dua ketuk sekali.
	var kluster_a := [220.0, 261.63, 311.13]
	var kluster_b := [233.08, 293.66, 349.23]
	for b in bil_ketuk:
		if b % 2 == 1:
			continue
		var mula: float = float(b) * ketuk
		var notas: Array = kluster_a if b % 4 == 0 else kluster_b
		_tambah_kluster(s, kadar, mula, notas, 0.18, 0.62, 16.0)
		if b == 2 or b == 6:
			_tambah_kluster(s, kadar, mula + ketuk * 0.5, notas, 0.12, 0.40, 22.0)

	# Melodi arpeggio tinggi: inilah yang paling jelas pada speaker kecil iPhone.
	var melodi := [587.33, 698.46, 880.0, 783.99, 659.25, 880.0, 1046.5, 880.0,
		587.33, 698.46, 880.0, 1174.66, 1046.5, 880.0, 783.99, 659.25]
	for i in bil_ketuk:
		_tambah_nada(s, kadar, float(i) * ketuk, melodi[i * 2], ketuk * 0.8, 0.26, 12.0)

	# Riser menegangkan setiap 4 ketuk.
	_tambah_riser(s, kadar, 0.0, ketuk * 4.0, 0.30)
	_tambah_riser(s, kadar, ketuk * 4.0, ketuk * 4.0, 0.42)

	# Dron rendah D1 yang bergetar perlahan (ancaman di belakang).
	for i in n:
		var t: float = float(i) / float(kadar)
		var getar: float = 0.6 + 0.4 * sin(TAU * 3.0 * t / tempoh)
		s[i] += sin(TAU * 36.71 * t) * 0.26 * getar

	_normal(s, 0.97)
	# Mampatan tanh kuat: RMS naik tinggi, jadi muzik terasa paling kuat
	# walaupun puncak kekal dalam had (tiada clipping).
	for i in n:
		s[i] = tanh(s[i] * drive)
	# 0.50 + ISIPADU_BOS 6.0 dB (~2x) = puncak ~1.0: sekuat mungkin tanpa clipping.
	_normal(s, sasaran)
	return _ke_stream(s, true, kadar)

# Versi perlahan muzik boss untuk kawasan AquaHusk (sebelum boss bangun).
func _jana_kawasan_bos() -> AudioStreamWAV:
	return _jana_rancak(124.0, 3.0, 0.55)

# ---- Bunyi meteorit pecah sepenuhnya: hancur besar -------------------

func _jana_pecah() -> AudioStreamWAV:
	var tempoh: float = 0.95
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var a_tengah: float = clampf(TAU * 2200.0 / float(KADAR), 0.0, 1.0)
	var a_rendah: float = clampf(TAU * 180.0 / float(KADAR), 0.0, 1.0)
	var y_tengah: float = 0.0
	var y_rendah: float = 0.0
	var fasa_gemuruh: float = 0.0
	var butir: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		var putih: float = randf_range(-1.0, 1.0)
		y_tengah += a_tengah * (putih - y_tengah)
		y_rendah += a_rendah * (putih - y_rendah)
		# Letusan besar: noise penuh.
		var letus: float = putih * exp(-t * 55.0) * 0.9
		# Hancuran batu yang berterusan.
		var hancur: float = (y_tengah - y_rendah) * exp(-t * 7.0) * 1.5
		# Gemuruh rendah perlahan (rasa berat).
		fasa_gemuruh += TAU * lerpf(72.0, 34.0, t / tempoh) / float(KADAR)
		var gemuruh: float = sin(fasa_gemuruh) * exp(-t * 3.2) * 0.45
		# Serpihan bertaburan sepanjang letupan.
		if randf() < 0.30 * exp(-t * 3.5):
			butir = randf_range(-1.0, 1.0) * randf_range(0.25, 0.7)
		butir *= 0.9
		s[i] = letus + hancur + gemuruh + butir
	_lulus_rendah(s, 5200.0)
	_gema(s, 0.12, 0.25)
	_gema(s, 0.26, 0.14)
	_normal(s, 0.95)
	return _ke_stream(s, false)

# ---- Bunyi kerja bina: ketukan tukul pada struktur -------------------

func _jana_bina() -> AudioStreamWAV:
	var tempoh: float = 0.20
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var a_tengah: float = clampf(TAU * 2600.0 / float(KADAR), 0.0, 1.0)
	var a_rendah: float = clampf(TAU * 300.0 / float(KADAR), 0.0, 1.0)
	var y_tengah: float = 0.0
	var y_rendah: float = 0.0
	var fasa_dentum: float = 0.0
	var fasa_logam: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		var putih: float = randf_range(-1.0, 1.0)
		y_tengah += a_tengah * (putih - y_tengah)
		y_rendah += a_rendah * (putih - y_rendah)
		fasa_dentum += TAU * lerpf(150.0, 62.0, clampf(t / 0.12, 0.0, 1.0)) / float(KADAR)
		fasa_logam += TAU * 1180.0 / float(KADAR)
		# Ketukan tukul: noise tajam + dentum rendah + dering logam.
		var ketuk: float = putih * exp(-t * 260.0) * 0.8
		var dentum: float = sin(fasa_dentum) * exp(-t * 26.0) * 0.7
		var dering: float = sin(fasa_logam) * exp(-t * 60.0) * 0.32
		var logam: float = (y_tengah - y_rendah) * exp(-t * 90.0) * 0.45
		s[i] = ketuk + dentum + dering + logam
	_lulus_rendah(s, 6500.0)
	_normal(s, 0.9)
	return _ke_stream(s, false)

# ---- Bunyi kerja baiki: tiga klik sepana ----------------------------

func _jana_baiki() -> AudioStreamWAV:
	var tempoh: float = 0.26
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	# Tiga klik sepana: bunyi baiki lebih "rapi" daripada ketukan tukul.
	var masa_klik := [0.0, 0.075, 0.15]
	for mula in masa_klik:
		var i0: int = int(float(mula) * KADAR)
		var panjang: int = int(0.06 * KADAR)
		var fasa: float = 0.0
		var y: float = 0.0
		var a: float = clampf(TAU * 3000.0 / float(KADAR), 0.0, 1.0)
		for i in panjang:
			var idx: int = i0 + i
			if idx >= n:
				break
			var t: float = float(i) / float(KADAR)
			var putih: float = randf_range(-1.0, 1.0)
			y += a * (putih - y)
			fasa += TAU * lerpf(900.0, 520.0, clampf(t / 0.06, 0.0, 1.0)) / float(KADAR)
			var klik: float = (putih - y) * exp(-t * 420.0) * 0.9
			var dering: float = sin(fasa) * exp(-t * 90.0) * 0.4
			s[idx] += klik + dering
	# Desiran alat ringan di latar supaya kedengaran seperti kerja berjalan.
	for i in n:
		var t: float = float(i) / float(KADAR)
		s[i] += randf_range(-1.0, 1.0) * 0.05 * exp(-t * 9.0)
	_lulus_rendah(s, 7000.0)
	_normal(s, 0.85)
	return _ke_stream(s, false)

# ---- Bunyi roboh: runtuhan kayu (siap) + kerja mencungkil -------------

# Penapis band-pass ringkas (state variable) untuk badan kayu.
func _lulus_jalur(s: PackedFloat32Array, kekerapan: float, q: float) -> void:
	var f: float = 2.0 * sin(PI * kekerapan / float(KADAR))
	var redam: float = 1.0 / maxf(q, 0.5)
	var rendah: float = 0.0
	var jalur: float = 0.0
	for i in s.size():
		var x: float = s[i]
		rendah += f * jalur
		var tinggi: float = x - rendah - redam * jalur
		jalur += f * tinggi
		s[i] = jalur

# Satu serpihan kayu jatuh: ketukan desir pendek yang ditapis (bukan nada).
func _serpihan_kayu(s: PackedFloat32Array, mula: float, kuat: float) -> void:
	var n: int = s.size()
	var i0: int = int(mula * float(KADAR))
	if i0 >= n or kuat <= 0.0:
		return
	var panjang: int = int(0.035 * float(KADAR))
	var f: float = 2.0 * sin(PI * randf_range(700.0, 1900.0) / float(KADAR))
	var redam: float = 1.0 / 2.5
	var rendah: float = 0.0
	var jalur: float = 0.0
	for i in panjang:
		var idx: int = i0 + i
		if idx >= n:
			break
		var t: float = float(i) / float(KADAR)
		var x: float = randf_range(-1.0, 1.0) * exp(-t * 140.0)
		rendah += f * jalur
		var tinggi: float = x - rendah - redam * jalur
		jalur += f * tinggi
		s[idx] += jalur * kuat * 1.4

# Roboh siap: papan patah, serpihan berderai dan gemuruh - semuanya berasaskan
# desir supaya kedengaran macam kayu pecah, bukan ketukan bernada.
func _jana_roboh_siap() -> AudioStreamWAV:
	var tempoh: float = 0.75
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)

	# 1) Retak besar: desir jalur lebar pendek, macam papan patah.
	var retak := PackedFloat32Array()
	retak.resize(n)
	for i in n:
		var t: float = float(i) / float(KADAR)
		retak[i] = randf_range(-1.0, 1.0) * exp(-t * 42.0)
	# Badan papan: retak ditapis pada dua frekuensi badan kayu.
	var badan: PackedFloat32Array = retak.duplicate()
	_lulus_jalur(badan, 620.0, 3.0)
	var badan2: PackedFloat32Array = retak.duplicate()
	_lulus_jalur(badan2, 1400.0, 2.0)
	for i in n:
		var t: float = float(i) / float(KADAR)
		s[i] += retak[i] * 0.6
		s[i] += badan[i] * 2.2 * exp(-t * 7.0)
		s[i] += badan2[i] * 1.6 * exp(-t * 11.0)

	# 2) Serpihan jatuh: ketukan desir pendek pada masa rawak.
	var masa: float = 0.015
	while masa < 0.55:
		_serpihan_kayu(s, masa, (1.0 - masa / 0.62) * randf_range(0.4, 0.9))
		masa += randf_range(0.012, 0.042)

	# 3) Gemuruh rendah + dentuman berat (struktur tumbang ke tanah).
	var gemuruh := PackedFloat32Array()
	gemuruh.resize(n)
	for i in n:
		gemuruh[i] = randf_range(-1.0, 1.0)
	_lulus_rendah(gemuruh, 240.0)
	var fasa_dentum: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		fasa_dentum += TAU * lerpf(110.0, 42.0, clampf(t / 0.25, 0.0, 1.0)) / float(KADAR)
		var dentum: float = sin(fasa_dentum) * exp(-t * 9.0) * 0.4
		s[i] += gemuruh[i] * 3.0 * exp(-t * 4.0) + dentum
	_lulus_rendah(s, 8500.0)
	_gema(s, 0.05, 0.18)
	_normal(s, 0.96)
	return _ke_stream(s, false)

# ---- Bunyi kerja roboh: retak dan hancur (kekal macam asal) ----------

func _jana_roboh() -> AudioStreamWAV:
	var tempoh: float = 0.30
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var a_tengah: float = clampf(TAU * 1400.0 / float(KADAR), 0.0, 1.0)
	var a_rendah: float = clampf(TAU * 220.0 / float(KADAR), 0.0, 1.0)
	var y_tengah: float = 0.0
	var y_rendah: float = 0.0
	var fasa_kerik: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		var putih: float = randf_range(-1.0, 1.0)
		y_tengah += a_tengah * (putih - y_tengah)
		y_rendah += a_rendah * (putih - y_rendah)
		# Retak: noise pecah pendek.
		var retak: float = putih * exp(-t * 120.0) * 0.75
		# Hancur: jalur pertengahan yang reput perlahan.
		var hancur: float = (y_tengah - y_rendah) * exp(-t * 18.0) * 1.2
		# Struktur menegang (kayu/logam berderit).
		fasa_kerik += TAU * (240.0 + 120.0 * sin(TAU * 7.0 * t)) / float(KADAR)
		var kerik: float = sin(fasa_kerik) * exp(-t * 14.0) * 0.18
		s[i] = retak + hancur + kerik
	_lulus_rendah(s, 4800.0)
	_normal(s, 0.88)
	return _ke_stream(s, false)

# ---- Bunyi siap bina/baiki: dua nada + dentuman kecil -----------------
# Bina dan baiki kongsi bentuk yang sama; frekuensi berbeza memberi warna
# masing-masing (bina naik sederhana, baiki lebih cerah). Roboh ada bunyi
# runtuhan kayu sendiri di atas.

func _jana_siap(f1: float, f2: float, amp_dentum: float) -> AudioStreamWAV:
	var tempoh: float = 0.42
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var mula_nada2: float = 0.10
	var fasa1: float = 0.0
	var fasa2: float = 0.0
	var fasa_dentum: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		fasa1 += TAU * f1 / float(KADAR)
		fasa_dentum += TAU * lerpf(190.0, 70.0, clampf(t / 0.14, 0.0, 1.0)) / float(KADAR)
		var dentum: float = sin(fasa_dentum) * exp(-t * 30.0) * amp_dentum
		var naik1: float = 1.0 - exp(-t * 220.0)
		var v1: float = (sin(fasa1) + 0.35 * sin(fasa1 * 2.0)) * naik1 * exp(-t * 7.0) * 0.45
		var v2: float = 0.0
		if t >= mula_nada2:
			var t2: float = t - mula_nada2
			fasa2 += TAU * f2 / float(KADAR)
			var naik2: float = 1.0 - exp(-t2 * 220.0)
			v2 = (sin(fasa2) + 0.30 * sin(fasa2 * 2.0)) * naik2 * exp(-t2 * 6.0) * 0.42
		s[i] = v1 + v2 + dentum
	_lulus_rendah(s, 8000.0)
	_gema(s, 0.06, 0.18)
	_normal(s, 0.85)
	return _ke_stream(s, false)

# ---- Bunyi letak rancangan: berjaya / gagal -------------------------
# Wall, floor dan door kongsi bunyi yang sama supaya pemain kenal isyarat
# "rancangan diterima" dan "rancangan ditolak" tanpa perlu beza jenis.

func _jana_rancang_ok() -> AudioStreamWAV:
	var tempoh: float = 0.16
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var fasa: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		# Nada naik pendek: bunyi "ting" tanda rancangan diterima.
		fasa += TAU * lerpf(680.0, 980.0, clampf(t / tempoh, 0.0, 1.0)) / float(KADAR)
		var naik: float = 1.0 - exp(-t * 300.0)
		var nada: float = (sin(fasa) + 0.28 * sin(fasa * 2.0)) * naik * exp(-t * 22.0)
		# Klik halus di awal supaya terasa seperti tanda diletak.
		var klik: float = randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.25
		s[i] = nada * 0.7 + klik
	_lulus_rendah(s, 7000.0)
	_normal(s, 0.85)
	return _ke_stream(s, false)

func _jana_rancang_gagal() -> AudioStreamWAV:
	var tempoh: float = 0.09
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var fasa: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		# "Tet" pendek: satu denyut yang terus putus, isyarat "tak boleh".
		fasa += TAU * 320.0 / float(KADAR)
		var naik: float = 1.0 - exp(-t * 900.0)
		var nada: float = (sin(fasa) + 0.30 * sin(fasa * 3.0)) * naik * exp(-t * 45.0)
		s[i] = nada * 0.6
	_lulus_rendah(s, 3200.0)
	_normal(s, 0.85)
	return _ke_stream(s, false)


# ---- Bunyi retak: struktur cedera tetapi belum pecah -----------------

func _jana_retak() -> AudioStreamWAV:
	var tempoh: float = 0.16
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	# Retak tajam: desir pendek yang ditapis pada dua badan kayu.
	var asas := PackedFloat32Array()
	asas.resize(n)
	for i in n:
		var t: float = float(i) / float(KADAR)
		asas[i] = randf_range(-1.0, 1.0) * exp(-t * 120.0)
	var b1: PackedFloat32Array = asas.duplicate()
	_lulus_jalur(b1, 900.0, 3.0)
	var b2: PackedFloat32Array = asas.duplicate()
	_lulus_jalur(b2, 1800.0, 2.0)
	var fasa: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		fasa += TAU * lerpf(180.0, 90.0, clampf(t / 0.1, 0.0, 1.0)) / float(KADAR)
		var dentum: float = sin(fasa) * exp(-t * 45.0) * 0.3
		s[i] = asas[i] * 0.7 + b1[i] * 1.8 + b2[i] * 1.1 + dentum
	_lulus_rendah(s, 9000.0)
	_normal(s, 0.9)
	return _ke_stream(s, false)


# ---- Bunyi klik butang menu: suis ditekan ----------------------------
# Sangat pendek (~0.07s) supaya menekan butang berturut-turut tidak bertindih.
func _jana_klik() -> AudioStreamWAV:
	var tempoh: float = 0.07
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var fasa: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		# Desir tajam yang reput pantas: rasa suis fizikal ditekan.
		var klik: float = randf_range(-1.0, 1.0) * exp(-t * 900.0) * 0.55
		# Nada rendah lembut sebagai badan bunyi.
		fasa += TAU * lerpf(640.0, 440.0, clampf(t / tempoh, 0.0, 1.0)) / float(KADAR)
		var nada: float = sin(fasa) * (1.0 - exp(-t * 700.0)) * exp(-t * 60.0) * 0.45
		s[i] = klik + nada
	_lulus_rendah(s, 6500.0)
	_normal(s, 0.7)
	return _ke_stream(s, false)

# ---- Bunyi menu perabot: satu tekstur per jenis -----------------------
# Pendek (~0.34s) supaya buka/tutup menu berulang kali tidak menggangu.

func _jana_menu(nama: String) -> AudioStreamWAV:
	var tempoh: float = 0.34
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	if nama == "menu_relau":
		# Relau: dentum logam berat + raungan api yang naik perlahan.
		_tambah_dentum(s, KADAR, 0.0, 150.0, 62.0, 0.30, 0.55, 14.0)
		var api := PackedFloat32Array()
		api.resize(n)
		for i in n:
			var ta: float = float(i) / float(KADAR)
			api[i] = randf_range(-1.0, 1.0) * (1.0 - exp(-ta * 26.0)) * exp(-ta * 7.0)
		_lulus_jalur(api, 650.0, 1.6)
		for i in n:
			s[i] += api[i] * 1.5
		_lulus_rendah(s, 3200.0)
	elif nama == "menu_fabrikasi":
		# Fabrikasi: klik geganti + motor servo yang menaik.
		_tambah_hitam(s, KADAR, 0.0, 0.05, 0.55)
		var fasa: float = 0.0
		for i in n:
			var tm: float = float(i) / float(KADAR)
			var maju: float = clampf(tm / 0.28, 0.0, 1.0)
			fasa += TAU * lerpf(170.0, 300.0, maju) / float(KADAR)
			var gigi: float = fposmod(fasa / TAU, 1.0) * 2.0 - 1.0
			s[i] += gigi * (1.0 - exp(-tm * 60.0)) * exp(-tm * 9.0) * 0.40
		_lulus_rendah(s, 5200.0)
	elif nama == "menu_dapur":
		# Dapur: dua denting seramik + ketukan kayu lembut.
		_tambah_dentum(s, KADAR, 0.0, 260.0, 155.0, 0.12, 0.40, 28.0)
		_tambah_nada(s, KADAR, 0.0, 1180.0, 0.30, 0.48, 15.0)
		_tambah_nada(s, KADAR, 0.035, 1760.0, 0.26, 0.30, 22.0)
		_lulus_rendah(s, 6800.0)
	elif nama == "menu_cas":
		# Stesen cas: dengung elektrik naik + percikan di hujung.
		var fasa_c: float = 0.0
		for i in n:
			var tc: float = float(i) / float(KADAR)
			var maju_c: float = clampf(tc / 0.26, 0.0, 1.0)
			fasa_c += TAU * lerpf(320.0, 520.0, maju_c) / float(KADAR)
			var getar: float = 0.55 + 0.45 * signf(sin(TAU * 46.0 * tc))
			s[i] += sin(fasa_c) * getar * (1.0 - exp(-tc * 70.0)) * exp(-tc * 8.0) * 0.45
		_tambah_hitam(s, KADAR, 0.16, 0.06, 0.35)
		_lulus_rendah(s, 5200.0)
	elif nama == "menu_solar":
		# Solar: kilau kaca tinggi + denyut lembut.
		var kaca := PackedFloat32Array()
		kaca.resize(n)
		for i in n:
			var tk: float = float(i) / float(KADAR)
			kaca[i] = randf_range(-1.0, 1.0) * (1.0 - exp(-tk * 80.0)) * exp(-tk * 11.0)
		_lulus_jalur(kaca, 4200.0, 3.0)
		for i in n:
			s[i] += kaca[i] * 1.7
		_tambah_nada(s, KADAR, 0.02, 1520.0, 0.30, 0.22, 12.0)
	elif nama == "menu_inverter":
		# Inverter: dengung kuasa rendah yang pudar + klik geganti.
		var fasa_i: float = 0.0
		for i in n:
			var ti: float = float(i) / float(KADAR)
			fasa_i += TAU * 98.0 / float(KADAR)
			var hum: float = sin(fasa_i) + 0.45 * sin(fasa_i * 2.0) + 0.22 * sin(fasa_i * 3.0)
			s[i] += hum * (1.0 - exp(-ti * 50.0)) * exp(-ti * 6.5) * 0.45
		_tambah_hitam(s, KADAR, 0.0, 0.04, 0.30)
		_lulus_rendah(s, 2000.0)
	elif nama == "menu_kajian":
		# Meja kajian: tiga bip digital menaik.
		_tambah_nada(s, KADAR, 0.0, 880.0, 0.10, 0.32, 26.0)
		_tambah_nada(s, KADAR, 0.06, 1180.0, 0.10, 0.30, 26.0)
		_tambah_nada(s, KADAR, 0.12, 1560.0, 0.16, 0.28, 20.0)
		_lulus_rendah(s, 7000.0)
	else:
		return null
	_normal(s, 0.85)
	return _ke_stream(s, false)

# ---- Bunyi tutup menu perabot: satu bunyi generik untuk semua menu -------
# Nada turun lembut + desir pendek (~0.2s), sama untuk semua perabot supaya
# bunyi "menu ditutup" konsisten.
func _jana_menu_tutup() -> AudioStreamWAV:
	var tempoh: float = 0.20
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var fasa: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		fasa += TAU * lerpf(640.0, 420.0, clampf(t / 0.16, 0.0, 1.0)) / float(KADAR)
		var sampul: float = (1.0 - exp(-t * 90.0)) * exp(-t * 22.0)
		s[i] += sin(fasa) * sampul * 0.55
		s[i] += sin(fasa * 2.0) * sampul * 0.16
	# Desir halus yang meluncur turun, macam menu ditutup.
	var desir := PackedFloat32Array()
	desir.resize(n)
	for i in n:
		var td: float = float(i) / float(KADAR)
		desir[i] = randf_range(-1.0, 1.0) * (1.0 - exp(-td * 60.0)) * exp(-td * 26.0)
	_lulus_jalur(desir, 1500.0, 1.4)
	for i in n:
		s[i] += desir[i] * 0.5
	_lulus_rendah(s, 4800.0)
	_normal(s, 0.85)
	return _ke_stream(s, false)
