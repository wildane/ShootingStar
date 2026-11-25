extends Node

## Protein Drink dimimum secara automatik apabila HP pemain turun ke 1 atau
## kurang. Hanya berfungsi kalau ada Protein Drink di dalam inventori, dan
## selepas setiap minuman ada masa cooldown 5 saat.

const ID_PROTEIN_DRINK: String = "item_0012"
const PEMULIHAN_HP: int = 1
const MASA_COOLDOWN: float = 5.0

# Baki masa cooldown (saat). 0 bermaksud boleh minum.
var _baki_cooldown: float = 0.0

func _process(delta: float) -> void:
	if _baki_cooldown > 0.0:
		_baki_cooldown = maxf(_baki_cooldown - delta, 0.0)

	if _baki_cooldown > 0.0:
		return

	var hp_komp := _dapat_hp_komponen()
	if hp_komp == null or bool(hp_komp.get("is_dead")):
		return

	var hp_sekarang: int = int(hp_komp.get("hp"))
	if hp_sekarang > 1:
		return

	if InventoryManager.bilangan_item(ID_PROTEIN_DRINK) <= 0:
		return

	if not InventoryManager.tolak_item(ID_PROTEIN_DRINK, 1):
		return

	var hp_maks: int = int(hp_komp.get("max_hp"))
	hp_komp.set("hp", mini(hp_sekarang + PEMULIHAN_HP, hp_maks))
	_baki_cooldown = MASA_COOLDOWN
	print("Protein Drink: dimimum automatik. HP ", hp_sekarang, " -> ", hp_komp.get("hp"))

func _dapat_hp_komponen() -> Node:
	var pemain := get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(pemain):
		return null
	return pemain.get_node_or_null("HealthComponent")
