extends "res://scene/level_3/build_system/smelter/smelter_actual.gd"

## Relau neutral milik pangkalan permulaan.
##
## Perabot ini BUKAN milik pemain: ia berada dalam kumpulan "PerabotNeutral",
## bukan "Furniture". Jadi raider tidak menjadikannya sasaran dan rangkaian
## kuasa pemain tidak mengawal bekalan elektriknya.
##
## Relau ini sentiasa bertenaga (tiada inverter diperlukan), hanya boleh
## melebur Steel, dan tiada butang demolish kerana ia bukan perabot pemain.

const KUMPULAN_NEUTRAL: String = "PerabotNeutral"

func _ready() -> void:
	# Buang resipi "Water + Oxygen" SEBELUM menu dibina: relau ini Steel sahaja.
	var hanya_steel: Array[Dictionary] = []
	if not senarai_resipi.is_empty():
		hanya_steel.append(senarai_resipi[0])
	senarai_resipi = hanya_steel

	super._ready()

	_jadikan_neutral()

	# Tiada butang demolish: perabot neutral tidak boleh dirobohkan pemain.
	if butang_demolish != null:
		butang_demolish.visible = false
	# Kad resipi air/oksigen disembunyikan (relau ini Steel sahaja).
	var kad_air := get_node_or_null("CanvasLayer/Pusat/MenuUI/VBoxContainer/SenaraiResipi/KadAir")
	if kad_air != null:
		kad_air.visible = false

	_kemas_kini_warna_visual()
	_kemas_kini_ui()

# Keluar dari sistem perabot pemain dan masuk kumpulan neutral.
func _jadikan_neutral() -> void:
	remove_from_group("Furniture")
	add_to_group(KUMPULAN_NEUTRAL)
	# Kumpulan berasingan supaya tutorial boleh menunjuk relau ini.
	add_to_group("Relau")
	# Jangan simpan ke slot simpanan: perabot ini sudah ada dalam scene level,
	# jadi menyimpannya akan mencipta pendua selepas load.
	var simpan := get_node_or_null("SaveComponent")
	if simpan != null:
		remove_child(simpan)
		simpan.free()
	# Tidak didaftarkan pada rangkaian kuasa pemain.
	PowerGridRef.nyahdaftar_perabot(self)
	has_power = true

# Relau neutral tiada sambungan kuasa, jadi sentiasa dianggap bertenaga.
func set_power_status(_status_elektrik: bool, _pembekal: Node2D = null) -> void:
	has_power = true
