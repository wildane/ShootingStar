# ==========================================================
# FAIL: sfx.gd  (AUTOLOAD — nama singleton: Sfx)
# Kesan bunyi dijana sepenuhnya dalam kod: tiada fail aset dan tiada
# import editor diperlukan, jadi ia berfungsi dalam build telefon.
# Guna: Sfx.mainkan("tembakan", -7.0)
#
# Nota iPhone: Xogot/Godot guna sesi audio yang dihenyak oleh suis
# senyap (silent mode), jadi bunyi hanya keluar bila silent dimatikan.
# ==========================================================
extends Node

const KADAR: int = 22050
const PUNCAK: float = 32000.0
const BILANGAN_PEMAIN: int = 4  # supaya bunyi boleh bertindih

var _pemain: Dictionary = {}
var _giliran: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sedia("tembakan", 0.16)
	_sedia("lombong", 0.22)

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

func _sedia(nama: String, tempoh: float) -> void:
	var stream := _jana(nama, tempoh)
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

func _jana(nama: String, tempoh: float) -> AudioStreamWAV:
	var jumlah: int = maxi(1, int(KADAR * tempoh))
	var bait := PackedByteArray()
	bait.resize(jumlah * 2)
	var fasa: float = 0.0
	var fasa_petik: float = 0.0
	for i in jumlah:
		var t: float = float(i) / float(KADAR)
		var nilai: float = 0.0
		if nama == "tembakan":
			# Laser: frekuensi turun 1600 -> 300 Hz, pendek dan tajam.
			var f: float = lerpf(1600.0, 300.0, t / tempoh)
			fasa += TAU * f / float(KADAR)
			nilai = (sin(fasa) * 0.75 + sin(fasa * 0.5) * 0.25) * exp(-t * 18.0)
			nilai += randf_range(-1.0, 1.0) * exp(-t * 80.0) * 0.3
		else:
			# Ketukan batu: "tok" rendah 300 -> 90 Hz + petikan + serpihan.
			var f2: float = lerpf(300.0, 90.0, t / tempoh)
			fasa += TAU * f2 / float(KADAR)
			fasa_petik += TAU * 1500.0 / float(KADAR)
			nilai = sin(fasa) * exp(-t * 22.0) * 0.9
			nilai += sin(fasa_petik) * exp(-t * 55.0) * 0.2
			nilai += randf_range(-1.0, 1.0) * exp(-t * 45.0) * 0.3
		nilai = clampf(nilai, -1.0, 1.0)
		# PCM 16-bit little-endian.
		var v: int = clampi(int(roundf(nilai * PUNCAK)), -32768, 32767)
		var u: int = v
		if u < 0:
			u += 65536
		bait[i * 2] = u & 0xFF
		bait[i * 2 + 1] = (u >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = KADAR
	stream.stereo = false
	stream.data = bait
	return stream
