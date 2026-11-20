extends "res://scene/level_3/build_system/BuildPreview.gd"
## Hologram preview Robot Pod. Imej pod dijana secara vektor oleh RekaPod.gd,
## jadi tiada fail PNG diperlukan dan ikon kekal tajam pada semua saiz.

const SkripReka := preload("res://scene/level_3/build_system/RobotPod/RekaPod.gd")

func _ready() -> void:
	# Tekstur disediakan SEBELUM BuildPreview._ready() mengira saiz UI bahan.
	if sprite:
		sprite.texture = SkripReka.buat_ikon(160)
		sprite.scale = Vector2(0.25, 0.25)
	super._ready()
