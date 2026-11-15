extends Control

## HUD HP pemain kekal di bahagian atas skrin.

var _bar_hp: HpBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tengah := CenterContainer.new()
	tengah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tengah.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tengah)

	_bar_hp = HpBar.cipta(HpBar.SAIZ_PEMAIN, HpBar.FON_PEMAIN)
	tengah.add_child(_bar_hp)

func _process(_delta: float) -> void:
	if _bar_hp == null:
		return

	var player := get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		_bar_hp.tetapkan(0.0, "--/--")
		return

	var hc: Node = player.get_node_or_null("HealthComponent")
	if hc == null or not ("hp" in hc) or not ("max_hp" in hc):
		_bar_hp.tetapkan(0.0, "--/--")
		return

	var hp_sekarang: int = max(int(hc.hp), 0)
	var hp_maks: int = max(int(hc.max_hp), 1)
	_bar_hp.tetapkan(float(hp_sekarang) / float(hp_maks), "%d/%d" % [hp_sekarang, hp_maks])
