extends Sprite2D

# ==========================================
# GLOW PERISAI MAGNETIK (IKUT BENTUK PEMAIN)
# ==========================================
# Node ini diurus oleh HealthComponent. Ia menyalin tekstur, frame dan
# transform sprite pemain yang sedang kelihatan (SpriteAngkasa semasa di
# angkasa, SpriteBase semasa di pangkalan), kemudian shader melukis cahaya
# di luar siluet sprite itu sahaja. Jadi glow betul-betul mengikut bentuk
# kapal, bukan bulatan atau petak.

const BAHAN_GLOW: Shader = preload("res://scene/astro/shield_glow.gdshader")
const LEBAR_GLOW_SKRIN: float = 2.0  # piksel skrin
const WARNA_GLOW := Color(0.30, 0.90, 1.0, 1.0)

# Dikawal HealthComponent: glow hanya dipaparkan selagi stok shield ada.
var aktif: bool = false

var _masa: float = 0.0
var _kilat: float = 0.0
var _bahan: ShaderMaterial

func _ready() -> void:
	_bahan = ShaderMaterial.new()
	_bahan.shader = BAHAN_GLOW
	_bahan.set_shader_parameter("warna_glow", WARNA_GLOW)
	material = _bahan
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	visible = false

func _process(delta: float) -> void:
	_masa += delta
	_kilat = maxf(_kilat - delta * 2.5, 0.0)
	_salin_sprite_aktif()

# Dipanggil HealthComponent bila stok shield mula/habis.
func set_aktif(nilai: bool) -> void:
	aktif = nilai
	visible = nilai and _cari_sprite_aktif() != null

# Dipanggil setiap kali serangan diserap: glow menyala sekejap.
func kilat() -> void:
	_kilat = 1.0

# Salin bentuk sprite pemain yang sedang kelihatan.
func _salin_sprite_aktif() -> void:
	var sumber := _cari_sprite_aktif()
	if not aktif or sumber == null:
		visible = false
		return
	visible = true

	texture = sumber.texture
	hframes = sumber.hframes
	vframes = sumber.vframes
	frame = sumber.frame
	frame_coords = sumber.frame_coords
	centered = sumber.centered
	offset = sumber.offset
	flip_h = sumber.flip_h
	flip_v = sumber.flip_v
	position = sumber.position
	scale = sumber.scale
	rotation = sumber.rotation

	_kemas_kini_kilauan()

func _kemas_kini_kilauan() -> void:
	if _bahan == null:
		return
	var skala: float = absf(scale.x)
	if skala <= 0.0:
		skala = 0.03
	# Lebar glow dalam piksel tekstur supaya saiz di skrin kekal ~2 piksel.
	_bahan.set_shader_parameter("lebar_glow", LEBAR_GLOW_SKRIN / skala)
	var denyut := sin(_masa * 4.0) * 0.15
	_bahan.set_shader_parameter("keamatan", (1.0 + denyut) * (1.0 + 1.5 * _kilat))

# Sprite pemain yang kelihatan sekarang (Angkasa atau Base).
func _cari_sprite_aktif() -> Sprite2D:
	var pemain: Node = get_parent()
	if pemain == null:
		return null
	var terjumpa: Sprite2D = null
	for anak in pemain.get_children():
		if anak is Sprite2D and anak != self:
			var sprite: Sprite2D = anak as Sprite2D
			if sprite.visible and sprite.texture != null:
				terjumpa = sprite
	return terjumpa
