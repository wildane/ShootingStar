# ==========================================================
# FAIL: sfx.gd
# Kesan bunyi ringkas yang dijana secara prosedur (tiada fail .wav
# diperlukan). Setiap bunyi dibina sekali dan di-cache.
# Guna: Sfx.mainkan(get_tree().current_scene, "tembakan")
# ==========================================================
class_name Sfx
extends RefCounted

const KADAR: int = 22050

static var _cache: Dictionary = {}

# Mainkan bunyi pada parent (biasanya get_tree().current_scene).
static func mainkan(parent: Node, nama: String, isipadu_db: float = -6.0, pic: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
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
	match nama:
		"tembakan":
			return _jana(0.13, _sampel_tembakan)
		"lombong":
			return _jana(0.20, _sampel_lombong)
	push_warning("Sfx: bunyi tidak dikenali - " + nama)
	return null

# Laser pendek: gelombang gigi gergaji menurun + desiran halus.
static func _sampel_tembakan(t: float, tempoh: float) -> float:
	var f: float = lerpf(1500.0, 320.0, t / tempoh)
	var fasa: float = TAU * f * t
	var nada: float = sin(fasa) * 0.7 + sin(fasa * 0.5) * 0.3
	var sampul: float = exp(-t * 22.0)
	var desir: float = randf_range(-1.0, 1.0) * exp(-t * 70.0) * 0.35
	return clampf((nada * sampul + desir) * 0.8, -1.0, 1.0)

# Ketukan batu: bunyi rendah "tok" + serpihan desiran.
static func _sampel_lombong(t: float, tempoh: float) -> float:
	var f: float = lerpf(260.0, 85.0, t / tempoh)
	var badan: float = sin(TAU * f * t) * exp(-t * 26.0)
	var petik: float = sin(TAU * 1450.0 * t) * exp(-t * 60.0) * 0.25
	var serpihan: float = randf_range(-1.0, 1.0) * exp(-t * 40.0) * 0.35
	return clampf(badan * 0.85 + petik + serpihan, -1.0, 1.0)

static func _jana(tempoh: float, penjana: Callable) -> AudioStreamWAV:
	var jumlah: int = maxi(1, int(KADAR * tempoh))
	var data := PackedByteArray()
	data.resize(jumlah * 2)
	for i in jumlah:
		var t: float = float(i) / KADAR
		var nilai: float = penjana.call(t, tempoh)
		data.encode_s16(i * 2, int(roundf(clampf(nilai, -1.0, 1.0) * 32000.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = KADAR
	stream.stereo = false
	stream.data = data
	return stream
