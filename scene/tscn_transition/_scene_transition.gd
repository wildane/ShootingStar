extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	# Pastikan skrin tidak hitam secara automatik semasa game bermula
	color_rect.modulate.a = 0

func tukar_scene(target_scene_path: String) -> void:
	# 1. Sekat input pemain semasa transition berlaku
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. Mainkan animasi skrin menjadi hitam
	animation_player.play("fade_to_black")
	await animation_player.animation_finished
	
	# 3. Tukar ke scene baharu di latar belakang
	get_tree().change_scene_to_file(target_scene_path)
	
	# 4. Mainkan animasi secara terbalik (skrin kembali cerah)
	animation_player.play_backwards("fade_to_black")
	await animation_player.animation_finished
	
	# 5. Buka semula sekatan input selepas selesai
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
