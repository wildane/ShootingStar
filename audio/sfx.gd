# ==========================================================
# FAIL: sfx.gd
# Kesan bunyi yang dijana sepenuhnya dalam kod — TIADA fail aset,
# jadi tiada import editor diperlukan dan ia berfungsi dalam build
# export (iOS/Android) juga.
# Guna (dengan const Bunyi = preload("res://audio/sfx.gd")):
#   Bunyi.mainkan(self, "tembakan")
# ==========================================================
extends RefCounted

const KADAR: int = 22050
const PUNCAK: float = 32000.0

static var _cache: Dictionary = {}

# Bekas khas di bawah root scene tree. AudioStreamPlayer TIDAK boleh jadi
# anak kepada Node2D dalam game kerana spawner/save manager menyusun semula
# anak-anak itu guna global_position (akan picu ralat).
static var _bekas: Node = null

# Mainkan bunyi. `sumber` hanya digunakan untuk dapatkan SceneTree.
static func mainkan(sumber: Node, nama: String, isipadu_db: float = -6.0, pic: float = 1.0) -> void:
	if sumber == null:
		return
	if not sumber.is_inside_tree():
		return
	var pokok: SceneTree = sumber.get_tree()
	if pokok == null:
		return
	var stream: AudioStream = _ambil(nama)
	if stream == null:
		return
	var pemain := AudioStreamPlayer.new()
	pemain.stream = stream
	pemain.volume_db = isipadu_db
	pemain.pitch_scale = pic * randf_range(0.94, 1.06)
	_bekas_bunyi(pokok).add_child(pemain)
	pemain.finished.connect(pemain.queue_free)
	pemain.play()

static func _ambil(nama: String) -> AudioStream:
	var stream: AudioStream = _cache.get(nama)
	if stream != null:
		return stream
	stream = _jana(nama)
	if stream == null:
		return null
	_cache[nama] = stream
	return stream

static func _jana(nama: String) -> AudioStreamWAV:
	var tempoh: float = 0.0
	if nama == "tembakan":
		tempoh = 0.16
	elif nama == "lombong":
		tempoh = 0.22
	else:
		push_warning("Sfx: bunyi tidak dikenali - " + nama)
		return null

	print("SFX: jana bunyi ", nama, " (", tempoh, "s) - tiada aset diperlukan")
	var jumlah: int = maxi(1, int(KADAR * tempoh))
	var bait := PackedByteArray()
	bait.resize(jumlah * 2)
	var fasa: float = 0.0
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
			nilai = sin(fasa) * exp(-t * 22.0) * 0.9
			nilai += sin(TAU * 1500.0 * t) * exp(-t * 55.0) * 0.2
			nilai += randf_range(-1.0, 1.0) * exp(-t * 45.0) * 0.3
		nilai = clampf(nilai, -1.0, 1.0)
		# PCM 16-bit little-endian, ditulis terus ke byte array.
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

static func _bekas_bunyi(pokok: SceneTree) -> Node:
	if _bekas != null and is_instance_valid(_bekas) and _bekas.is_inside_tree():
		return _bekas
	_bekas = Node.new()
	_bekas.name = "BekasSFX"
	pokok.root.add_child(_bekas)
	return _bekas
