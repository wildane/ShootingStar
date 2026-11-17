# ==========================================================
# FAIL: sfx.gd
# Pemain kesan bunyi ringkas. Bunyi diambil dari fail .wav dalam
# folder audio/ dan dimainkan pada satu bekas khas bawah root.
# Guna (dengan const Bunyi = preload("res://audio/sfx.gd")):
#   Bunyi.mainkan(self, "tembakan")
#
# Nota: kalau editor Godot belum import .wav (tiada fail .import),
# load() akan gagal. Kod ini akan baca PCM terus dari fail sebagai
# ganti supaya bunyi tetap keluar walaupun belum di-import.
# ==========================================================
extends RefCounted

const LALUAN := {
	"tembakan": "res://audio/tembakan.wav",
	"lombong": "res://audio/lombong.wav",
}

static var _cache: Dictionary = {}

# Bekas khas di bawah root scene tree. AudioStreamPlayer TIDAK boleh jadi
# anak kepada Node2D dalam game kerana spawner/save manager menyusun semula
# anak-anak itu guna global_position (bunyi akan picu ralat).
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
	var laluan: String = LALUAN.get(nama, "")
	if laluan == "":
		push_warning("Sfx: bunyi tidak dikenali - " + nama)
		return null
	if ResourceLoader.exists(laluan):
		stream = load(laluan)
	if stream == null:
		stream = _baca_wav_mentah(laluan)
	if stream == null:
		push_warning("Sfx: gagal memuatkan " + laluan)
		return null
	_cache[nama] = stream
	return stream

# Baca fail WAV PCM 16-bit terus dari cakera (tak perlu import editor).
static func _baca_wav_mentah(laluan: String) -> AudioStreamWAV:
	var bait := FileAccess.get_file_as_bytes(laluan)
	if bait.size() < 44:
		return null
	if bait.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var kadar: int = 22050
	var saluran: int = 1
	var i: int = 12
	while i + 8 <= bait.size():
		var id: String = bait.slice(i, i + 4).get_string_from_ascii()
		var saiz: int = bait.decode_u32(i + 4)
		if id == "fmt " and i + 16 <= bait.size():
			saluran = bait.decode_u16(i + 10)
			kadar = bait.decode_u32(i + 12)
		elif id == "data":
			var akhir: int = mini(i + 8 + saiz, bait.size())
			if akhir <= i + 8:
				return null
			var stream := AudioStreamWAV.new()
			stream.format = AudioStreamWAV.FORMAT_16_BITS
			stream.mix_rate = kadar
			stream.stereo = saluran == 2
			stream.data = bait.slice(i + 8, akhir)
			return stream
		i += 8 + saiz + (saiz & 1)
	return null

static func _bekas_bunyi(pokok: SceneTree) -> Node:
	if _bekas != null and is_instance_valid(_bekas) and _bekas.is_inside_tree():
		return _bekas
	_bekas = Node.new()
	_bekas.name = "BekasSFX"
	pokok.root.add_child(_bekas)
	return _bekas
