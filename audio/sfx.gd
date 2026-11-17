# ==========================================================
# FAIL: sfx.gd  (AUTOLOAD — nama singleton: Sfx)
# Kesan bunyi dijana sepenuhnya dalam kod: tiada fail aset dan tiada
# import editor diperlukan, jadi ia berfungsi dalam build telefon.
# Guna: Sfx.mainkan("tembakan", -7.0)
# ==========================================================
extends Node

const KADAR: int = 22050
const PUNCAK: float = 32000.0
const BILANGAN_PEMAIN: int = 4  # supaya bunyi boleh bertindih

var _pemain: Dictionary = {}
var _giliran: Dictionary = {}
# Untuk ujian: puncak sampel dan bilangan byte bukan sifar yang dijana.
var _puncak: Dictionary = {}
var _bukan_sifar: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sedia("tembakan", 0.16)
	_sedia("lombong", 0.22)
	print("SFX sedia: ", _pemain.keys())
	# UJIAN AUDIO: bunyi sekali setiap game mula + paparan status di skrin.
	# Buang blok ini bila bunyi dah disahkan keluar.
	await get_tree().create_timer(0.5).timeout
	mainkan("tembakan", -7.0)
	await get_tree().create_timer(0.15).timeout
	_papar_status_ujian()

# Paparan sementara untuk sahkan keadaan audio pada peranti.
func _papar_status_ujian() -> void:
	var pemain: AudioStreamPlayer = null
	if _pemain.has("tembakan"):
		var senarai: Array = _pemain["tembakan"]
		if not senarai.is_empty():
			pemain = senarai[0]
	var teks: String = "SFX ujian\n"
	if pemain and pemain.stream:
		teks += "panjang: " + str(snappedf(pemain.stream.get_length(), 0.01)) + "s\n"
	teks += "playing: " + str(pemain.playing if pemain else false) + "\n"
	teks += "bus: " + str(AudioServer.get_bus_count()) + " vol " + str(AudioServer.get_bus_volume_db(0))
	teks += " mute " + str(AudioServer.is_bus_mute(0)) + "\n"
	teks += "device: " + str(AudioServer.get_output_device()) + "\n"
	teks += "puncak: " + str(_puncak.get("tembakan", -1)) + "\n"
	teks += "byte bukan sifar: " + str(_bukan_sifar.get("tembakan", -1)) + " / " + str(pemain.stream.data.size() if pemain and pemain.stream else 0)
	teks += "\n(cuba volume media tinggi + silent off)"
	var label := Label.new()
	label.text = teks
	label.position = Vector2(8, 40)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(1, 1, 0))
	var lapisan := CanvasLayer.new()
	lapisan.add_child(label)
	get_tree().root.add_child(lapisan)
	await get_tree().create_timer(10.0).timeout
	lapisan.queue_free()

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
	var puncak: int = 0
	var bukan_sifar: int = 0
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
		if absi(v) > puncak:
			puncak = absi(v)
		if u != 0:
			bukan_sifar += 1
	_puncak[nama] = puncak
	_bukan_sifar[nama] = bukan_sifar

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = KADAR
	stream.stereo = false
	stream.data = bait
	return stream
