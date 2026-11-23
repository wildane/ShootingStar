extends Node2D

@onready var sprite = $Sprite2D
@onready var area_penderia = $Area2D 

# --- SISTEM KEPERLUAN BAHAN (5 SLOT MANUAL - TANPA ARRAY) ---
@export_category("Bahan Keperluan 1")
@export_file("*.tscn") var fail_mats_1: String = ""
@export var kuantiti_1: int = 1

@export_category("Bahan Keperluan 2")
@export_file("*.tscn") var fail_mats_2: String = ""
@export var kuantiti_2: int = 1

@export_category("Bahan Keperluan 3")
@export_file("*.tscn") var fail_mats_3: String = ""
@export var kuantiti_3: int = 1

@export_category("Bahan Keperluan 4")
@export_file("*.tscn") var fail_mats_4: String = ""
@export var kuantiti_4: int = 1

@export_category("Bahan Keperluan 5")
@export_file("*.tscn") var fail_mats_5: String = ""
@export var kuantiti_5: int = 1

@export_category("Struktur Bangunan Sebenar")
@export_file("*.tscn") var fail_bangunan_sebenar_tscn: String = ""

# Nama yang dipaparkan pada hologram preview. Jika dibiarkan kosong,
# nama diambil daripada nama fail bangunan sebenar.
@export var nama_bangunan: String = ""

# --- SISTEM BUTANG UI TERAPUNG (EXPORT) ---
@export_category("Tetapan Butang UI")
@export var ikon_confirm: Texture2D
@export var ikon_cancel: Texture2D
@export var saiz_butang: Vector2 = Vector2(40, 40)

var boleh_pasang: bool = false
var ada_cukup_bahan: bool = false

# --- ELEMEN UI DI BAWAH HOLOGRAM ---
var bekas_ui_utama: VBoxContainer                     
var bekas_semua_keperluan: VBoxContainer              
var bekas_butang: HBoxContainer                       

var butang_confirm: TextureButton
var butang_cancel: TextureButton

# Struktur data tempatan untuk simpan info bahan yang diisi sahaja
var data_mats_terekstrak: Array[Dictionary] = []

# Panel detail bawah kiri (sama seperti yang inventory guna)
var label_info: Label = null
var teks_info_ditulis: String = ""
var ui_inventori: CanvasItem = null

func _ready() -> void:
	z_index = 100 
	if sprite:
		sprite.modulate = Color(1.0, 0.3, 0.3, 0.5)

	if area_penderia:
		area_penderia.monitoring = true
		area_penderia.monitorable = false
		
	ekstrak_info_bahan_manual()
	sediakan_seluruh_ui_manual()
	_sediakan_label_info()
	semak_baki_inventori_dan_update_ui()
	
	if has_node("/root/InventoryManager"):
		get_node("/root/InventoryManager").inventory_dikemaskini.connect(semak_baki_inventori_dan_update_ui)

func _physics_process(_delta: float) -> void:
	if mod_pembinaan_aktif():
		imbas_menggunakan_skala_inspector()
		semak_baki_inventori_dan_update_ui()
		kemas_kini_posisi_ui()

func _nama_bangunan_untuk_ui() -> String:
	var nama = nama_bangunan.strip_edges()
	if not nama.is_empty():
		return nama

	if fail_bangunan_sebenar_tscn.is_empty():
		return ""

	# Fallback: "SolarModuleActual.tscn" -> "Solar Module"
	nama = fail_bangunan_sebenar_tscn.get_file().get_basename()
	nama = nama.replace("_Actual", "").replace("Actual", "").replace("_Preview", "").replace("Preview", "")

	var hasil = ""
	for i in nama.length():
		var huruf = nama[i]
		if i > 0 and huruf == huruf.to_upper() and huruf != huruf.to_lower() and nama[i - 1] == nama[i - 1].to_lower():
			hasil += " "
		hasil += huruf

	return hasil.strip_edges()

func ekstrak_info_bahan_manual() -> void:
	data_mats_terekstrak.clear()
	
	# Senarai mentah untuk diproses secara gelung (loop) dalaman sahaja
	var slot_mentah = [
		{"fail": fail_mats_1, "kuantiti": kuantiti_1},
		{"fail": fail_mats_2, "kuantiti": kuantiti_2},
		{"fail": fail_mats_3, "kuantiti": kuantiti_3},
		{"fail": fail_mats_4, "kuantiti": kuantiti_4},
		{"fail": fail_mats_5, "kuantiti": kuantiti_5}
	]
	
	for slot in slot_mentah:
		var path: String = slot["fail"]
		if path.is_empty(): continue # AUTOMATIK: Jika kosong, abaikan terus!
		
		var id_mat = ""
		var nama_mat = ""
		var ikon_mat : Texture2D = null
		
		var item_scene = load(path)
		if item_scene:
			var item_instance = item_scene.instantiate()
			if "id_barang" in item_instance: id_mat = item_instance.id_barang
			if "nama_barang" in item_instance: nama_mat = item_instance.nama_barang
			else: nama_mat = path.get_file().get_basename().capitalize()
			if "ikon_barang" in item_instance: ikon_mat = item_instance.ikon_barang
			item_instance.queue_free()
			
		data_mats_terekstrak.append({
			"id": id_mat,
			"nama": nama_mat,
			"ikon": ikon_mat,
			"diperlukan": slot["kuantiti"]
		})

func sediakan_seluruh_ui_manual() -> void:
	bekas_ui_utama = VBoxContainer.new()
	bekas_ui_utama.alignment = BoxContainer.ALIGNMENT_CENTER
	bekas_ui_utama.z_index = 105
	add_child(bekas_ui_utama)
	
	# Nama bangunan: di bawah hologram, di atas senarai bahan
	var lbl_nama = Label.new()
	lbl_nama.name = "NamaBangunan"
	lbl_nama.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nama.text = _nama_bangunan_untuk_ui()
	bekas_ui_utama.add_child(lbl_nama)
	
	bekas_semua_keperluan = VBoxContainer.new()
	bekas_semua_keperluan.alignment = BoxContainer.ALIGNMENT_CENTER
	bekas_ui_utama.add_child(bekas_semua_keperluan)
	
	# Hanya bina baris UI untuk slot yang ada isi sahaja
	for data in data_mats_terekstrak:
		var baris_mat = HBoxContainer.new()
		baris_mat.alignment = BoxContainer.ALIGNMENT_CENTER
		baris_mat.name = data["id"] 
		
		var t_rect = TextureRect.new()
		t_rect.custom_minimum_size = Vector2(24, 24)
		t_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t_rect.texture = data["ikon"]
		baris_mat.add_child(t_rect)
		
		var lbl = Label.new()
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		baris_mat.add_child(lbl)
		
		bekas_semua_keperluan.add_child(baris_mat)
	
	# Bina Bahagian Butang
	bekas_butang = HBoxContainer.new()
	bekas_butang.alignment = BoxContainer.ALIGNMENT_CENTER
	bekas_butang.add_theme_constant_override("separation", 20)
	bekas_ui_utama.add_child(bekas_butang)
	
	butang_cancel = TextureButton.new()
	butang_cancel.custom_minimum_size = saiz_butang
	butang_cancel.ignore_texture_size = true
	butang_cancel.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if ikon_cancel: butang_cancel.texture_normal = ikon_cancel
	butang_cancel.pressed.connect(_on_butang_cancel_pressed)
	bekas_butang.add_child(butang_cancel)
	
	butang_confirm = TextureButton.new()
	butang_confirm.custom_minimum_size = saiz_butang
	butang_confirm.ignore_texture_size = true
	butang_confirm.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if ikon_confirm: butang_confirm.texture_normal = ikon_confirm
	butang_confirm.pressed.connect(_on_butang_confirm_pressed)
	bekas_butang.add_child(butang_confirm)

func semak_baki_inventori_dan_update_ui() -> void:
	if not is_instance_valid(bekas_ui_utama) or not sprite: return
	
	var semua_bahan_cukup = true
	var inv_list = []
	
	if has_node("/root/InventoryManager"):
		inv_list = get_node("/root/InventoryManager").senarai_barang

	for data in data_mats_terekstrak:
		var kuantiti_dalam_inventori = 0
		for barang in inv_list:
			if barang.get("id") == data["id"]:
				kuantiti_dalam_inventori = barang.get("kuantiti", 0)
				break
					
		var baris_ui = bekas_semua_keperluan.get_node_or_null(data["id"])
		if baris_ui:
			var lbl = baris_ui.get_child(1) as Label
			if lbl:
				lbl.text = data["nama"] + " (" + str(int(kuantiti_dalam_inventori)) + "/" + str(int(data["diperlukan"])) + ")"
			
			if kuantiti_dalam_inventori < data["diperlukan"]:
				baris_ui.modulate = Color(1.0, 0.3, 0.3, 1.0) # MERAH jika tak cukup
				semua_bahan_cukup = false
			else:
				baris_ui.modulate = Color(1.0, 1.0, 1.0, 1.0)
				
	ada_cukup_bahan = semua_bahan_cukup

	if not ada_cukup_bahan:
		butang_confirm.disabled = true
		butang_confirm.modulate = Color(0.5, 0.5, 0.5, 0.5)
	else:
		if boleh_pasang:
			butang_confirm.disabled = false
			butang_confirm.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			butang_confirm.disabled = true
			butang_confirm.modulate = Color(0.5, 0.5, 0.5, 0.5)

	_kemas_kini_info_binaan()

func _sediakan_label_info() -> void:
	var adegan = get_tree().current_scene
	if adegan == null:
		return
	label_info = adegan.find_child("InfoText", true, false) as Label
	ui_inventori = adegan.find_child("Inventory", true, false) as CanvasItem

func _kemas_kini_info_binaan() -> void:
	if not is_instance_valid(label_info) or not is_instance_valid(ui_inventori):
		_sediakan_label_info()
	if not is_instance_valid(label_info):
		return

	# Jangan timpa detail inventory bila inventory sedang dibuka
	if is_instance_valid(ui_inventori) and ui_inventori.visible:
		return

	var inv_list = []
	if has_node("/root/InventoryManager"):
		inv_list = get_node("/root/InventoryManager").senarai_barang

	var teks: String = "Name: " + _nama_bangunan_untuk_ui() + "\n"
	for data in data_mats_terekstrak:
		var ada: int = 0
		for barang in inv_list:
			if barang.get("id") == data["id"]:
				ada = int(barang.get("kuantiti", 0))
				break
		teks += str(data["nama"]) + " " + str(ada) + "/" + str(int(data["diperlukan"])) + "\n"

	if not ada_cukup_bahan:
		teks += "Not enough materials"
	elif boleh_pasang:
		teks += "Can build here"
	else:
		teks += "Can't build here"

	if teks != label_info.text:
		label_info.text = teks
	teks_info_ditulis = teks

func _exit_tree() -> void:
	# Kosongkan panel detail bila preview tamat, tapi jangan ganggu teks inventory
	if is_instance_valid(label_info) and label_info.text == teks_info_ditulis:
		label_info.text = ""

func kemas_kini_posisi_ui() -> void:
	if not is_instance_valid(bekas_ui_utama) or not is_instance_valid(sprite) or not sprite.texture: return
	
	var saiz_ui_sebenar = bekas_ui_utama.get_combined_minimum_size()
	var saiz_gambar = sprite.get_rect().size * sprite.scale
	
	if sprite.centered:
		bekas_ui_utama.position = Vector2(-saiz_ui_sebenar.x / 2, (saiz_gambar.y / 2) + 15)
	else:
		bekas_ui_utama.position = Vector2((saiz_gambar.x / 2) - (saiz_ui_sebenar.x / 2), saiz_gambar.y + 15)

func _on_butang_confirm_pressed() -> void:
	if boleh_pasang and ada_cukup_bahan:
		if fail_bangunan_sebenar_tscn.is_empty(): return

		if has_node("/root/InventoryManager"):
			var inv_mgr = get_node("/root/InventoryManager")
			for data in data_mats_terekstrak:
				inv_mgr.tolak_item(data["id"], data["diperlukan"])
		
		var bangunan_scene = load(fail_bangunan_sebenar_tscn)
		if bangunan_scene:
			var bangunan_baru = bangunan_scene.instantiate()
			get_parent().add_child(bangunan_baru)
			bangunan_baru.global_position = global_position
			get_tree().call_group("PowerInverter", "tanda_kotor")
		
		queue_free()

func _on_butang_cancel_pressed() -> void:
	queue_free()

func mod_pembinaan_aktif() -> bool:
	return is_instance_valid(area_penderia)

func imbas_menggunakan_skala_inspector() -> void:
	var semua_badan = area_penderia.get_overlapping_bodies()
	var semua_kawasan = area_penderia.get_overlapping_areas()
	var atas_lantai: bool = false
	var kena_halangan: bool = false

	for body in semua_badan:
		if not is_instance_valid(body): continue
		# layer 4 = environment (contoh: meteorit) -> halangan, bukan lantai
		if body.get_collision_layer_value(1) or body.get_collision_layer_value(2) or body.get_collision_layer_value(4):
			kena_halangan = true
			break

	if not kena_halangan:
		for area in semua_kawasan:
			if not is_instance_valid(area): continue
			if area.get_collision_layer_value(1) or area.get_collision_layer_value(2) or area.get_collision_layer_value(4):
				kena_halangan = true
				break

	# SELURUH tapak perabot mesti berada di atas zon bina (layer 3), bukan
	# sekadar bersentuhan di satu bucu.
	if not kena_halangan:
		atas_lantai = ZonBina.semua_dalam_zon_bina(area_penderia)

	if kena_halangan:
		if sprite: sprite.modulate = Color(1.0, 0.3, 0.3, 0.5)
		boleh_pasang = false
	elif atas_lantai and ada_cukup_bahan:
		if sprite: sprite.modulate = Color(0.3, 1.0, 0.3, 0.5)
		boleh_pasang = true
	else:
		if sprite: sprite.modulate = Color(1.0, 0.3, 0.3, 0.5)
		boleh_pasang = false
