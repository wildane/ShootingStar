extends "res://scene/level_3/build_system/BuildPreview.gd"
## Hologram preview Robot Pod. Imej pod diambil daripada fail PNG, jadi rupa
## preview sama tepat dengan perabot sebenar selepas dibina.

const TEKSTUR_POD: Texture2D = preload("res://scene/level_3/build_system/RobotPod/pod.png")

func _ready() -> void:
	# Tekstur disediakan SEBELUM BuildPreview._ready() mengira saiz UI bahan.
	if sprite:
		sprite.texture = TEKSTUR_POD
		sprite.scale = Vector2(0.25, 0.25)
	super._ready()


# Sprite pod diletak pada (0,-12) supaya lantai pod sejajar dengan Area2D.
# BuildPreview mengira posisi senarai bahan daripada saiz sprite sahaja, jadi
# tambah offset sprite itu semula.
func kemas_kini_posisi_ui() -> void:
	super.kemas_kini_posisi_ui()
	if is_instance_valid(bekas_ui_utama) and is_instance_valid(sprite):
		bekas_ui_utama.position += sprite.position
