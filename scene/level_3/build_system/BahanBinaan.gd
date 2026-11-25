class_name BahanBinaan
extends RefCounted

## Kos bina perabot TIDAK disimpan (bukan pada bangunan, bukan dalam save).
## Semasa Demolish, bahan diambil semula terus daripada preview bangunan itu
## (fail_mats_1..5 / kuantiti_1..5 pada scene preview yang menunjuk ke scene
## bangunan ini), jadi demolish selepas load save tetap pulangkan bahan sama.

const FOLDER_BINA := "res://scene/level_3/build_system"
const BIL_SLOT: int = 5

# Cache dibina sekali sahaja: laluan scene bangunan -> senarai bahan bina.
static var _peta_bahan: Dictionary = {}
static var _sedia: bool = false


# Senarai bahan bina untuk satu bangunan (kosong jika previewnya tiada).
static func bahan_binaan(bangunan: Node) -> Array:
	if not is_instance_valid(bangunan):
		return []
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


# Imbas semua scene preview di folder bina dan petakan scene bangunan sebenar
# kepada senarai bahan binanya. Instantiate tanpa masuk tree: _ready tidak
# dijalankan, jadi tiada UI/side effect.
static func _imbas_preview() -> void:
	_sedia = true
	for laluan in _semua_tscn(FOLDER_BINA):
		if not laluan.get_file().to_lower().contains("review"):
			continue
		var scene := load(laluan) as PackedScene
		if scene == null:
			continue
		var contoh := scene.instantiate()
		if contoh == null:
			continue
		if "fail_bangunan_sebenar_tscn" in contoh:
			var bangunan: String = str(contoh.get("fail_bangunan_sebenar_tscn"))
			if not bangunan.is_empty():
				_peta_bahan[bangunan] = _bahan_preview(contoh)
		contoh.free()


static func _bahan_preview(contoh: Node) -> Array:
	var senarai: Array = []
	for i in range(1, BIL_SLOT + 1):
		var laluan: String = str(contoh.get("fail_mats_%d" % i))
		if laluan.is_empty():
			continue
		var banyak: int = int(contoh.get("kuantiti_%d" % i))
		if banyak <= 0:
			continue
		var data := {
			"id": "",
			"nama": laluan.get_file().get_basename().capitalize(),
			"ikon": null,
			"scene_path": laluan,
			"diperlukan": banyak,
		}
		var scene_item := load(laluan) as PackedScene
		if scene_item:
			var item := scene_item.instantiate()
			if item:
				if "id_barang" in item:
					data["id"] = str(item.id_barang)
				if "nama_barang" in item:
					data["nama"] = str(item.nama_barang)
				if "ikon_barang" in item:
					data["ikon"] = item.ikon_barang
				item.free()
		senarai.append(data)
	return senarai


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
