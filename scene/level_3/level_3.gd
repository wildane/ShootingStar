extends Node2D

var player_scene = preload("res://scene/astro/astro2.tscn")
var local_player: CharacterBody2D
@onready var ysort = $Y_Sort_Container

# Node overlay untuk mengawal skrin gelap/terang milik level_3
var overlay_gelap: ColorRect

func _ready() -> void:
	# 1. Bina lapisan hitam pekat bersiap sedia di bawah lapisan menu (Alpha = 1.0)
	bina_overlay_mula()
	_bina_hud_hp_pemain()
	
	# 2. Hubungkan isyarat daripada JSON
	if not SaveManager.semua_data_siap_di_load.is_connected(proses_selesai_load_json):
		SaveManager.semua_data_siap_di_load.connect(proses_selesai_load_json)
	
	# 3. Panggil fungsi load JSON untuk mula menyusun perabot
	SaveManager.load_game()

func _bina_hud_hp_pemain() -> void:
	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		return
	# Elak duplikasi jika fungsi dipanggil semula
	if canvas.has_node("PlayerHpHud"):
		return
	var hud := Control.new()
	hud.name = "PlayerHpHud"
	hud.set_script(load("res://scene/ui/PlayerHpHud.gd"))
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Letak full rect; kedudukan sebenar bar diurus dalam PlayerHpHud (bawah kanan)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.offset_left = 0
	hud.offset_right = 0
	hud.offset_top = 0
	hud.offset_bottom = 0
	canvas.add_child(hud)

# Membina lapisan hitam pekat di awal game
func bina_overlay_mula() -> void:
	overlay_gelap = ColorRect.new()
	overlay_gelap.color = Color(0, 0, 0, 1.0) # Sedia ada hitam pekat
	overlay_gelap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_gelap.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 99 # Diletakkan di layer 99 (Menu tadi berada di layer 100)
	canvas_layer.add_child(overlay_gelap)
	add_child(canvas_layer)

# DIPANGGIL SELEPAS ISYARAT JSON DITERIMA
func proses_selesai_load_json() -> void:
	# 1. Lahirkan player selepas semua perabot siap disusun
	spawn_local()
	
	# 2. 🌟 MENURUT LOGIK BARU: Tunggu masa bertenang 0.3 saat sejurus selepas isyarat JSON selesai
	print("[World] Isyarat JSON diterima. Menahan skrin hitam selama 0.3 saat...")
	await get_tree().create_timer(0.3).timeout
	
	# 3. 🌟 PADAM FADE MENU DI SINI: Cari dan musnahkan perisai hitam yang ditinggalkan oleh menu utama di Autoload
	var perisai_menu = SceneTransition.get_node_or_null("PerisaiHitamMenu")
	if is_instance_valid(perisai_menu):
		print("[World] 0.3 saat tamat. Memadam skrin hitam milik menu utama!")
		perisai_menu.queue_free()
	
	# 4. Mulakan kesan fade terang milik level_3 sendiri selama 3 saat
	mulakan_fade_terang()

func spawn_local() -> void:
	if is_instance_valid(local_player):
		return
		
	var existing_player = get_tree().get_first_node_in_group("Player")
	if is_instance_valid(existing_player):
		local_player = existing_player
		print("[World] Player dikesan sudah wujud. Batal spawn.")
		return
		
	local_player = player_scene.instantiate()
	local_player.set_meta("local", true)
	local_player.global_position = Vector2(141, 250)
	
	ysort.add_child(local_player)
	print("[World] Local spawned ✔")

# Memudar skrin hitam kepada terang semula (Fade Out skrin hitam)
func mulakan_fade_terang() -> void:
	print("[World] Memulakan fade out skrin hitam selama 3 saat...")
	var tween = create_tween()
	
	# Tukar alpha daripada 1.0 ke 0.0 selama 3 saat penuh bersambung lancar ke dalam game
	tween.tween_property(overlay_gelap, "color:a", 0.0, 3.0)
	await tween.finished
	
	# Padam node parent CanvasLayer overlay setelah selesai untuk jimat RAM
	if is_instance_valid(overlay_gelap):
		overlay_gelap.get_parent().queue_free()

# ==========================================
# FUNGSI SAVE DUNIA
# ==========================================
func save_world() -> void:
	SaveManager.save_game()
	print("[World] Dunia hibrid berjaya disimpan ke storan!")

func _physics_process(_delta: float) -> void:
	pass 

func _on_init(_data):
	pass

func _on_world_update(_players: Dictionary):
	pass
