extends Node2D

func _ready() -> void:
	# Tunggu satu kerangka enjin untuk memastikan semua sistem sedia
	await get_tree().process_frame
	
	# Matikan rupa grafik DAN bekukan semua kod latar belakang BaseScene
	if has_node("/root/BaseScene"):
		var base_scene = get_node("/root/BaseScene")
		base_scene.visible = false
		base_scene.process_mode = PROCESS_MODE_DISABLED
