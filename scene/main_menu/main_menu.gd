extends CanvasLayer

# 🛠️ PEMBOLEHUBAH EXPORT (Sila tarik fail level_3.tscn asli ke petak ini di Inspector)
@export var scene_sasaran: PackedScene
@export var tempoh_menunggu: float = 2.0      # Masa terpapar di menu sebelum mula fade (saat)
@export var tempoh_fade_in: float = 3.0       # Kelajuan skrin menu ditutup hitam (saat)

var overlay_hitam: ColorRect

func _ready() -> void:
	layer = 100
	
	# 1. Bina lapisan hitam
	bina_overlay_loading()
	
	# 2. Tunggu di menu seketika sebelum memulakan transisi hitam
	print("[MainMenu] Menunggu di skrin menu...")
	await get_tree().create_timer(tempoh_menunggu).timeout
	
	# 3. Mulakan kesan Fade In hitam
	mulakan_fade_in()

func bina_overlay_loading() -> void:
	overlay_hitam = ColorRect.new()
	overlay_hitam.color = Color(0, 0, 0, 0) # Mula lutsinar
	overlay_hitam.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_hitam.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay_hitam)

func mulakan_fade_in() -> void:
	print("[MainMenu] Memulakan kesan Fade In hitam...")
	var tween = create_tween()
	tween.tween_property(overlay_hitam, "color:a", 1.0, tempoh_fade_in)
	await tween.finished
	
	tukar_scene_di_sebalik_tabir()

func tukar_scene_di_sebalik_tabir() -> void:
	if scene_sasaran:
		var main_loop = Engine.get_main_loop() as SceneTree
		if not main_loop: return
		
		print("[MainMenu] Menukar scene ke level_3...")
		
		# 1. Cabut overlay_hitam daripada menu utama supaya tidak dipadam secara automatik
		if is_instance_valid(overlay_hitam):
			if overlay_hitam.get_parent():
				overlay_hitam.get_parent().remove_child(overlay_hitam)
			
			# 2. Letakkan di dalam Autoload SceneTransition (supaya kekal hidup merentasi pertukaran scene)
			SceneTransition.add_child(overlay_hitam)
			
			# 3. Beri tag nama pada overlay ini supaya mudah dipanggil oleh level_3 nanti
			overlay_hitam.name = "PerisaiHitamMenu"
		
		# 4. Tukar scene secara rasmi
		main_loop.change_scene_to_packed(scene_sasaran)
		
		# 5. Padam komponen butang/skrip menu utama yang lain (Overlay hitam selamat di Autoload)
		queue_free()
	else:
		print("[Ralat MainMenu] scene_sasaran kosong! Sila seret fail level_3.tscn ke Inspector.")
