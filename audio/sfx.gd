# ==========================================================
# FAIL: sfx.gd
# Kesan bunyi ringkas yang dijana secara prosedur (tiada fail .wav
# diperlukan). Setiap bunyi dibina sekali dan di-cache.
# Guna (dengan const Bunyi = preload("res://audio/sfx.gd")):
#   Bunyi.mainkan(get_parent(), "tembakan")
# ==========================================================
extends RefCounted

const KADAR: int = 22050
const KUAT: float = 32000.0

static var _cache: Dictionary = {}

# Mainkan bunyi pada parent (biasanya get_parent() atau current_scene).
static func mainkan(parent: Node, nama: String, isipadu_db: float = -6.0, pic: float = 1.0) -> void:
	if parent == null:
		return
	if not parent.is_inside_tree():
		return
	var stream: AudioStreamWAV = _cache.get(nama)
	if stream == null:
		stream = _buat(nama)
		if stream == null:
			return
		_cache[nama] = stream
	var pemain := AudioStreamPlayer.new()
	pemain.stream = stream
	pemain.volume_db = isipadu_db
	pemain.pitch_scale = pic * randf_range(0.94, 1.06)
	parent.add_child(pemain)
	pemain.finished.connect(pemain.queue_free)
	pemain.play()

static func _buat(nama: String) -> AudioStreamWAV:
	var tempoh: float = 0.0
	if nama == "tembakan":
		tempoh = 0.13
	elif nama == "lombong":
		tempoh = 0.20
	else:
		push_warning("Sfx: bunyi tidak dikenali - " + nama)
		return null

	var jumlah: int = maxi(1, int(KADAR * tempoh))
	var data := PackedByteArray()
	data.resize(jumlah * 2)
	for i in jumlah:
		var t: float = float(i) / float(KADAR)
		var nilai: float = 0.0
		if nama == "tembakan":
			# Laser: frekuensi turun 1500 -> 320 Hz + desiran halus.
			var f: float = lerpf(1500.0, 320.0, t / tempoh)
			var fasa: float = TAU * f * t
			var nada: float = sin(fasa) * 0.7 + sin(fasa * 0.5) * 0.3
			nilai = nada * exp(-t * 22.0) + randf_range(-1.0, 1.0) * exp(-t * 70.0) * 0.35
		else:
			# Ketukan batu: "tok" rendah 260 -> 85 Hz + serpihan.
			var f2: float = lerpf(260.0, 85.0, t / tempoh)
			var badan: float = sin(TAU * f2 * t) * exp(-t * 26.0) * 0.85
			var petik: float = sin(TAU * 1450.0 * t) * exp(-t * 60.0) * 0.25
			nilai = badan + petik + randf_range(-1.0, 1.0) * exp(-t * 40.0) * 0.35
		nilai = clampf(nilai, -1.0, 1.0)
		# Tulis PCM 16-bit little-endian secara manual (tanpa encode_s16).
		var v: int = int(roundf(nilai * KUAT))
		v = clampi(v, -32768, 32767)
		if v < 0:
			v += 65536
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = KADAR
	stream.stereo = false
	stream.data = data
	return stream
