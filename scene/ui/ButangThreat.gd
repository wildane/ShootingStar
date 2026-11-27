extends Button

## Butang threat dalam group ikon menegak kiri (bawah ikon rumah).
##
## Butang ini nod sebenar dalam level_3.tscn, jadi ia sentiasa kelihatan sama
## seperti butang Build / Inventory / Drone / Home. Menu threat juga dibina
## oleh butang ini sendiri (tidak bergantung pada autoload untuk terbuka).

const IKON: String = "res://scene/ui/threat_icon.png"
const SkripMenu := preload("res://scene/ui/MenuThreat.gd")
const LAPIS_LAYER: int = 95

var _lapis: CanvasLayer
var _menu: PanelContainer

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
	_pastikan_menu()
	if _menu != null and is_instance_valid(_menu):
		_menu.tukar()

func _pastikan_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		return
	_lapis = CanvasLayer.new()
	_lapis.name = "LapisMenuThreat"
	_lapis.layer = LAPIS_LAYER
	add_child(_lapis)
	_menu = SkripMenu.new() as PanelContainer
	_lapis.add_child(_menu)

# Menu ini kekal di dalam scene level, jadi ia hilang bersama scene.
func tutup_menu_cepat() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.tutup()

func tutup_menu() -> void:
	tutup_menu_cepat()
