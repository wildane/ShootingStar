extends SceneTree

# Ujian sistem baiki perabot:
#   1. Kos baiki ikut nisbah HP hilang (0.5 ke atas naik, 0.4 ke bawah turun).
#   2. Baiki hanya bila bahan cukup, kemudian HP pulih dan bar HP dibuang.
#   3. Panel Repair muncul hanya pada perabot rosak.
#   4. Perabot rosak yang dirobohkan tidak memulangkan bahan bina.
#
# Ujian guna autoload InventoryManager sebenar (beg dipulangkan selepas ujian),
# jadi tiada nod tiruan yang bertembung nama dengan autoload.

const REPAIR := preload("res://scene/level_3/build_system/RepairStruktur.gd")
const PANEL_REPAIR := preload("res://scene/level_3/build_system/PanelRepair.gd")
const BAR_HP := preload("res://scene/level_3/build_system/BarHpStruktur.gd")

var lulus: bool = true


class PerabotUjian extends Node2D:
	var kos: Array = []

	func kos_bina() -> Array:
		return kos


func _init() -> void:
	call_deferred("_jalan")


func _semak(syarat: bool, mesej: String) -> void:
	print(("LULUS  " if syarat else "GAGAL  ") + mesej)
	if not syarat:
		lulus = false


func _peta_perlu(kos: Array) -> Dictionary:
	var peta: Dictionary = {}
	for data in kos:
		peta[str(data.get("id", ""))] = int(data.get("diperlukan", 0))
	return peta


func _isi_beg(inv: Node, id_barang: String, banyak: int) -> void:
	inv.senarai_barang.clear()
	inv.tambah_item({"id": id_barang, "nama": id_barang, "kuantiti": banyak}, true)


func _jalan() -> void:
	var akar := Node2D.new()
	akar.name = "LevelUjian"
	root.add_child(akar)
	current_scene = akar

	var inv: Node = root.get_node_or_null("InventoryManager")
	_semak(inv != null, "autoload InventoryManager dijumpai")
	if inv == null:
		print("LULUS=", false)
		quit(1)
		return
	var simpanan_awal: Array = inv.senarai_barang.duplicate(true)
	inv.senarai_barang.clear()

	var perabot := PerabotUjian.new()
	perabot.name = "PerabotUjian"
	perabot.kos = [
		{"id": "besi", "nama": "Iron", "ikon": null, "scene_path": "", "diperlukan": 3},
		{"id": "ais", "nama": "Ice", "ikon": null, "scene_path": "", "diperlukan": 1},
	]
	akar.add_child(perabot)

	# --- 1. Perabot penuh: tiada kos, tiada baiki ---
	_semak(not REPAIR.rosak(perabot), "perabot penuh tak dianggap rosak")
	_semak(REPAIR.kos_repair(perabot).is_empty(), "kos baiki kosong bila HP penuh")
	_semak(not REPAIR.baiki(perabot), "baiki ditolak bila perabot tidak rosak")

	# --- 2. HP 1/2: separuh bahan, 1.5 -> 2, 0.5 -> 1 ---
	perabot.set_meta("hp_sasaran_maks", 2)
	perabot.set_meta("hp_serangan", 1)
	_semak(REPAIR.rosak(perabot), "HP 1/2 dianggap rosak")
	var perlu: Dictionary = _peta_perlu(REPAIR.kos_repair(perabot))
	_semak(int(perlu.get("besi", -1)) == 2, "3 × 0.5 = 1.5 dibundar jadi 2 besi")
	_semak(int(perlu.get("ais", -1)) == 1, "1 × 0.5 = 0.5 dibundar jadi 1 ais")

	# --- 3. HP 2/3: 1.0 kekal, 0.33 turun jadi 0 (bahan itu tak dikenakan) ---
	perabot.set_meta("hp_sasaran_maks", 3)
	perabot.set_meta("hp_serangan", 2)
	perlu = _peta_perlu(REPAIR.kos_repair(perabot))
	_semak(int(perlu.get("besi", -1)) == 1, "3 × 1/3 = 1 kekal 1 besi")
	_semak(not perlu.has("ais"), "1 × 1/3 = 0.33 turun jadi 0 (tiada ais)")

	# --- 4. HP 4/5: 0.6 naik jadi 1, 0.2 turun jadi 0 ---
	perabot.set_meta("hp_sasaran_maks", 5)
	perabot.set_meta("hp_serangan", 4)
	perlu = _peta_perlu(REPAIR.kos_repair(perabot))
	_semak(int(perlu.get("besi", -1)) == 1, "3 × 0.2 = 0.6 dibundar jadi 1 besi")
	_semak(not perlu.has("ais"), "1 × 0.2 = 0.2 dibundar jadi 0 (tiada ais)")

	# --- 5. Bahan tak cukup: baiki gagal, HP tak berubah ---
	perabot.set_meta("hp_sasaran_maks", 2)
	perabot.set_meta("hp_serangan", 1)
	inv.senarai_barang.clear()
	_semak(not REPAIR.baiki(perabot), "baiki gagal bila bahan tak cukup")
	_semak(REPAIR.hp_baki(perabot) == 1, "HP kekal 1 selepas baiki gagal")

	# --- 6. Bahan cukup: HP pulih, bahan ditolak, bar HP dibuang ---
	BAR_HP.papar(perabot, 1, 2)
	_semak(perabot.has_meta("bar_hp_struktur"), "bar HP wujud sebelum baiki")
	inv.tambah_item({"id": "besi", "nama": "Iron", "kuantiti": 2}, true)
	inv.tambah_item({"id": "ais", "nama": "Ice", "kuantiti": 1}, true)
	_semak(REPAIR.baiki(perabot), "baiki berjaya bila bahan cukup")
	_semak(not REPAIR.rosak(perabot), "HP pulih penuh selepas baiki")
	_semak(inv.bilangan_item("besi") == 0 and inv.bilangan_item("ais") == 0, "bahan baiki ditolak dari beg")
	_semak(not perabot.has_meta("bar_hp_struktur"), "bar HP dibuang selepas baiki")
	_semak(not REPAIR.baiki(perabot), "baiki kedua ditolak (perabot sudah penuh)")

	# --- 7. Panel Repair: sembunyi bila penuh, muncul + ikut bahan bila rosak ---
	var panel = PANEL_REPAIR.new()
	akar.add_child(panel)
	panel.sediakan(perabot)
	_semak(not panel.visible, "panel Repair tersembunyi pada perabot penuh")

	perabot.set_meta("hp_serangan", 1)
	panel.segarkan()
	_semak(panel.visible, "panel Repair muncul pada perabot rosak")
	var butang: Button = panel.get_node_or_null("ButangRepair")
	_semak(butang != null, "panel Repair ada butang Repair")
	_semak(butang != null and butang.disabled, "butang Repair mati bila bahan tak cukup")

	inv.tambah_item({"id": "besi", "nama": "Iron", "kuantiti": 2}, true)
	inv.tambah_item({"id": "ais", "nama": "Ice", "kuantiti": 1}, true)
	panel.segarkan()
	_semak(butang != null and not butang.disabled, "butang Repair hidup bila bahan cukup")
	butang.pressed.emit()
	_semak(not REPAIR.rosak(perabot), "tekan butang Repair memulihkan HP")
	_semak(not panel.visible, "panel Repair tersembunyi selepas baiki")

	# --- 8. Demolish: perabot penuh pulangkan bahan, perabot rosak tidak ---
	var adegan_meja := load("res://scene/level_3/build_system/kitchen_table/KitchenTable_Actual.tscn")
	inv.senarai_barang.clear()
	var meja_penuh: Node2D = adegan_meja.instantiate()
	akar.add_child(meja_penuh)
	meja_penuh.call("_on_butang_demolish_pressed")
	_semak(inv.bilangan_item("item_0002") == 1 and inv.bilangan_item("item_0001") == 3,
		"meja penuh yang dirobohkan pulangkan semua bahan bina")

	inv.senarai_barang.clear()
	var meja_rosak: Node2D = adegan_meja.instantiate()
	akar.add_child(meja_rosak)
	meja_rosak.set_meta("hp_sasaran_maks", 2)
	meja_rosak.set_meta("hp_serangan", 1)
	meja_rosak.call("_on_butang_demolish_pressed")
	_semak(inv.senarai_barang.is_empty(), "meja rosak yang dirobohkan tak pulangkan bahan langsung")

	# --- 9. Menu setiap perabot: panel Repair ada, butang craft mati bila rosak ---
	var senarai_menu: Array = [
		{"nama": "Kitchen", "laluan": "res://scene/level_3/build_system/kitchen_table/KitchenTable_Actual.tscn", "panel": "CanvasLayer/Pusat/MenuUI/VBoxContainer/PanelRepair", "kemas": "_kemas_kini_ui", "butang": "CanvasLayer/Pusat/MenuUI/VBoxContainer/ButangCraft"},
		{"nama": "Smelter", "laluan": "res://scene/level_3/build_system/smelter/Smelter_Actual.tscn", "panel": "CanvasLayer/Pusat/MenuUI/VBoxContainer/PanelRepair", "kemas": "_kemas_kini_ui", "butang": "CanvasLayer/Pusat/MenuUI/VBoxContainer/ButangCraft"},
		{"nama": "Fabricator", "laluan": "res://scene/level_3/build_system/fabricator/Fabricator_Actual.tscn", "panel": "CanvasLayer/MenuUI/VBoxContainer/PanelRepair", "kemas": "_kemas_kini_craft", "butang": "CanvasLayer/MenuUI/VBoxContainer/KandunganCraftDron/ButangCraft"},
		{"nama": "Research", "laluan": "res://scene/level_3/build_system/research_table/ResearchTable_Actual.tscn", "panel": "CanvasLayer/MenuUI/VBoxContainer/PanelRepair", "kemas": "_segarkan_repair", "butang": ""},
		{"nama": "Charging", "laluan": "res://scene/level_3/build_system/ChargingStation/ChargingStationActual.tscn", "panel": "CanvasLayer/MenuUI/VBoxContainer/PanelRepair", "kemas": "_segarkan_repair", "butang": ""},
	]
	for ujian in senarai_menu:
		inv.senarai_barang.clear()
		var perabot_menu: Node2D = load(str(ujian["laluan"])).instantiate()
		akar.add_child(perabot_menu)
		# Fabricator membina menu craftnya secara deferred.
		await process_frame
		perabot_menu.set_meta("hp_sasaran_maks", 2)
		perabot_menu.set_meta("hp_serangan", 1)
		perabot_menu.call(str(ujian["kemas"]))
		var panel_menu: Node = perabot_menu.get_node_or_null(str(ujian["panel"]))
		_semak(panel_menu != null, "%s: panel Repair wujud dalam menu" % str(ujian["nama"]))
		_semak(panel_menu != null and panel_menu.visible, "%s: panel Repair muncul bila perabot rosak" % str(ujian["nama"]))
		if not str(ujian["butang"]).is_empty():
			var butang_craft: Button = perabot_menu.get_node_or_null(str(ujian["butang"]))
			_semak(butang_craft != null, "%s: butang craft dijumpai" % str(ujian["nama"]))
			_semak(butang_craft != null and butang_craft.disabled, "%s: butang craft mati bila perabot rosak" % str(ujian["nama"]))

	# Beg pemain dipulihkan supaya ujian tak mengubah data permainan.
	inv.senarai_barang = simpanan_awal

	print("LULUS=", lulus)
	quit(0 if lulus else 1)
