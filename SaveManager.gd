extends Node

signal semua_data_siap_di_load

const BAR_HP_STRUKTUR := preload("res://scene/level_3/build_system/BarHpStruktur.gd")

# Simpanan berbilang slot: setiap slot satu fail JSON dalam user://saves/.
# Nama dan masa setiap slot disimpan dalam katalog supaya boleh ditukar nama
# atau dipadam dari halaman Muat Simpanan.
const DIREKTORI_SAVE = "user://saves"
const KATALOG_PATH = "user://saves/katalog.json"
const LALUAN_LAMA = "user://savegame.json"

# Slot autosave berputar; ditulis bila game di-minimize (app pause/focus out).
const SLOT_AUTOSAVE = ["autosave1", "autosave2", "autosave3"]

# Versi format fail simpanan. Naikkan bila kandungan game dibuang/ditukar
# dan save lama perlu dibersihkan dalam _migrasi_data_simpanan().
const VERSI_SIMPANAN: int = 1

# Slot yang sedang dimainkan ("" = permainan baharu, belum ada slot).
var slot_aktif: String = ""

# Data pemain terakhir yang dibaca dari fail (posisi, HP, tenaga).
var data_player: Dictionary = {}

func _ready() -> void:
	_sediakan_direktori()
	_migrasi_simpanan_lama()

# Jarak minimum antara dua autosave (saat). Android kadangkala menghantar
# NOTIFICATION_APPLICATION_PAUSED dua kali untuk satu minimize; had ini
# menghalang dua slot autosave daripada ditulis dengan keadaan yang sama.
const JARAK_AUTOSAVE_MIN := 2.0

var _masa_autosave_terakhir: float = -1000.0

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		semak_dan_auto_save()

# Autosave hanya dalam level permainan (bukan menu), dan tidak berulang terlalu rapat.
func semak_dan_auto_save():
	var scene_utama = Engine.get_main_loop().current_scene
	if not scene_utama or scene_utama.scene_file_path.get_file() != "level_3.tscn":
		return
	var kini := Time.get_ticks_msec() / 1000.0
	if kini - _masa_autosave_terakhir < JARAK_AUTOSAVE_MIN:
		return
	_masa_autosave_terakhir = kini
	save_autosave()

# ==========================================
# MASA TEMPATAN UNTUK CAP MASA
# ==========================================
# Simpanan menyimpan unix time (UTC). Untuk paparan, tambah bias zon waktu
# peranti supaya jam yang ditunjuk sama dengan jam telefon (format 24 jam).
func _bias_zohn_saat() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

func format_masa(masa: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(masa) + _bias_zohn_saat())
	return "%02d/%02d/%04d %02d:%02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute, d.second]

# ==========================================
# SIMPANAN BERBILANG SLOT
# ==========================================
func _sediakan_direktori() -> void:
	if not DirAccess.dir_exists_absolute(DIREKTORI_SAVE):
		DirAccess.make_dir_recursive_absolute(DIREKTORI_SAVE)

func _laluan_slot(id: String) -> String:
	return DIREKTORI_SAVE.path_join("data_%s.json" % id)

# Salinan sah terakhir slot, dipakai kalau fail utama rosak.
func _laluan_backup(id: String) -> String:
	return _laluan_slot(id) + ".bak"

func _baca_katalog() -> Dictionary:
	if not FileAccess.file_exists(KATALOG_PATH):
		return {}
	var file := FileAccess.open(KATALOG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data

func _tulis_katalog(katalog: Dictionary) -> void:
	var file := FileAccess.open(KATALOG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(katalog, "\t"))
		file.close()

# Semua slot, paling baharu dahulu (ikut masa simpanan terakhir).
func senarai_slot() -> Array:
	var hasil: Array = []
	if not DirAccess.dir_exists_absolute(DIREKTORI_SAVE):
		return hasil
	var katalog := _baca_katalog()
	var dir := DirAccess.open(DIREKTORI_SAVE)
	if dir == null:
		return hasil
	dir.list_dir_begin()
	var nama_fail := dir.get_next()
	while nama_fail != "":
		if not dir.current_is_dir() and nama_fail.begins_with("data_") and nama_fail.ends_with(".json"):
			var id := nama_fail.substr(5, nama_fail.length() - 10)
			var meta: Dictionary = katalog.get(id, {})
			var laluan := _laluan_slot(id)
			hasil.append({
				"id": id,
				"nama": str(meta.get("nama", "Save %s" % id)),
				"masa": float(meta.get("masa", FileAccess.get_modified_time(laluan))),
			})
		nama_fail = dir.get_next()
	dir.list_dir_end()
	hasil.sort_custom(func(a, b): return float(a["masa"]) > float(b["masa"]))
	return hasil

func ada_simpanan() -> bool:
	return not senarai_slot().is_empty()

func slot_terbaru() -> String:
	var senarai := senarai_slot()
	if senarai.is_empty():
		return ""
	return str(senarai[0]["id"])

func nama_slot(id: String) -> String:
	for slot in senarai_slot():
		if str(slot["id"]) == id:
			return str(slot["nama"])
	return id

func cipta_slot_baru(nama: String = "") -> String:
	var katalog := _baca_katalog()
	var asas := "s%d" % int(Time.get_unix_time_from_system())
	var id := asas
	var nombor := 2
	while FileAccess.file_exists(_laluan_slot(id)) or katalog.has(id):
		id = "%s_%d" % [asas, nombor]
		nombor += 1
	var nama_akhir := nama.strip_edges()
	if nama_akhir == "":
		nama_akhir = "Save %d" % (senarai_slot().size() + 1)
	katalog[id] = {"nama": nama_akhir, "masa": Time.get_unix_time_from_system()}
	_tulis_katalog(katalog)
	return id

func tukar_nama_slot(id: String, nama_baru: String) -> void:
	var nama := nama_baru.strip_edges()
	if nama == "":
		return
	var katalog := _baca_katalog()
	var meta: Dictionary = katalog.get(id, {})
	meta["nama"] = nama
	if not meta.has("masa"):
		meta["masa"] = float(FileAccess.get_modified_time(_laluan_slot(id)))
	katalog[id] = meta
	_tulis_katalog(katalog)

func hapus_slot(id: String) -> void:
	if FileAccess.file_exists(_laluan_slot(id)):
		DirAccess.remove_absolute(_laluan_slot(id))
	var katalog := _baca_katalog()
	if katalog.has(id):
		katalog.erase(id)
		_tulis_katalog(katalog)
	if slot_aktif == id:
		slot_aktif = ""

# Permainan baharu: lupakan slot lama dan kosongkan inventori.
func mula_permainan_baru() -> void:
	slot_aktif = ""
	data_player = {}
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager:
		inv_manager.senarai_barang.clear()
		inv_manager.inventory_dikemaskini.emit()
	# Permainan baharu bermula tanpa threat/serangan balas.
	StorThreat.reset()

# Pilih slot untuk dimuatkan oleh scene seterusnya (level_3 panggil load_game).
func tetapkan_slot(id: String) -> void:
	data_player = {}
	slot_aktif = id

func _kemas_kini_masa_slot(id: String, nama_lalai: String = "") -> void:
	var katalog := _baca_katalog()
	var meta: Dictionary = katalog.get(id, {})
	if not meta.has("nama"):
		meta["nama"] = nama_lalai if nama_lalai != "" else "Save %s" % id
	meta["masa"] = Time.get_unix_time_from_system()
	katalog[id] = meta
	_tulis_katalog(katalog)

# Pindahkan fail simpanan tunggal versi lama ke slot pertama.
func _migrasi_simpanan_lama() -> void:
	if not FileAccess.file_exists(LALUAN_LAMA):
		return
	if not senarai_slot().is_empty():
		# Sudah ada slot baharu: fail lama tidak dipakai lagi.
		DirAccess.remove_absolute(LALUAN_LAMA)
		return
	var id := "lama"
	var laluan := _laluan_slot(id)
	DirAccess.rename_absolute(LALUAN_LAMA, laluan)
	var katalog := _baca_katalog()
	katalog[id] = {"nama": "Legacy Save", "masa": float(FileAccess.get_modified_time(laluan))}
	_tulis_katalog(katalog)
	print("[Save] Simpanan versi lama dipindahkan ke slot 'lama'.")

func _kumpul_data_state() -> Dictionary:
	var scene_utama = Engine.get_main_loop().current_scene
	if not scene_utama or "menu" in scene_utama.name.to_lower():
		return {}

	# Struktur JSON menggabungkan data perabot, inventori, dan SEMUA jenis spawner
	var data_keseluruhan = {
		"versi_simpanan": VERSI_SIMPANAN,
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

	# 2b. Simpan tile grid binaan pangkalan (lantai, dinding, pintu).
	var grid_bina := get_tree().get_first_node_in_group("BuildGrid")
	if grid_bina != null and grid_bina.has_method("dapatkan_data_save"):
		data_keseluruhan["build_grid"] = grid_bina.call("dapatkan_data_save")

	# 2c. Snapshot threat + baki pemasa serangan balas pada masa simpan ini.
	# Tanpa ini, load slot lama akan guna nilai cakera terkini (contoh: selepas
	# gelombang selesai) dan pemasa yang disimpan hilang.
	data_keseluruhan["threat"] = StorThreat.data_simpanan()

	# 3. KEMAS KINI MUTLAK: Mencari MobSpawner DAN MeteoriteSpawner secara automatik
	if scene_utama:
		var semua_node = scene_utama.find_children("*", "Node2D", true, false)
		for node in semua_node:
			if node.has_method("dapatkan_data_save") and "spawner_id" in node:
				data_keseluruhan["spawner_data"][node.spawner_id] = node.dapatkan_data_save()

	return data_keseluruhan

# ==========================================
# SIMPAN MANUAL (OVERWRITE) DAN AUTOSAVE 1-2-3
# ==========================================
# Butang SIMPAN: tulis semula slot aktif. Slot baharu dicipta hanya kalau
# permainan ini belum ada slot langsung (permainan baru yang belum disimpan).
func save_game() -> bool:
	# Slot autosave tidak ditimpa oleh simpan manual: sesi yang dimulakan dari
	# autosave akan dapat slot simpanan sendiri.
	if slot_aktif == "" or SLOT_AUTOSAVE.has(slot_aktif):
		slot_aktif = cipta_slot_baru()
	var data := _kumpul_data_state()
	if data.is_empty():
		return false
	return _tulis_data_ke_slot(slot_aktif, data)

# Autosave: dipanggil bila game di-minimize (app pause / focus out).
# Slot dipilih ikut masa: slot kosong dahulu (1 -> 2 -> 3), kemudian slot
# dengan simpanan paling lama ditulis semula supaya 3 slot sentiasa berputar.
func save_autosave() -> bool:
	var id := _slot_autosave_berikut()
	var data := _kumpul_data_state()
	if data.is_empty():
		return false
	var nama_lalai := "Autosave %d" % (SLOT_AUTOSAVE.find(id) + 1)
	var berjaya := _tulis_data_ke_slot(id, data, nama_lalai)
	if berjaya:
		print("[Save] Autosave disimpan ke ", id)
	return berjaya

# Simpan manual ke slot tertentu (dipilih dalam panel SAVE dalam game).
func simpan_ke_slot(id: String) -> bool:
	var data := _kumpul_data_state()
	if data.is_empty():
		return false
	if not _tulis_data_ke_slot(id, data):
		return false
	slot_aktif = id
	return true

# Simpan ke slot baharu (butang New Save). Pulangkan id slot, "" kalau gagal.
func simpan_slot_baru(nama: String = "") -> String:
	var id := cipta_slot_baru(nama)
	if not simpan_ke_slot(id):
		return ""
	return id

func _slot_autosave_berikut() -> String:
	var katalog := _baca_katalog()
	var paling_lama: String = SLOT_AUTOSAVE[0]
	var masa_paling_lama := INF
	for id in SLOT_AUTOSAVE:
		if not FileAccess.file_exists(_laluan_slot(id)):
			return id
		var meta: Dictionary = katalog.get(id, {})
		var masa := float(meta.get("masa", FileAccess.get_modified_time(_laluan_slot(id))))
		if masa < masa_paling_lama:
			masa_paling_lama = masa
			paling_lama = id
	return paling_lama

func _tulis_data_ke_slot(id: String, data: Dictionary, nama_lalai: String = "") -> bool:
	if not _tulis_fail_slot(id, data):
		return false
	_kemas_kini_masa_slot(id, nama_lalai)
	return true

# Tulis JSON slot secara atomik: fail sementara -> backup fail lama (.bak) ->
# ganti fail utama. Fail asal kekal sah sehingga tulisan baharu lengkap, jadi
# app yang dibunuh semasa menyimpan tidak merosakkan save. buat_backup=false
# dipakai bila memulihkan fail utama daripada .bak (jangan timpa backup baik
# dengan fail yang rosak).
func _tulis_fail_slot(id: String, data: Dictionary, buat_backup: bool = true) -> bool:
	if id == "":
		return false
	_sediakan_direktori()
	var laluan := _laluan_slot(id)
	var sementara := laluan + ".tmp"
	var file := FileAccess.open(sementara, FileAccess.WRITE)
	if file == null:
		push_warning("[Save] Gagal buka fail sementara untuk slot %s" % id)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	var ralat_tulis := file.get_error()
	file.close()
	if ralat_tulis != OK:
		push_warning("[Save] Gagal tulis slot %s (ralat %d)" % [id, ralat_tulis])
		DirAccess.remove_absolute(sementara)
		return false
	if buat_backup and FileAccess.file_exists(laluan):
		# Satu backup sahaja: simpanan sah terakhir sebelum ditimpa.
		DirAccess.remove_absolute(_laluan_backup(id))
		if DirAccess.copy_absolute(laluan, _laluan_backup(id)) != OK:
			push_warning("[Save] Gagal buat backup slot %s" % id)
	if DirAccess.rename_absolute(sementara, laluan) != OK:
		push_warning("[Save] Gagal ganti fail slot %s" % id)
		DirAccess.remove_absolute(sementara)
		return false
	return true

# Baca satu fail slot. Kamus kosong = fail tiada atau JSON rosak.
func _baca_fail_slot(laluan: String) -> Dictionary:
	if not FileAccess.file_exists(laluan):
		return {}
	var file := FileAccess.open(laluan, FileAccess.READ)
	if file == null:
		return {}
	var teks := file.get_as_text()
	file.close()
	# Guna JSON.new() supaya fail rosak tidak mencetak ralat enjin: ia keadaan
	# yang dijangka dan dikendalikan (cuba .bak / main permainan baharu).
	var json := JSON.new()
	if json.parse(teks) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data

func load_game(scene_aktif: Node = null):
	# Buang data pemain lama supaya fail tanpa player_data tidak guna nilai basi.
	data_player = {}
	# Tiada slot aktif = permainan baharu: mula tanpa data simpanan.
	if slot_aktif == "":
		semua_data_siap_di_load.emit()
		return

	var saved_data := _baca_fail_slot(_laluan_slot(slot_aktif))
	if saved_data.is_empty():
		# Fail utama rosak/hilang: cuba backup terakhir yang sah.
		saved_data = _baca_fail_slot(_laluan_backup(slot_aktif))
		if saved_data.is_empty():
			semua_data_siap_di_load.emit()
			return
		print("[Save] Simpanan %s rosak; dipulihkan dari fail .bak" % slot_aktif)
		_tulis_fail_slot(slot_aktif, saved_data, false)

	# Data pemain dipakai semasa spawn (lihat posisi_awal_player / pakai_data_player).
	data_player = saved_data.get("player_data", {})

	# Migrasi format lama (versi_simpanan): data yang scene-nya sudah tiada
	# dibuang secara eksplisit, dan fail slot ditulis semula sekali sahaja.
	if _migrasi_data_simpanan(saved_data):
		_tulis_fail_slot(slot_aktif, saved_data)
	var inventori_bersih: Array = saved_data.get("inventory_items", [])
	var objek_bersih: Array = saved_data.get("placed_objects", [])

	var scene_utama = scene_aktif if scene_aktif != null else Engine.get_main_loop().current_scene
	
	# 1. Muat Semula Data Inventori
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager:
		inv_manager.senarai_barang.clear()
		for item in inventori_bersih:
			var path = item.get("scene_path", "")
			var hantu = (load(path) as PackedScene).instantiate()
			var id_d = path.get_file().get_basename()
			var nama_d = "Item Tanpa Nama"
			var ikon_d = null
			if "id_barang" in hantu: id_d = hantu.id_barang
			if "nama_barang" in hantu: nama_d = hantu.nama_barang
			if "ikon_barang" in hantu: ikon_d = hantu.ikon_barang
			hantu.queue_free()

			inv_manager.senarai_barang.append({"id": id_d, "nama": nama_d, "ikon": ikon_d, "scene_path": path, "kuantiti": item.get("kuantiti", 1)})
		inv_manager.inventory_dikemaskini.emit()

	# 2. Muat Semula Objek Dunia Terus dari Senarai Rata
	var y_sort_node = scene_utama.get_node_or_null("Y_Sort_Container") if scene_utama else null
	if y_sort_node:
		for data in objek_bersih:
			var path_fail = data.get("scene_path", "")
			var obj_instance = (load(path_fail) as PackedScene).instantiate() as Node2D
			obj_instance.name = data.get("node_name", "PlacedObject")
			obj_instance.global_position = Vector2(data.get("pos_x", 0.0), data.get("pos_y", 0.0))
			obj_instance.scene_file_path = path_fail
			y_sort_node.add_child(obj_instance)
			# Pulihkan HP/tenaga objek selepas _ready.
			_pakai_data_objek(obj_instance, data)

	# 2b. Bina semula tile grid (lantai, dinding, pintu) dari simpanan.
	var grid_bina := get_tree().get_first_node_in_group("BuildGrid")
	if grid_bina != null and grid_bina.has_method("muat_data_save"):
		grid_bina.call("muat_data_save", saved_data.get("build_grid", {}))

	# 2c. Pulihkan threat + baki pemasa serangan balas milik slot ini.
	if saved_data.has("threat"):
		var data_threat = saved_data.get("threat", {})
		if data_threat is Dictionary:
			StorThreat.pakai_data_simpanan(data_threat)

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


# Migrasi data simpanan lama ke format semasa. Setiap langkah bersifat
# eksplisit supaya data lama dibersihkan bila kandungan game dibuang.
# Pulangkan true kalau data berubah dan fail slot perlu ditulis semula.
func _migrasi_data_simpanan(data: Dictionary) -> bool:
	var versi := int(data.get("versi_simpanan", 0))
	var berubah := false
	if versi < 1:
		# v1: buang entri robot/pod yang dibuang dari projek.
		berubah = true
	# Tapisan scene sentiasa dijalankan (murah, idempotent) sebagai jaring
	# keselamatan kalau kandungan dibuang tanpa naikkan VERSI_SIMPANAN.
	berubah = _bersihkan_senarai_scene(data, "inventory_items") or berubah
	berubah = _bersihkan_senarai_scene(data, "placed_objects") or berubah
	if versi < VERSI_SIMPANAN:
		data["versi_simpanan"] = VERSI_SIMPANAN
		berubah = true
	return berubah

# Tapis satu senarai entri di dalam data simpanan. Pulangkan true kalau ada
# entri dibuang atau nilainya bukan senarai.
func _bersihkan_senarai_scene(data: Dictionary, kunci: String) -> bool:
	var senarai = data.get(kunci, [])
	if not (senarai is Array):
		data[kunci] = []
		return true
	var bersih := _tapisan_scene_wujud(senarai)
	data[kunci] = bersih
	return bersih.size() < senarai.size()

# Senarai entri simpanan (inventori/objek dunia) tanpa entri yang
# scene_path-nya tiada.
func _tapisan_scene_wujud(senarai: Array) -> Array:
	var bersih: Array = []
	for data in senarai:
		if data is Dictionary:
			var path := str(data.get("scene_path", ""))
			if path != "" and ResourceLoader.exists(path):
				bersih.append(data)
	if bersih.size() < senarai.size():
		print("[Save] %d entri basi dibuang daripada simpanan (scene tiada)." % (senarai.size() - bersih.size()))
	return bersih

# Pulihkan HP/tenaga objek dunia daripada data simpanan.
func _pakai_data_objek(nod: Node, data: Dictionary) -> void:
	if nod == null:
		return
	if "hp" in nod and data.has("hp"):
		var hp_maks: float = float(nod.get("hp_maks")) if "hp_maks" in nod else float(data["hp"])
		nod.set("hp", clampf(float(data["hp"]), 1.0, hp_maks))
	if "tenaga" in nod and data.has("tenaga"):
		var tenaga_maks: float = float(nod.get("tenaga_maks")) if "tenaga_maks" in nod else float(data["tenaga"])
		nod.set("tenaga", clampf(float(data["tenaga"]), 1.0, tenaga_maks))
	# HP perabot yang diserang husk (disimpan sebagai meta, bukan properti hp).
	# Bar HP dipaparkan semula supaya struktur rosak kekal jelas selepas load.
	if data.has("hp_serangan") and nod is Node2D:
		var baki: int = maxi(1, int(data.get("hp_serangan", 1)))
		var maks: int = maxi(baki, int(data.get("hp_sasaran_maks", baki)))
		nod.set_meta("hp_serangan", baki)
		nod.set_meta("hp_sasaran_maks", maks)
		if baki < maks:
			BAR_HP_STRUKTUR.papar(nod as Node2D, baki, maks)
	# State tambahan khusus objek (contoh: batch smelter yang belum siap).
	if nod.has_method("pakai_data_simpanan_tambahan"):
		nod.call("pakai_data_simpanan_tambahan", data)
