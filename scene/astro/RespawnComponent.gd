extends Node

@export_group("Respawn Configuration")
@export var respawn_position: Vector2 = Vector2(141.0, 198.0) 

@export_group("Respawn Visual Settings")
@export var fade_out_duration: float = 2.0  # Masa skrin bertukar gelap (2 saat)
@export var fade_in_duration: float = 2.0   # Masa skrin kembali cerah (2 saat)

@onready var player: CharacterBody2D = get_parent()

# Menyimpan rujukan komponen untuk diproses selepas butang ditekan
var _cached_health_component: Node = null
var _cached_target_sprite: Node2D = null
var _canvas_layer: CanvasLayer = null
var _black_screen: ColorRect = null
var _menu_container: VBoxContainer = null
var _respawn_button: Button = null  # Simpan rujukan butang ke global variable

# 🛡️ PENGANWAL KESELAMATAN: Menghalang fungsi utama dipanggil bertindih
var _is_respawning: bool = false

func execute_player_respawn(health_component: Node, target_sprite: Node2D) -> void:
	if not is_instance_valid(player): return
	
	# 🛑 SEKATAN 1: Jika proses respawn sedang berjalan, abaikan panggilan baru
	if _is_respawning: return
	_is_respawning = true
	
	# Simpan rujukan ke dalam cache pembolehubah
	_cached_health_component = health_component
	_cached_target_sprite = target_sprite
	
	print("RESPAWN SYSTEM: Memulakan fasa peralihan skrin gelap (2 Saat)...")
	
	# 1. CIPTA LAPISAN GHAIB UNTUK ANTARAMUKA KEMATIAN
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	
	# Skrin hitam penuh
	_black_screen = ColorRect.new()
	_black_screen.color = Color(0, 0, 0, 0)
	_black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_black_screen)
	
	# Bekas susunan menegak (VBoxContainer) diletaktan di tengah skrin
	_menu_container = VBoxContainer.new()
	_menu_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu_container.modulate.a = 0.0 # Mula dengan ghaib
	_menu_container.theme_type_variation = "VBoxContainer"
	_menu_container.add_theme_constant_override("separation", 20) # Jarak antara teks dan butang
	_canvas_layer.add_child(_menu_container)
	
	# Cipta Teks "YOU HAVE DIED"
	var death_label = Label.new()
	death_label.text = "YOU HAVE DIED"
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 28)
	death_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1, 1.0)) 
	_menu_container.add_child(death_label)
	
	# Cipta Butang "RESPAWN"
	_respawn_button = Button.new()
	_respawn_button.text = "  RESPAWN  "
	_respawn_button.custom_minimum_size = Vector2(200, 50)
	_respawn_button.add_theme_font_size_override("font_size", 20)
	
	# ⚡ PENTING: Kunci butang siap-siap semasa ia halimunan! Pemain tak boleh tekan.
	_respawn_button.disabled = true
	_respawn_button.focus_mode = Control.FOCUS_NONE  # Halang daripada auto-focus keyboard/controller
	
	_respawn_button.pressed.connect(_on_respawn_pressed)
	_menu_container.add_child(_respawn_button)
	
	# Masukkan keseluruhan UI ke dalam Scene Utama
	get_tree().current_scene.add_child(_canvas_layer)
	
	# 2. FASA SKRIN BERTUKAR GELAP PERLAHAN (FADE OUT - 2 SAAT)
	var fade_tween = create_tween()
	fade_tween.tween_property(_black_screen, "color:a", 1.0, fade_out_duration)
	await fade_tween.finished
	
	# 3. PAPARKAN MENU TEKS DAN BUTANG SECARA PUDAR LEMBUT
	var menu_tween = create_tween()
	menu_tween.tween_property(_menu_container, "modulate:a", 1.0, 0.4)
	await menu_tween.finished  # Tunggu menu muncul sepenuhnya dahulu
	
	# 🔓 BUKA KUNCI BUTANG: Dah habis gelap dan menu dah keluar, barulah boleh ditekan!
	if is_instance_valid(_respawn_button):
		_respawn_button.disabled = false
		_respawn_button.focus_mode = Control.FOCUS_ALL
		print("RESPAWN SYSTEM: Menu sedia. Butang diaktifkan untuk klik.")

# FUNGSI YANG DIPANGGIL APABILA PEMAIN KLIK BUTANG "RESPAWN"
func _on_respawn_pressed() -> void:
	print("RESPAWN SYSTEM: Butang ditekan. Memulakan fasa teleportasi...")
	
	# ⚡ SEKATAN KEDUA: Lepas tekan je, terus disable semula serta-merta!
	if is_instance_valid(_respawn_button):
		_respawn_button.disabled = true
		
	# --- FASA GHAIB: TELEPORT KE (141, 198) & RESET DATA PLAYER ---
	player.global_position = respawn_position
	
	if is_instance_valid(_cached_health_component):
		_cached_health_component.hp = _cached_health_component.max_hp
		_cached_health_component.is_dead = false
		
	if is_instance_valid(_cached_target_sprite):
		_cached_target_sprite.modulate = Color.WHITE
		_cached_target_sprite.modulate.a = 1.0
		
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO
		player.set_collision_layer_value(1, true)
		player.set_collision_mask_value(1, true)
		
	# Tunggu 0.2 saat dalam gelap selepas teleport untuk keselesaan visual pemain
	await get_tree().create_timer(0.2).timeout
	
	# Padam bekas menu (teks & butang) selepas fasa teleportasi selesai
	if is_instance_valid(_menu_container):
		_menu_container.queue_free()
	
	# 4. FASA SKRIN KEMBALI CERAH PERLAHAN (FADE IN - 2 SAAT)
	if is_instance_valid(_black_screen):
		var bright_tween = create_tween()
		bright_tween.tween_property(_black_screen, "color:a", 0.0, fade_in_duration)
		await bright_tween.finished
	
	# Re-aktifkan pemprosesan logik dan kawalan input player selepas skrin cerah sepenuhnya
	player.set_physics_process(true)
	player.set_process(true)
	
	# 5. BERSIHKAN LAPISAN UI DARI MEMORI
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
		
	# Buka semula pintu sekatan keselamatan utama
	_is_respawning = false
	print("RESPAWN SYSTEM: Fasa kelahiran semula selesai sepenuhnya!")
