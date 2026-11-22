extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	# Pastikan skrin tidak hitam secara automatik semasa game bermula
	color_rect.modulate.a = 0

# Perisai hitam kekal (autoload, layer 1000) supaya tiada bingkai warna
# latar kelabu muncul semasa scene baharu dimuatkan.
func pasang_perisai() -> void:
	color_rect.modulate.a = 1.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

func pudar_ke_hitam(tempoh: float) -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, tempoh)
	await tween.finished

func buang_perisai() -> void:
	color_rect.modulate.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
