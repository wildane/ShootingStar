extends Button
## Butang bina Robot Pod dalam panel bina. Ikon diambil daripada PNG pod.

const PREVIEW: String = "res://scene/level_3/build_system/RobotPod/PodPreview.tscn"
const ACTUAL: String = "res://scene/level_3/build_system/RobotPod/PodActual.tscn"
const IKON: Texture2D = preload("res://scene/level_3/build_system/RobotPod/pod.png")

func _ready() -> void:
	if icon == null:
		icon = IKON
		expand_icon = true
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _pressed() -> void:
	# Tekan semula jenis yang sama = batal, tekan bangunan lain = tukar preview
	BuildManager.tukar_atau_batal_pembinaan(PREVIEW, ACTUAL)
	_tutup_panel_bina()
	release_focus()

# Tutup panel ikon bangunan selepas satu jenis dipilih.
func _tutup_panel_bina() -> void:
	var nod: Node = get_parent()
	while nod != null:
		if nod.has_method("tutup_menu_cepat"):
			nod.tutup_menu_cepat()
			return
		nod = nod.get_parent()
