extends "res://scene/level_3/build_system/ChargingStation/ChargingStationActual.gd"

## Stesen cas neutral milik pangkalan permulaan.
##
## Sama seperti relau neutral: bukan kumpulan "Furniture" (raider mengabaikan
## dan rangkaian kuasa pemain tidak mengawalnya), sentiasa bertenaga supaya
## terus mengecas pemain yang berada dalam radius, dan tiada butang demolish.

const KUMPULAN_NEUTRAL: String = "PerabotNeutral"

func _ready() -> void:
	super._ready()

	remove_from_group("Furniture")
	add_to_group(KUMPULAN_NEUTRAL)
	# Jangan simpan ke slot simpanan (elak pendua selepas load).
	var simpan := get_node_or_null("SaveComponent")
	if simpan != null:
		remove_child(simpan)
		simpan.free()
	# Tidak memerlukan inverter pemain.
	PowerGridRef.nyahdaftar_perabot(self)
	has_power = true

	if butang_demolish != null:
		butang_demolish.visible = false

	_kemas_kini_warna_visual()
	_kemas_kini_label_status()

# Stesen neutral tiada sambungan kuasa, jadi sentiasa dianggap bertenaga.
func set_power_status(_status_elektrik: bool, _pembekal: Node2D = null) -> void:
	has_power = true
