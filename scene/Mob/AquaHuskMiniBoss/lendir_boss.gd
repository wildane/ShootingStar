extends Area2D

# ==========================================================
# LENDIR BOSS - projektil khas AquaHuskMiniBoss
#
# Beza dari lendir HuskLurker (jarak dekat, hijau):
#   - Terbang JAUH dan pantas
#   - Berpusing + denyut kuat, ada glow merah sendiri
#   - Meninggalkan trail titisan meleleh
#   - Pecah dengan lingkaran kejutan merah
# ==========================================================

@export var kelajuan: float = 170.0
@export var jarak_maksimum: float = 460.0
@export var hayat: float = 4.0
@export var kerosakan: int = 2

@export_group("Kesan Pecah")
@export var bilangan_cebisan: int = 9
@export var jarak_cebisan: float = 30.0
@export var warna_cebisan: Color = Color(1.0, 0.34, 0.28)

@export_group("Trail")
@export var aktif_trail: bool = true
@export var selang_trail: float = 0.055
@export var warna_trail: Color = Color(0.95, 0.24, 0.2)

var arah: Vector2 = Vector2.RIGHT
var jarak_dilalui: float = 0.0
var masa_hidup: float = 0.0
var sudah_pecah: bool = false
var jam_trail: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow: Node2D = $Glow

var skala_sprite_asas: Vector2 = Vector2(0.55, 0.55)
var skala_glow_asas: Vector2 = Vector2.ONE

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Ambil skala dari scene supaya nilai dalam .tscn jadi rujukan tunggal
	if sprite:
		skala_sprite_asas = sprite.scale
	if glow:
		skala_glow_asas = glow.scale

func tembak(hala: Vector2, dmg: int = 2) -> void:
	Sfx.mainkan("lendir_boss", -8.0)
	arah = hala.normalized()
	kerosakan = dmg
	rotation = arah.angle()

func _physics_process(delta: float) -> void:
	if sudah_pecah:
		return

	var langkah: float = kelajuan * delta
	global_position += arah * langkah
	jarak_dilalui += langkah
	masa_hidup += delta

	# Denyut kuat + kilau teras
	if sprite:
		var denyut: float = 1.0 + sin(masa_hidup * 18.0) * 0.16
		sprite.scale = skala_sprite_asas * denyut
	if glow:
		glow.scale = skala_glow_asas * (1.0 + sin(masa_hidup * 9.0) * 0.12)

	# Trail titisan meleleh
	if aktif_trail:
		jam_trail -= delta
		if jam_trail <= 0.0:
			jam_trail = selang_trail
			_buat_trail()

	if jarak_dilalui >= jarak_maksimum or masa_hidup >= hayat:
		_pecah()

func _on_body_entered(body: Node) -> void:
	if sudah_pecah or not is_instance_valid(body):
		return

	# Jangan cedera sesama sendiri
	if body.is_in_group("enemy") or body.is_in_group("enemies"):
		return

	# Dinding / objek pejal -> pecah
	if body is StaticBody2D:
		_pecah()
		return

	if body.has_node("HealthComponent"):
		var hc = body.get_node("HealthComponent")
		if hc.has_method("take_damage"):
			hc.take_damage(kerosakan)
			print("LendirBoss: kena player! (-", kerosakan, " hp)")
			_pecah()
			return

	if body.has_method("take_damage"):
		body.take_damage(kerosakan)
		print("LendirBoss: kena player! (-", kerosakan, " hp)")
		_pecah()
		return

	if "health" in body:
		body.health -= kerosakan
		print("LendirBoss: kena player! (-", kerosakan, " hp)")
		_pecah()

# --- TRAIL: titisan merah yang pudar ---
func _buat_trail() -> void:
	var induk := get_parent()
	if induk == null:
		return

	var titis := Sprite2D.new()
	if sprite and sprite.texture:
		titis.texture = sprite.texture
	titis.z_index = z_index - 1
	titis.modulate = Color(warna_trail.r, warna_trail.g, warna_trail.b, 0.55)
	induk.add_child(titis)
	titis.global_position = global_position
	titis.global_rotation = 0.0
	var saiz: float = randf_range(0.2, 0.38)
	titis.scale = Vector2(saiz, saiz)

	var tw := titis.create_tween().set_parallel(true)
	tw.tween_property(titis, "scale", Vector2(0.03, 0.03), 0.34)
	tw.tween_property(titis, "modulate:a", 0.0, 0.34)
	tw.chain().tween_callback(titis.queue_free)

# --- SPLAT: blob kembang + lingkaran kejutan + cebisan terbang ---
func _pecah() -> void:
	if sudah_pecah:
		return
	sudah_pecah = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)

	if sprite:
		sprite.global_rotation = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sprite, "scale", sprite.scale * 1.8, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.32)

	if glow:
		var twg := create_tween().set_parallel(true)
		twg.tween_property(glow, "scale", Vector2.ONE * 2.6, 0.18)
		twg.tween_property(glow, "modulate:a", 0.0, 0.18)

	_buat_lingkaran_kejutan()

	for i in range(bilangan_cebisan):
		_buat_cebisan(i)

	await get_tree().create_timer(0.38).timeout
	if is_instance_valid(self):
		queue_free()

func _buat_lingkaran_kejutan() -> void:
	var induk := get_parent()
	if induk == null:
		return

	var gelang := Sprite2D.new()
	if sprite and sprite.texture:
		gelang.texture = sprite.texture
	gelang.z_index = z_index - 1
	gelang.modulate = Color(warna_cebisan.r, warna_cebisan.g, warna_cebisan.b, 0.5)
	induk.add_child(gelang)
	gelang.global_position = global_position
	gelang.global_rotation = 0.0
	gelang.scale = Vector2(0.5, 0.5)

	var tw := gelang.create_tween().set_parallel(true)
	tw.tween_property(gelang, "scale", Vector2(2.1, 2.1), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(gelang, "modulate:a", 0.0, 0.26)
	tw.chain().tween_callback(gelang.queue_free)

func _buat_cebisan(indeks: int) -> void:
	if sprite == null or sprite.texture == null:
		return

	var induk := get_parent()
	if induk == null:
		return

	var cebisan := Sprite2D.new()
	cebisan.texture = sprite.texture
	cebisan.z_index = z_index
	induk.add_child(cebisan)
	cebisan.global_position = global_position
	cebisan.global_rotation = 0.0

	var saiz_awal: float = randf_range(0.16, 0.38)
	cebisan.scale = Vector2(saiz_awal, saiz_awal)

	# Semburan ke belakang + serakan bulat
	var sudut_sisi: float = (TAU / float(max(1, bilangan_cebisan))) * float(indeks)
	var serakan: Vector2 = Vector2.RIGHT.rotated(sudut_sisi) * randf_range(0.5, 1.0)
	var hala: Vector2 = (-arah * 0.5 + serakan).normalized()
	var jarak: float = randf_range(jarak_cebisan * 0.4, jarak_cebisan)

	var tw := cebisan.create_tween().set_parallel(true)
	tw.tween_property(cebisan, "global_position", global_position + hala * jarak, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cebisan, "scale", Vector2(0.03, 0.03), 0.34)
	tw.tween_property(cebisan, "modulate:a", 0.0, 0.34)
	tw.chain().tween_callback(cebisan.queue_free)
