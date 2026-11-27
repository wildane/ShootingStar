extends Button

## Butang threat dalam group ikon menegak kiri (under ikon rumah).
##
## Butang ini memang ada dalam level_3.tscn (bukan dicipta oleh autoload),
## jadi ia sentiasa kelihatan sama seperti butang Build / Inventory / Drone /
## Home. Bila ditekan, ia minta autoload SeranganBalas membuka menu husk
## (menu gaya perabot: ikon husk, peratus threat, kiraan bunuh, pemasa).

const IKON: String = "res://scene/ui/threat_icon.png"

func _ready() -> void:
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Husk Threat"

	if icon == null and ResourceLoader.exists(IKON):
		icon = load(IKON)

	# Ikon gagal dimuat (PNG belum diimport): tunjuk butang merah "!" supaya
	# butang tetap kelihatan dan boleh ditekan.
	if icon == null:
		text = "!"
		add_theme_font_size_override("font_size", 16)
		add_theme_color_override("font_color", Color(1.0, 0.4, 0.35, 1.0))
		var latar := StyleBoxFlat.new()
		latar.bg_color = Color(0.35, 0.08, 0.1, 0.6)
		latar.border_color = Color(0.9, 0.25, 0.25, 0.8)
		latar.set_border_width_all(1)
		latar.set_corner_radius_all(4)
		add_theme_stylebox_override("normal", latar)

	if not pressed.is_connected(_tekan):
		pressed.connect(_tekan)

func _tekan() -> void:
	var serangan := get_node_or_null("/root/SeranganBalas")
	if serangan != null and serangan.has_method("buka_menu_threat"):
		serangan.buka_menu_threat()
	else:
		print("ButangThreat: autoload SeranganBalas tidak dijumpai")
