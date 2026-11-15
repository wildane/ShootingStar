extends Button

const PREVIEW = "res://scene/level_3/build_system/research_table/ResearchTable_Preview.tscn"
const ACTUAL = "res://scene/level_3/build_system/research_table/ResearchTable_Actual.tscn"

func _pressed():
	# Tekan semula jenis yang sama = batal, tekan bangunan lain = tukar preview
	BuildManager.tukar_atau_batal_pembinaan(PREVIEW, ACTUAL)
	
	if owner and owner.has_method("tutup_menu_cepat"): owner.tutup_menu_cepat()
	elif get_parent().has_method("tutup_menu_cepat"): get_parent().tutup_menu_cepat()
	release_focus()
