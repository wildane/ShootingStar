# ==========================================================
# FAIL: drop_component.gd (Versi Pembaikan Posisi Skrin)
# ==========================================================
class_name DropComponent
extends Node2D

@export var drop_scenes: Array[PackedScene] = []
@export var drop_percentages: Array[float] = [50.0, 35.0, 10.0, 5.0]

func trigger_drop() -> void:
	if drop_scenes.is_empty():
		print("DropComponent: GAGAL! Array 'drop_scenes' kosong!")
		return
		
	if drop_percentages.size() < drop_scenes.size():
		for i in range(drop_percentages.size(), drop_scenes.size()):
			drop_percentages.append(10.0)

	var total_weight: float = 0.0
	for i in range(drop_scenes.size()):
		total_weight += drop_percentages[i]
		
	var roll: float = randf() * total_weight
	var current_weight: float = 0.0
	var selected_scene: PackedScene = null
	
	for i in range(drop_scenes.size()):
		current_weight += drop_percentages[i]
		if roll <= current_weight:
			selected_scene = drop_scenes[i]
			break
			
	if selected_scene == null: 
		selected_scene = drop_scenes[0]
		
	var barang_baru = selected_scene.instantiate() as Node2D
	if not barang_baru: return
	
	barang_baru.global_position = global_position
	get_tree().current_scene.add_child(barang_baru)
	print("DropComponent: BERJAYA SPAWN -> ", barang_baru.name)
	
	# Ekstrak data teks, gambar ikon, DAN laluan fail .tscn asal
	var id_b = barang_baru.get("id_barang")
	var nama_b = barang_baru.get("nama_barang")
	var ikon_b = barang_baru.get("ikon_barang")
	var path_b = selected_scene.resource_path # Mengunci laluan fail untuk sistem Save Game
	
	if id_b == null: id_b = "item_unknown"
	if nama_b == null: nama_b = "Unnamed Item"
	
	var data_barang = {
		"id": id_b,
		"nama": nama_b,
		"ikon": ikon_b,
		"scene_path": path_b
	}
	
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager and inv_manager.has_method("tambah_item"):
		inv_manager.tambah_item(data_barang)
		print("DropComponent: Data berjaya dihantar ke InventoryManager!")
	
	# --- ANIMASI +1 TERAPUNG, MELEKAT PADA POSISI DUNIA ---
	var pos_dunia: Vector2 = barang_baru.global_position
	var ikon_tex: Texture2D = ikon_b if ikon_b is Texture2D else null
	barang_baru.queue_free()
	tunjuk_popup_terapung(ikon_tex, "+1 %s" % str(nama_b), pos_dunia, self)

# Animasi "+N" (ikon + teks) terapung yang melekat pada posisi dunia, jadi ia
# ikut kamera bergerak. Statik supaya skrip drop lain (contoh: cheat mode)
# boleh guna rupa animasi yang sama.
static func tunjuk_popup_terapung(ikon_tex: Texture2D, teks: String, pos_dunia: Vector2, sumber: Node) -> void:
	if not is_instance_valid(sumber):
		return
	var pokok := sumber.get_tree()
	if pokok == null or pokok.current_scene == null:
		return
	var viewport := sumber.get_viewport()
	if viewport == null:
		return

	var canvas = pokok.current_scene.find_child("CanvasLayer", true, false)
	# Saiz popup disamakan dengan iklan "+1 <nama>" di relau smelter:
	# ikon 7px, fon 7, jarak 1px, supaya semua popup "+" seragam.
	var popup := HBoxContainer.new()
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.alignment = BoxContainer.ALIGNMENT_CENTER
	popup.add_theme_constant_override("separation", 1)
	popup.z_index = 100

	if ikon_tex:
		var ikon := TextureRect.new()
		ikon.texture = ikon_tex
		ikon.custom_minimum_size = Vector2(7, 7)
		ikon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ikon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ikon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ikon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(ikon)

	var label := Label.new()
	label.text = teks
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.09, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(label)

	if canvas:
		canvas.add_child(popup)
	else:
		pokok.current_scene.add_child(popup)
	popup.reset_size()
	# Tengahkan popup tepat pada kedudukan item guna lebar sebenar teks.
	var offset_x := -popup.size.x * 0.5
	var offset_y_awal := -14.0
	popup.global_position = (viewport.get_canvas_transform() * pos_dunia) + Vector2(offset_x, offset_y_awal)

	var tween = pokok.create_tween().set_parallel(true)
	var tw_pos = tween.tween_method(func(masa: float) -> void:
		if not is_instance_valid(popup):
			return
		var t_gerak := clampf(masa / 0.7, 0.0, 1.0)
		var e := 1.0 - (1.0 - t_gerak) * (1.0 - t_gerak) # EASE_OUT_QUAD
		popup.global_position = (viewport.get_canvas_transform() * pos_dunia) + Vector2(offset_x, offset_y_awal - 28.0 * e)
	, 0.0, 0.9, 0.9)
	tw_pos.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(popup, "modulate:a", 0.0, 0.7).set_delay(0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(popup.queue_free)
