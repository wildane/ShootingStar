class_name BahanBinaan
extends RefCounted

## Bahan yang dibayar untuk membina perabot disimpan sebagai meta pada
## bangunan sebenar. Butang Demolish membaca meta ini dan memulangkan bahan
## yang sama, dengan popup "+N <nama>" yang serupa dengan popup drop smelter.

const META_BAHAN := "bahan_binaan"


# Ingat kos bina pada bangunan yang baru diletak.
static func simpan(bangunan: Node, bahan: Array) -> void:
	if not is_instance_valid(bangunan):
		return
	bangunan.set_meta(META_BAHAN, bahan.duplicate(true))


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
# "+N <nama>". Bangunan tanpa kos (diletak terus dalam scene/simpanan lama)
# hanya dibuang tanpa pulangan.
static func pulangkan(bangunan: Node) -> void:
	if not is_instance_valid(bangunan) or not bangunan.has_meta(META_BAHAN):
		return
	var bahan = bangunan.get_meta(META_BAHAN)
	if not (bahan is Array) or (bahan as Array).is_empty():
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
