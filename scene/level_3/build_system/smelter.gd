extends Button

const PREVIEW = "res://scene/level_3/build_system/smelter/Smelter_Preview.tscn"
const ACTUAL = "res://scene/level_3/build_system/smelter/Smelter_Actual.tscn"

func _pressed():
	# Tekan semula jenis yang sama = batal, tekan bangunan lain = tukar preview
	BuildManager.tukar_atau_batal_pembinaan(PREVIEW, ACTUAL)
	_tutup_panel_bina()
	release_focus()

# Tutup panel ikon bangunan selepas satu jenis dipilih. Butang ini duduk
# dalam ItemsPanel (bukan anak terus BuildSystem), jadi cari nod yang ada
# fungsi tutup_menu_cepat di atasnya.
func _tutup_panel_bina() -> void:
	var nod: Node = get_parent()
	while nod != null:
		if nod.has_method("tutup_menu_cepat"):
			nod.tutup_menu_cepat()
			return
		nod = nod.get_parent()
