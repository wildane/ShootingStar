class_name BahanBinaan
extends RefCounted

## Kos bina perabot TIDAK disimpan (bukan pada bangunan, bukan dalam save).
## Semasa Demolish, bahan diambil semula terus daripada scene preview bangunan
## (fail_mats_1..5 / kuantiti_1..5). Peta dibina dengan membaca SceneState
## (tanpa instantiate node), jadi tiada lonjakan FPS bila demolish.

const FOLDER_BINA := "res://scene/level_3/build_system"
const BIL_SLOT: int = 5

# Cache dibina sekali sahaja: laluan scene bangunan -> senarai bahan bina.
static var _peta_bahan: Dictionary = {}
static var _peta_item: Dictionary = {} # laluan item -> data (id/nama/ikon/scene_path)
static var _sedia: bool = false


# Senarai bahan bina untuk satu bangunan. Utamakan kos_bina() pada skrip
# bangunan sebenar (data ikut preview, tiada scan/save). Fallback ke peta
# preview untuk bangunan lama yang belum ada kos_bina().
static func bahan_binaan(bangunan: Node) -> Array:
	if not is_instance_valid(bangunan):
		return []
	if bangunan.has_method("kos_bina"):
		var kos = bangunan.kos_bina()
		if kos is Array:
			return kos
	var laluan := str(bangunan.scene_file_path)
	if laluan.is_empty():
		return []
	if not _sedia:
		_imbas_preview()
	return _peta_bahan.get(laluan, [])


# Popup terapung bagi setiap bahan. tanda = -1 semasa bahan ditolak (merah),
# +1 semasa bahan dipulangkan (hijau). Setiap bahan disusun bertingkat supaya
# popup tidak bertindih.
static func papar_iklan(bahan: Array, pos_dunia: Vector2, sumber: Node, tanda: int) -> void:
	var ofset: float = 0.0
	for data in bahan:
		var banyak: int = int(data.get("diperlukan", 0))
		if banyak <= 0:
			continue
		var ikon = data.get("ikon")
		var tekstur: Texture2D = ikon if ikon is Texture2D else null
		DropComponent.tunjuk_popup_bahan(
			tekstur, tanda * banyak, str(data.get("nama", "")), pos_dunia + Vector2(0.0, ofset), sumber
		)
		ofset -= 9.0


# Pulangkan semua bahan bina bangunan ini ke inventori, kemudian tunjuk popup
# "+N <nama>". Bangunan yang previewnya tiada hanya dibuang tanpa pulangan.
static func pulangkan(bangunan: Node) -> void:
	var bahan := bahan_binaan(bangunan)
	if bahan.is_empty():
		return
	var inv = bangunan.get_node_or_null("/root/InventoryManager")
	if inv == null:
		return
	for data in bahan:
		var banyak: int = int(data.get("diperlukan", 0))
		for _n in banyak:
			inv.tambah_item({
				"id": str(data.get("id", "")),
				"nama": str(data.get("nama", "")),
				"ikon": data.get("ikon"),
				"scene_path": str(data.get("scene_path", "")),
			}, true)
	inv.kemas_kini_selepas_batch()
	papar_iklan(bahan, bangunan.global_position + Vector2(0.0, -10.0), bangunan, 1)


# Imbas scene preview di folder bina. Baca SceneState, jangan instantiate node,
# supaya tiada lonjakan FPS (instantiate preview + item boleh mahal).
static func _imbas_preview() -> void:
	_sedia = true
	for laluan in _semua_tscn(FOLDER_BINA):
		if not laluan.get_file().to_lower().contains("review"):
			continue
		var scene := load(laluan) as PackedScene
		if scene == null:
			continue
		var prop := _baca_prop_root(scene)
		var bangunan: String = str(prop.get("fail_bangunan_sebenar_tscn", ""))
		if bangunan.is_empty():
			continue
		_peta_bahan[bangunan] = _bahan_dari_prop(prop)


static func _bahan_dari_prop(prop: Dictionary) -> Array:
	var senarai: Array = []
	for i in range(1, BIL_SLOT + 1):
		var laluan: String = str(prop.get("fail_mats_%d" % i, ""))
		if laluan.is_empty():
			continue
		# Kuantiti lalai ialah 1 (sama seperti export default pada preview).
		# SceneState hanya simpan nilai yang ditulis dalam .tscn, jadi jika
		# kuantiti tidak ditetapkan, guna 1.
		var banyak: int = 1
		if prop.has("kuantiti_%d" % i):
			banyak = int(prop.get("kuantiti_%d" % i))
		elif not prop.has("fail_mats_%d" % i):
			banyak = 0
		if banyak <= 0:
			continue
		var item := _data_item(laluan)
		senarai.append({
			"id": str(item.get("id", "")),
			"nama": str(item.get("nama", laluan.get_file().get_basename().capitalize())),
			"ikon": item.get("ikon", null),
			"scene_path": laluan,
			"diperlukan": banyak,
		})
	return senarai


static func _data_item(laluan: String) -> Dictionary:
	if _peta_item.has(laluan):
		return _peta_item[laluan]
	var data := {
		"id": "",
		"nama": laluan.get_file().get_basename().capitalize(),
		"ikon": null,
	}
	var scene := load(laluan) as PackedScene
	if scene:
		# id_barang / nama_barang biasanya default skrip (tiada dalam SceneState),
		# jadi instantiate sekali sahaja per jenis item, cache, kemudian free.
		var item := scene.instantiate()
		if item:
			if "id_barang" in item:
				data["id"] = str(item.get("id_barang"))
			if "nama_barang" in item:
				data["nama"] = str(item.get("nama_barang"))
			if "ikon_barang" in item:
				data["ikon"] = item.get("ikon_barang")
			item.free()
	_peta_item[laluan] = data
	return data


# Baca semua property yang ditetapkan pada nod root scene (index 0) tanpa
# instantiate. Cukup untuk export var preview dan property item.
static func _baca_prop_root(scene: PackedScene) -> Dictionary:
	var hasil: Dictionary = {}
	var state := scene.get_state()
	if state == null or state.get_node_count() <= 0:
		return hasil
	for i in state.get_node_property_count(0):
		hasil[state.get_node_property_name(0, i)] = state.get_node_property_value(0, i)
	return hasil


static func _semua_tscn(folder: String) -> Array:
	var hasil: Array = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return hasil
	dir.list_dir_begin()
	var nama := dir.get_next()
	while nama != "":
		var laluan := folder.path_join(nama)
		if dir.current_is_dir():
			if not nama.begins_with("."):
				hasil.append_array(_semua_tscn(laluan))
		elif nama.to_lower().ends_with(".tscn"):
			hasil.append(laluan)
		nama = dir.get_next()
	dir.list_dir_end()
	return hasil
