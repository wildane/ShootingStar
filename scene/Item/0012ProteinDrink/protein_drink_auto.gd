extends Node

## Protein Drink dimimum secara automatik sebaik HP pemain turun 1 (atau lebih)
## dari HP penuh. Hanya berfungsi kalau ada Protein Drink di dalam inventori,
## dan selepas setiap minuman ada masa cooldown 5 saat.
## Setiap minuman memaparkan iklan terapung "-1 Protein Drink" yang sama
## dengan popup bahan binaan.

const ID_PROTEIN_DRINK: String = "item_0012"
const NAMA_PROTEIN_DRINK: String = "Protein Drink"
const IKON_PROTEIN_DRINK: Texture2D = preload("res://scene/Item/0012ProteinDrink/Image_protein_drink.png")
const PEMULIHAN_HP: int = 1
const MASA_COOLDOWN: float = 5.0

# Baki masa cooldown (saat). 0 bermaksud boleh minum.
var _baki_cooldown: float = 0.0

func _process(delta: float) -> void:
	if _baki_cooldown > 0.0:
		_baki_cooldown = maxf(_baki_cooldown - delta, 0.0)

	if _baki_cooldown > 0.0:
		return

	var pemain := get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(pemain):
		return
	var hp_komp := pemain.get_node_or_null("HealthComponent")
	if hp_komp == null or bool(hp_komp.get("is_dead")):
		return

	var hp_sekarang: int = int(hp_komp.get("hp"))
	var hp_maks: int = int(hp_komp.get("max_hp"))
	# Minum sebaik sahaja HP turun dari HP penuh (turun 1 atau lebih).
	if hp_sekarang <= 0 or hp_sekarang >= hp_maks:
		return

	if InventoryManager.bilangan_item(ID_PROTEIN_DRINK) <= 0:
		return

	if not InventoryManager.tolak_item(ID_PROTEIN_DRINK, 1):
		return

	hp_komp.set("hp", mini(hp_sekarang + PEMULIHAN_HP, hp_maks))
	_baki_cooldown = MASA_COOLDOWN
	_paparkan_popup(pemain)
	print("Protein Drink: dimimum automatik. HP ", hp_sekarang, " -> ", hp_komp.get("hp"))

# Iklan terapung "-1 Protein Drink" di atas pemain, sama gaya dengan popup bahan.
func _paparkan_popup(pemain: Node2D) -> void:
	DropComponent.tunjuk_popup_bahan(
		IKON_PROTEIN_DRINK, -1, NAMA_PROTEIN_DRINK, pemain.global_position, pemain
	)
