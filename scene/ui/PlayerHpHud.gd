extends Control

## HUD pemain kekal di bahagian atas skrin: bar HP (hati) + bar tenaga (kilat).

var _bar_hp: HpBar
var _bar_tenaga: HpBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Bar diletak di bawah kanan skrin supaya tak bertindih dengan UI build
	var susunan := VBoxContainer.new()
	susunan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	susunan.add_theme_constant_override("separation", 3)
	susunan.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	susunan.offset_left = -(HpBar.SAIZ_PEMAIN.x + 6.0)
	susunan.offset_top = -(HpBar.SAIZ_PEMAIN.y * 2.0 + 3.0 + 6.0)
	susunan.offset_right = -6.0
	susunan.offset_bottom = -6.0
	add_child(susunan)

	_bar_hp = HpBar.cipta(HpBar.SAIZ_PEMAIN, HpBar.FON_PEMAIN, "hp")
	susunan.add_child(_bar_hp)

	_bar_tenaga = HpBar.cipta(HpBar.SAIZ_PEMAIN, HpBar.FON_PEMAIN, "energi")
	susunan.add_child(_bar_tenaga)

func _process(_delta: float) -> void:
	if _bar_hp == null or _bar_tenaga == null:
		return

	var player := get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		_bar_hp.tetapkan(0.0, "--/--")
		_bar_tenaga.tetapkan(0.0, "--/--")
		return

	var hc: Node = player.get_node_or_null("HealthComponent")
	if hc == null or not ("hp" in hc) or not ("max_hp" in hc):
		_bar_hp.tetapkan(0.0, "--/--")
	else:
		var hp_sekarang: int = max(int(hc.hp), 0)
		var hp_maks: int = max(int(hc.max_hp), 1)
		_bar_hp.tetapkan(float(hp_sekarang) / float(hp_maks), "%d/%d" % [hp_sekarang, hp_maks])

	var tenaga: Node = player.get_node_or_null("EnergyComponent")
	if tenaga == null or not ("tenaga" in tenaga) or not ("max_energy" in tenaga):
		_bar_tenaga.tetapkan(0.0, "--/--")
	else:
		var tenaga_semasa: int = max(int(round(tenaga.tenaga)), 0)
		var tenaga_maks: int = max(int(round(tenaga.max_energy)), 1)
		var kadar: float = tenaga.pulih_sesaat if ("pulih_sesaat" in tenaga) else 0.0
		_bar_tenaga.tetapkan(float(tenaga_semasa) / float(tenaga_maks), "%d/%d" % [tenaga_semasa, tenaga_maks], "+%.1f/s" % kadar)
