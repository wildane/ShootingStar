extends Node

signal semua_data_siap_di_load
const SAVE_PATH_JSON = "user://savegame.json"

# Data pemain terakhir yang dibaca dari fail (posisi, HP, tenaga).
var data_player: Dictionary = {}

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		semak_dan_auto_save()

func semak_dan_auto_save():
	var scene_utama = Engine.get_main_loop().current_scene
	if scene_utama and scene_utama.scene_file_path.get_file() == "level_3.tscn":
		save_game()

func save_game():
	var scene_utama = Engine.get_main_loop().current_scene
	if not scene_utama or "menu" in scene_utama.name.to_lower(): return

	# Struktur JSON menggabungkan data perabot, inventori, dan SEMUA jenis spawner
	var data_keseluruhan = {
		"inventory_items": [], 
		"placed_objects": [],
		"spawner_data": {}
	}
	
	# 1. Simpan Data Inventori
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager:
		for barang: Dictionary in inv_manager.senarai_barang:
			data_keseluruhan["inventory_items"].append({"scene_path": barang.get("scene_path", ""), "kuantiti": barang.get("kuantiti", 1)})

	# 1b. Simpan data pemain: kedudukan, HP dan tenaga.
	var pemain := get_tree().get_first_node_in_group("Player") as Node2D
	if is_instance_valid(pemain):
		var data_pemain := {
			"pos_x": pemain.global_position.x,
			"pos_y": pemain.global_position.y
		}
		var hp_pemain = pemain.get_node_or_null("HealthComponent")
		if hp_pemain != null:
			data_pemain["hp"] = hp_pemain.get("hp")
		var tenaga_pemain = pemain.get_node_or_null("EnergyComponent")
		if tenaga_pemain != null:
			data_pemain["tenaga"] = tenaga_pemain.get("tenaga")
		# State pemain (BaseState / AngkasaState) supaya kawalan dan visual
		# sama seperti sebelum keluar.
		var state_machine = pemain.get_node_or_null("StateMachine")
		if state_machine != null:
			var state_semasa = state_machine.get("state_sekarang")
			if state_semasa is Node:
				data_pemain["state"] = str((state_semasa as Node).name)
		data_keseluruhan["player_data"] = data_pemain

	# 2. Simpan Semua Objek Menggunakan SaveComponent
	var y_sort_node = scene_utama.get_node_or_null("Y_Sort_Container")
	if y_sort_node:
		for nod in y_sort_node.get_children():
			if nod is Node2D and nod.has_node("SaveComponent"):
				var data_objek = nod.get_node("SaveComponent").get_data()
				data_objek["node_name"] = nod.name
				data_keseluruhan["placed_objects"].append(data_objek)

	# 3. KEMAS KINI MUTLAK: Mencari MobSpawner DAN MeteoriteSpawner secara automatik
	if scene_utama:
		var semua_node = scene_utama.find_children("*", "Node2D", true, false)
		for node in semua_node:
			if node.has_method("dapatkan_data_save") and "spawner_id" in node:
				data_keseluruhan["spawner_data"][node.spawner_id] = node.dapatkan_data_save()

	var file = FileAccess.open(SAVE_PATH_JSON, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data_keseluruhan, "\t"))
		file.close()

func load_game(scene_aktif: Node = null):
	# Buang data pemain lama supaya fail tanpa player_data tidak guna nilai basi.
	data_player = {}
	if not FileAccess.file_exists(SAVE_PATH_JSON):
		semua_data_siap_di_load.emit()
		return
	
	var file = FileAccess.open(SAVE_PATH_JSON, FileAccess.READ)
	var saved_data = JSON.parse_string(file.get_as_text())
	file.close()
	if not saved_data:
		semua_data_siap_di_load.emit()
		return

	# Data pemain dipakai semasa spawn (lihat posisi_awal_player / pakai_data_player).
	data_player = saved_data.get("player_data", {})
		
	var scene_utama = scene_aktif if scene_aktif != null else Engine.get_main_loop().current_scene
	
	# 1. Muat Semula Data Inventori
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager and saved_data.has("inventory_items"):
		inv_manager.senarai_barang.clear()
		for item in saved_data["inventory_items"]:
			var path = item.get("scene_path", "")
			var id_d = path.get_file().get_basename()
			var nama_d = "Item Tanpa Nama"
			var ikon_d = null
			
			if path != "" and ResourceLoader.exists(path):
				var hantu = (load(path) as PackedScene).instantiate()
				if "id_barang" in hantu: id_d = hantu.id_barang
				if "nama_barang" in hantu: nama_d = hantu.nama_barang
				if "ikon_barang" in hantu: ikon_d = hantu.ikon_barang
				hantu.queue_free()
				
			inv_manager.senarai_barang.append({"id": id_d, "nama": nama_d, "ikon": ikon_d, "scene_path": path, "kuantiti": item.get("kuantiti", 1)})
		inv_manager.inventory_dikemaskini.emit()

	# 2. Muat Semula Objek Dunia Terus dari Senarai Rata
	var y_sort_node = scene_utama.get_node_or_null("Y_Sort_Container") if scene_utama else null
	if y_sort_node and saved_data.has("placed_objects"):
		for data in saved_data["placed_objects"]:
			var path_fail = data.get("scene_path", "")
			
			if path_fail != "" and ResourceLoader.exists(path_fail):
				var obj_instance = (load(path_fail) as PackedScene).instantiate() as Node2D
				obj_instance.name = data.get("node_name", "PlacedObject")
				obj_instance.global_position = Vector2(data.get("pos_x", 0.0), data.get("pos_y", 0.0))
				obj_instance.scene_file_path = path_fail
				y_sort_node.add_child(obj_instance)
				# Pulihkan HP/tenaga objek (contoh: robot pekerja) selepas _ready.
				_pakai_data_objek(obj_instance, data)

	# 3. KEMAS KINI MUTLAK: Mengagihkan semula data kedudukan kepada MobSpawner dan MeteoriteSpawner
	if scene_utama and saved_data.has("spawner_data"):
		var data_spawners = saved_data["spawner_data"]
		
		var semua_node = scene_utama.find_children("*", "Node2D", true, false)
		for node in semua_node:
			if "spawner_id" in node and data_spawners.has(node.spawner_id):
				if node.has_method("muat_data_save"):
					node.muat_data_save(data_spawners[node.spawner_id])

	# 4. Kalau pemain sudah wujud, pulihkan posisi/HP/tenaga terus.
	var pemain_sedia := get_tree().get_first_node_in_group("Player") as Node2D
	if is_instance_valid(pemain_sedia):
		pakai_data_player(pemain_sedia)

	semua_data_siap_di_load.emit()

# ==========================================
# DATA PEMAIN (posisi, HP, tenaga)
# ==========================================
# Posisi spawn pemain: guna data simpanan kalau ada, kalau tidak nilai lalai.
func posisi_awal_player(nilai_lalai: Vector2) -> Vector2:
	if data_player.is_empty():
		return nilai_lalai
	return Vector2(
		float(data_player.get("pos_x", nilai_lalai.x)),
		float(data_player.get("pos_y", nilai_lalai.y))
	)


# Pakai data pemain yang disimpan pada player yang baru di-spawn.
func pakai_data_player(pemain: Node2D) -> void:
	if not is_instance_valid(pemain) or data_player.is_empty():
		return
	if data_player.has("pos_x") and data_player.has("pos_y"):
		pemain.global_position = Vector2(float(data_player["pos_x"]), float(data_player["pos_y"]))
	var hp_komp := pemain.get_node_or_null("HealthComponent")
	if hp_komp != null and data_player.has("hp"):
		var hp_maks := int(hp_komp.get("max_hp"))
		hp_komp.set("hp", maxi(1, mini(int(float(data_player["hp"])), hp_maks)))
		hp_komp.set("is_dead", false)
	var tenaga_komp := pemain.get_node_or_null("EnergyComponent")
	if tenaga_komp != null and data_player.has("tenaga"):
		tenaga_komp.set("tenaga", clampf(float(data_player["tenaga"]), 0.0, float(tenaga_komp.get("max_energy"))))
	# Pulihkan state StateMachine (BaseState / AngkasaState).
	if data_player.has("state"):
		var sm := pemain.get_node_or_null("StateMachine")
		if sm != null:
			var state_baru := sm.get_node_or_null(NodePath(str(data_player["state"])))
			if state_baru != null:
				if sm.get("state_sekarang") == null:
					# State machine belum mula: biar ia guna state simpanan sebagai state awal.
					sm.set("state_awal", state_baru)
				elif sm.get("state_sekarang") != state_baru and sm.has_method("tukar_state"):
					sm.call("tukar_state", state_baru)


# Nama state pemain yang disimpan ("" kalau tiada).
func nama_state_player() -> String:
	return str(data_player.get("state", ""))


# Pulihkan HP/tenaga objek dunia (robot pekerja) daripada data simpanan.
func _pakai_data_objek(nod: Node, data: Dictionary) -> void:
	if nod == null:
		return
	if "hp" in nod and data.has("hp"):
		var hp_maks: float = float(nod.get("hp_maks")) if "hp_maks" in nod else float(data["hp"])
		nod.set("hp", clampf(float(data["hp"]), 1.0, hp_maks))
	if "tenaga" in nod and data.has("tenaga"):
		var tenaga_maks: float = float(nod.get("tenaga_maks")) if "tenaga_maks" in nod else float(data["tenaga"])
		nod.set("tenaga", clampf(float(data["tenaga"]), 1.0, tenaga_maks))
