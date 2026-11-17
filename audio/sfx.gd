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

var _pemain: Dictionary = {}
var _giliran: Dictionary = {}
var _ambien: AudioStreamPlayer = null
var _muzik_bos: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sedia("tembakan")
	_sedia("lombong")
	_sedia("lendir")
	_sedia("letupan")
	_sedia("lendir_boss")
	_mula_ambien()
	_mula_muzik_bos()

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

# ---- Ambien ruang angkasa -------------------------------------------

# Muzik rancak semasa boss menyerang.
func muzik_bos(nyala: bool) -> void:
	if _muzik_bos == null:
		return
	if nyala:
		if not _muzik_bos.playing:
			_muzik_bos.play()
		# Ambien dimatikan sepenuhnya: pudar keluar dulu, baru stop.
		if _ambien and _ambien.playing:
			var pudar := create_tween()
			pudar.tween_property(_ambien, "volume_db", -40.0, 0.35)
			pudar.tween_callback(_ambien.stop)
	else:
		if _muzik_bos.playing:
			_muzik_bos.stop()
		# Balik ke ambien asal: hidupkan semula dan pudar masuk.
		if _ambien:
			_ambien.volume_db = -40.0
			_ambien.play()
			var masuk := create_tween()
			masuk.tween_property(_ambien, "volume_db", -13.0, 0.9)

func _mula_muzik_bos() -> void:
	var stream := _jana_rancak()
	if stream == null:
		return
	_muzik_bos = AudioStreamPlayer.new()
	_muzik_bos.stream = stream
	_muzik_bos.volume_db = -5.0
	_muzik_bos.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_muzik_bos)

func ambien_aktif(nyala: bool) -> void:
	if _ambien == null:
		return
	if nyala:
		_ambien.play()
	else:
		_ambien.stop()

func isipadu_ambien(db: float) -> void:
	if _ambien:
		_ambien.volume_db = db

func _mula_ambien() -> void:
	var stream := _jana_ambien()
	if stream == null:
		return
	_ambien = AudioStreamPlayer.new()
	_ambien.stream = stream
	_ambien.volume_db = -13.0
	_ambien.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambien)
	_ambien.play()

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
	var tempoh: float = 0.34
	var n: int = int(KADAR * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	var fasa: float = 0.0
	var fasa_logam: float = 0.0
	var serakah: float = 0.0
	for i in n:
		var t: float = float(i) / float(KADAR)
		# Ketukan rendah batu.
		var f: float = lerpf(230.0, 62.0, t / tempoh)
		fasa += TAU * f / float(KADAR)
		var dentum: float = sin(fasa) * exp(-t * 16.0) * 0.9
		# Bunyi kasar batu pecah (noise yang ditapis).
		serakah = serakah * 0.72 + randf_range(-1.0, 1.0) * 0.28
		var hancur: float = serakah * exp(-t * 34.0) * 1.1
		# Resonans logam kecil bila mata cangkul kena batu.
		fasa_logam += TAU * 1180.0 / float(KADAR)
		var logam: float = sin(fasa_logam) * exp(-t * 42.0) * 0.22
		# Serpihan kecil yang berterabur lepas ketukan.
		var serpihan: float = 0.0
		if randf() < 0.05 * exp(-t * 6.0):
			serpihan = randf_range(-1.0, 1.0) * 0.5
		s[i] = dentum * 0.7 + hancur * 0.55 + logam + serpihan
	_lulus_rendah(s, 3800.0)
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

func _jana_rancak() -> AudioStreamWAV:
	var kadar: int = KADAR_AMBIEN
	var bpm: float = 140.0
	var ketuk: float = 60.0 / bpm
	var bil_ketuk: int = 8
	var tempoh: float = ketuk * bil_ketuk
	var n: int = int(kadar * tempoh)
	var s := PackedFloat32Array()
	s.resize(n)
	# Garis bass mengikut corak 8 ketukan (A minor).
	var bass := [55.0, 55.0, 65.41, 49.0, 55.0, 55.0, 73.42, 65.41]
	# Melodi pendek pada off-beat.
	var arp := [220.0, 261.63, 329.63, 261.63, 220.0, 261.63, 392.0, 329.63]
	for b in bil_ketuk:
		var mula: float = float(b) * ketuk
		# Tendangan pada setiap ketuk.
		_tambah_dentum(s, kadar, mula, 150.0, 52.0, 0.24, 0.55, 16.0)
		# Bass.
		_tambah_nada(s, kadar, mula, bass[b], 0.30, 0.30, 7.0)
		# Hi-hat pada separuh ketuk.
		_tambah_hitam(s, kadar, mula, 0.06, 0.16)
		_tambah_hitam(s, kadar, mula + ketuk * 0.5, 0.06, 0.12)
		# Melodi pada off-beat.
		_tambah_nada(s, kadar, mula + ketuk * 0.5, arp[b], 0.16, 0.12, 12.0)
	_normal(s, 0.95)
	return _ke_stream(s, true, kadar)
