class_name RepairStruktur
extends RefCounted

## Baiki perabot pangkalan yang cedera akibat serangan husk.
##
## Kos baiki = kos bina × nisbah HP yang hilang. Setiap bahan dibundarkan
## berasingan: 0.5 atau lebih naik ke nombor besar, 0.4 atau kurang turun ke
## nombor kecil. Contoh meja dapur (1 Meteorite Ice + 3 Basic Iron Ore) pada
## HP 1/2: 1 × 0.5 = 0.5 -> 1 ais, 3 × 0.5 = 1.5 -> 2 bijih.
##
## HP perabot disimpan sebagai meta "hp_serangan" / "hp_sasaran_maks" (sama
## seperti yang ditulis HuskLurkerRaider dan SaveManager), jadi kos baiki kekal
## betul selepas load. Perabot yang masih penuh tidak perlu dibaiki.

const BAHAN := preload("res://scene/level_3/build_system/BahanBinaan.gd")
const BAR_HP := preload("res://scene/level_3/build_system/BarHpStruktur.gd")
const KESAN_RETAK := preload("res://scene/level_3/build_system/KesanRetak.gd")

const KUNCI_HP: String = "hp_serangan"
const KUNCI_MAKS: String = "hp_sasaran_maks"
## HP lalai perabot, sama dengan HuskLurkerRaider.hp_perabot.
const HP_LALAI: int = 2


static func hp_maks(perabot: Node) -> int:
	if not is_instance_valid(perabot):
		return HP_LALAI
	var maks: int = int(perabot.get_meta(KUNCI_MAKS, 0))
	if maks <= 0:
		# Tiada meta maks: guna HP semasa (perabot yang belum pernah diserang).
		var baki: int = int(perabot.get_meta(KUNCI_HP, HP_LALAI))
		maks = maxi(HP_LALAI, baki)
	return maxi(1, maks)


static func hp_baki(perabot: Node) -> int:
	if not is_instance_valid(perabot):
		return HP_LALAI
	if not perabot.has_meta(KUNCI_HP):
		return hp_maks(perabot)
	return clampi(int(perabot.get_meta(KUNCI_HP)), 0, hp_maks(perabot))


# Perabot rosak = HP tinggal kurang daripada HP maks.
static func rosak(perabot: Node) -> bool:
	if not is_instance_valid(perabot):
		return false
	return hp_baki(perabot) < hp_maks(perabot)


# Nisbah HP yang sudah hilang (0.0 .. 1.0).
static func nisbah_hilang(perabot: Node) -> float:
	if not is_instance_valid(perabot):
		return 0.0
	var maks: int = hp_maks(perabot)
	return clampf(float(maks - hp_baki(perabot)) / float(maks), 0.0, 1.0)


# Senarai bahan baiki. Hanya bahan yang perlu dibayar (> 0) dikembalikan.
static func kos_repair(perabot: Node) -> Array:
	var hasil: Array = []
	if not rosak(perabot):
		return hasil
	var nisbah: float = nisbah_hilang(perabot)
	for data in BAHAN.bahan_binaan(perabot):
		var asas: int = int(data.get("diperlukan", 0))
		if asas <= 0:
			continue
		# roundi: 1.5 -> 2, 1.3 -> 1, 0.5 -> 1, 0.4 -> 0.
		var perlu: int = roundi(float(asas) * nisbah)
		if perlu <= 0:
			continue
		var salinan: Dictionary = data.duplicate()
		salinan["diperlukan"] = perlu
		hasil.append(salinan)
	return hasil


# Adakah beg pemain cukup untuk semua bahan baiki?
static func cukup_bahan(perabot: Node, kos: Array = []) -> bool:
	var senarai: Array = kos if not kos.is_empty() else kos_repair(perabot)
	for data in senarai:
		if bilangan_dalam_beg(perabot, str(data.get("id", ""))) < int(data.get("diperlukan", 0)):
			return false
	return true


static func bilangan_dalam_beg(perabot: Node, id_barang: String) -> int:
	if id_barang.is_empty() or not is_instance_valid(perabot):
		return 0
	var inv: Node = perabot.get_node_or_null("/root/InventoryManager")
	if inv == null:
		return 0
	for barang in inv.get("senarai_barang"):
		if barang is Dictionary and str(barang.get("id", "")) == id_barang:
			return int(barang.get("kuantiti", 0))
	return 0


# Tolak bahan baiki, pulihkan HP penuh dan buang bar HP lama.
static func baiki(perabot: Node) -> bool:
	if not rosak(perabot):
		return false
	var kos: Array = kos_repair(perabot)
	if not cukup_bahan(perabot, kos):
		return false
	var inv: Node = perabot.get_node_or_null("/root/InventoryManager")
	if inv == null:
		return false
	for data in kos:
		inv.call("tolak_item", str(data.get("id", "")), int(data.get("diperlukan", 0)))
	if perabot is Node2D:
		BAHAN.papar_iklan(kos, (perabot as Node2D).global_position + Vector2(0.0, -10.0), perabot, -1)
	perabot.set_meta(KUNCI_HP, hp_maks(perabot))
	BAR_HP.buang(perabot)
	KESAN_RETAK.buang(perabot)
	return true
