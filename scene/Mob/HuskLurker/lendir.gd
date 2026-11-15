extends Area2D

# ==========================================================
# LENDIR - projektil Husk Lurker (jarak dekat)
# Terbang lurus jarak pendek, lepas tu PECAH jadi cebisan lendir.
# ==========================================================

@export var kelajuan: float = 125.0
@export var jarak_maksimum: float = 115.0
@export var hayat: float = 2.0
@export var kerosakan: int = 1

@export_group("Kesan Pecah")
@export var bilangan_cebisan: int = 6
@export var jarak_cebisan: float = 22.0

var arah: Vector2 = Vector2.RIGHT
var jarak_dilalui: float = 0.0
var masa_hidup: float = 0.0
var sudah_pecah: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func tembak(hala: Vector2, dmg: int = 1) -> void:
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

	# Denyut kecil semasa terbang
	if sprite:
		var denyut: float = 1.0 + sin(masa_hidup * 22.0) * 0.12
		sprite.scale = Vector2(0.5, 0.5) * denyut

	if jarak_dilalui >= jarak_maksimum or masa_hidup >= hayat:
		_pecah()

func _on_body_entered(body: Node) -> void:
	if sudah_pecah or not is_instance_valid(body):
		return

	# Jangan cedera sesama sendiri
	if body.is_in_group("enemy") or body.is_in_group("enemies"):
		return

	# Dinding / objek pejal -> lendir pecah
	if body is StaticBody2D:
		_pecah()
		return

	if body.has_node("HealthComponent"):
		var hc = body.get_node("HealthComponent")
		if hc.has_method("take_damage"):
			hc.take_damage(kerosakan)
			print("Lendir: kena player! (-", kerosakan, " hp)")
			_pecah()
			return

	if body.has_method("take_damage"):
		body.take_damage(kerosakan)
		print("Lendir: kena player! (-", kerosakan, " hp)")
		_pecah()
		return

	if "health" in body:
		body.health -= kerosakan
		print("Lendir: kena player! (-", kerosakan, " hp)")
		_pecah()

# --- SPLAT: blob kembang, pudar, + cebisan terbang ---
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
		tw.tween_property(sprite, "scale", sprite.scale * 1.7, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.3)

	for i in range(bilangan_cebisan):
		_buat_cebisan(i)

	await get_tree().create_timer(0.34).timeout
	if is_instance_valid(self):
		queue_free()

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

	# Saiz rawak kecil
	var saiz_awal: float = randf_range(0.12, 0.3)
	cebisan.scale = Vector2(saiz_awal, saiz_awal)

	# Arah semburan: ke belakang sedikit (pantulan) + serakan ke semua arah
	var sudut_sisi: float = (TAU / float(max(1, bilangan_cebisan))) * float(indeks)
	var serakan: Vector2 = Vector2.RIGHT.rotated(sudut_sisi) * randf_range(0.45, 1.0)
	var hala: Vector2 = (-arah * 0.55 + serakan).normalized()
	var jarak: float = randf_range(jarak_cebisan * 0.4, jarak_cebisan)

	var tw := cebisan.create_tween().set_parallel(true)
	tw.tween_property(cebisan, "global_position", global_position + hala * jarak, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cebisan, "scale", Vector2(0.02, 0.02), 0.3)
	tw.tween_property(cebisan, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(cebisan.queue_free)
