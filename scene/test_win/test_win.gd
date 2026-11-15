# Skrip test_win.gd - Terus tukar ke folder main_menu
extends CanvasLayer

func _ready() -> void:
	# 1. Wajib ada supaya butang boleh ditekan semasa game di-pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 2. SISTEM AUTO-CARI UNTUK iOS: Cari mana-mana node berjenis Button di dalam scene ini
	var found_button = find_first_button(self)
	
	if found_button:
		# Sambungkan isyarat klik butang secara automatik
		found_button.pressed.connect(_on_menu_button_pressed)
		print("iOS Success: Butang menu berjaya dijumpai automatik!")
	else:
		print("iOS Error: Tiada sebarang node Button dijumpai di dalam scene test_win!")

func _on_menu_button_pressed() -> void:
	# 3. Lepaskan pause game sebelum tukar scene
	get_tree().paused = false
	
	# 4. KUNCI PENYELESAIAN: Laluan folder dikunci terus secara automatik
	var target_menu_path = "res://scene/main_menu/main_menu.tscn"
	
	if ResourceLoader.exists(target_menu_path):
		get_tree().change_scene_to_file(target_menu_path)
		print("iOS Success: Berjaya tukar ke menu utama di folder main_menu!")
	else:
		print("CRITICAL ERROR: Fail tidak dijumpai! Sila pastikan nama folder dan fail kau dieja 'main_menu/main_menu.tscn'")

# Fungsi bantuan untuk scan & cari butang secara automatik dalam senarai node
func find_first_button(current_node: Node) -> Button:
	if current_node is Button:
		return current_node
	for child in current_node.get_children():
		var result = find_first_button(child)
		if result:
			return result
	return null
