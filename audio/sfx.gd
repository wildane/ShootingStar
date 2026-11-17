# ==========================================================
# FAIL: sfx.gd
# Pemain kesan bunyi ringkas. Bunyi diambil dari fail .wav dalam
# folder audio/ dan dimainkan pada satu bekas khas bawah root.
# Guna (dengan const Bunyi = preload("res://audio/sfx.gd")):
#   Bunyi.mainkan(self, "tembakan")
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
	stream = load(laluan)
	if stream == null:
		push_warning("Sfx: gagal memuatkan " + laluan)
		return null
	_cache[nama] = stream
	return stream

static func _bekas_bunyi(pokok: SceneTree) -> Node:
	if _bekas != null and is_instance_valid(_bekas) and _bekas.is_inside_tree():
		return _bekas
	_bekas = Node.new()
	_bekas.name = "BekasSFX"
	pokok.root.add_child(_bekas)
	return _bekas
