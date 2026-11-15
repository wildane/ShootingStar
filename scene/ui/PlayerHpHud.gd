extends Label

## Paparan HP pemain kekal di bahagian atas skrin.

func _ready() -> void:
	# Gaya asas supaya jelas di atas permainan
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 10)
	add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_theme_constant_override("outline_size", 3)
	text = "HP --/--"

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		text = "HP --/--"
		return

	var hc: Node = player.get_node_or_null("HealthComponent")
	if hc == null or not ("hp" in hc) or not ("max_hp" in hc):
		text = "HP --/--"
		return

	var hp_sekarang: int = max(int(hc.hp), 0)
	var hp_maks: int = int(hc.max_hp)
	text = "HP %d/%d" % [hp_sekarang, hp_maks]
