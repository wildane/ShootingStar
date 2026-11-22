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
	
	# --- SISTEM ANIMASI TERBANG KOSMETIK (YANG TELAH DIBETULKAN) ---
	var target_world_pos: Vector2 = global_position
	var inventory_button: Control = null
	var canvas = get_tree().current_scene.find_child("CanvasLayer", true, false)
	
	if canvas:
		inventory_button = canvas.find_child("InventoryButton", true, false) as Control
	
	if inventory_button and inventory_button.is_visible_in_tree():
		# 🔥 DIPERBAIKI: Menggunakan global_position untuk mengelakkan ralat Runtime Crash Godot 4
		var screen_pos : Vector2 = inventory_button.global_position + (inventory_button.size / 2)
		target_world_pos = get_canvas_transform().affine_inverse() * screen_pos
	else:
		var player_node = get_tree().current_scene.find_child("SpaceShip", true, false)
		if not player_node:
			player_node = get_tree().current_scene.find_child("Player", true, false)
		if player_node:
			target_world_pos = player_node.global_position

	if barang_baru.has_node("CollisionShape2D"):
		barang_baru.get_node("CollisionShape2D").set_deferred("disabled", true)
	elif barang_baru.has_method("set_deferred"):
		barang_baru.set_deferred("monitoring", false)
		barang_baru.set_deferred("monitorable", false)
		
	barang_baru.set_process(false)
	barang_baru.set_physics_process(false)

	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(barang_baru, "global_position", target_world_pos, 0.6)
	tween.tween_property(barang_baru, "scale", Vector2.ZERO, 0.6)
	tween.chain().tween_callback(barang_baru.queue_free)
