extends RefCounted

## Tema kongsi untuk semua menu perabot. Diselaraskan dengan panel SaveMenu:
## latar navy gelap, bingkai cyan, sudut bulat, teks biru muda.
##
## Guna: TemaPerabot.pasang(menu_ui)


static func pasang(menu: Control) -> void:
	if menu == null:
		return
	menu.theme = bina_tema()

static func bina_tema() -> Theme:
	var tema := Theme.new()

	# Kotak menu: latar navy gelap + bingkai cyan nipis. Guna StyleBoxFlat supaya
	# bingkai sentiasa tepat membalut kandungan, tak kira saiz menu.
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.043, 0.11, 0.165, 0.96)
	panel.border_color = Color(0.36, 0.9, 1, 0.9)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(6)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 4
	panel.set_content_margin_all(8.0)
	tema.set_stylebox("panel", "PanelContainer", panel)
	tema.set_stylebox("panel", "Panel", panel)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.054, 0.145, 0.211, 0.92)
	normal.border_color = Color(0.36, 0.9, 1, 0.7)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(4.0)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.098, 0.278, 0.38, 0.96)
	hover.border_color = Color(0.5, 0.97, 1, 1)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.2, 0.55, 0.68, 1)
	pressed.border_color = Color(0.75, 1, 1, 1)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.05, 0.09, 0.13, 0.7)
	disabled.border_color = Color(0.25, 0.42, 0.5, 0.5)

	# Fokus tidak mengisi latar (sama seperti SaveMenu).
	var fokus := normal.duplicate() as StyleBoxFlat
	fokus.draw_center = false
	fokus.bg_color = Color(0, 0, 0, 0)
	fokus.border_color = hover.border_color

	tema.set_stylebox("normal", "Button", normal)
	tema.set_stylebox("hover", "Button", hover)
	tema.set_stylebox("pressed", "Button", pressed)
	tema.set_stylebox("disabled", "Button", disabled)
	tema.set_stylebox("focus", "Button", fokus)
	tema.set_font_size("font_size", "Button", 10)
	tema.set_color("font_color", "Button", Color(0.85, 0.97, 1, 1))
	tema.set_color("font_hover_color", "Button", Color(1, 1, 1, 1))
	tema.set_color("font_pressed_color", "Button", Color(0.05, 0.12, 0.16, 1))
	tema.set_color("font_disabled_color", "Button", Color(0.46, 0.56, 0.63, 1))

	tema.set_color("font_color", "Label", Color(0.82, 0.95, 1, 1))
	tema.set_color("default_color", "RichTextLabel", Color(0.82, 0.95, 1, 1))
	tema.set_font_size("normal_font_size", "RichTextLabel", 9)

	# Bar kemajuan (Smelter) ikut warna cyan tema.
	var trek := StyleBoxFlat.new()
	trek.bg_color = Color(0.05, 0.09, 0.13, 0.9)
	trek.border_color = Color(0.36, 0.9, 1, 0.45)
	trek.set_border_width_all(1)
	trek.set_corner_radius_all(3)
	var isi := StyleBoxFlat.new()
	isi.bg_color = Color(0.36, 0.9, 1, 0.9)
	isi.set_corner_radius_all(3)
	tema.set_stylebox("background", "ProgressBar", trek)
	tema.set_stylebox("fill", "ProgressBar", isi)

	return tema
