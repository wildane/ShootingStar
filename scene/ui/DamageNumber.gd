class_name DamageNumber
extends Node2D

## Nombor damage yang terapung naik dan lesap di atas musuh.

const MASA_NAIK: float = 0.6
const JARAK_NAIK: float = 16.0
const SAIZ_FON: int = 10
const SAIZ_KOTAK: Vector2 = Vector2(30, 14)

const MASA_HP_KELIHATAN: float = 1.5
const MASA_HP_PUDAR: float = 0.35
const NAMA_NODE_HP: String = "DamageHpLabel"
const OFSET_HP: Vector2 = Vector2(0.0, -24.0)

## Papar nombor damage pada posisi dunia (contoh: atas kepala musuh).
static func tunjuk(dari_node: Node, pos_dunia: Vector2, jumlah: float) -> void:
	if not is_instance_valid(dari_node):
		return

	var pokok := dari_node.get_tree()
	if pokok == null:
		return

	var induk: Node = pokok.current_scene
	if induk == null:
		induk = dari_node

	var teks := Label.new()
	teks.text = str(int(round(jumlah)))

	var gaya := LabelSettings.new()
	gaya.font_size = SAIZ_FON
	gaya.font_color = Color(1.0, 0.93, 0.35, 1.0)
	gaya.outline_size = 3
	gaya.outline_color = Color(0.05, 0.02, 0.0, 1.0)
	teks.label_settings = gaya

	teks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	teks.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	teks.size = SAIZ_KOTAK
	teks.position = -SAIZ_KOTAK * 0.5

	var nombor := DamageNumber.new()
	nombor.z_index = 100
	nombor.z_as_relative = false
	nombor.add_child(teks)
	induk.add_child(nombor)

	# Posisi selepas masuk tree (global_position perlukan parent)
	nombor.global_position = pos_dunia + Vector2(randf_range(-5.0, 5.0), -10.0)

	var tw := nombor.create_tween()
	tw.set_parallel(true)
	tw.tween_property(nombor, "position", nombor.position + Vector2(0.0, -JARAK_NAIK), MASA_NAIK)
	tw.tween_property(nombor, "modulate", Color(1, 1, 1, 0), MASA_NAIK * 0.6).set_delay(MASA_NAIK * 0.4)
	tw.set_parallel(false)
	tw.tween_callback(nombor.queue_free)

## Papar/kemas kini label HP (contoh: 3/4) di atas musuh. Hilang jika tiada damage baharu.
static func tunjuk_hp(musuh: Node, hp_sekarang: int, hp_maks: int) -> void:
	if not is_instance_valid(musuh):
		return
	if hp_maks <= 0:
		return

	var label_hp: Label = musuh.get_node_or_null(NAMA_NODE_HP)
	if label_hp == null:
		label_hp = Label.new()
		label_hp.name = NAMA_NODE_HP
		label_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_hp.size = Vector2(40, 14)
		label_hp.position = OFSET_HP - label_hp.size * 0.5
		label_hp.z_index = 99
		label_hp.z_as_relative = false

		var gaya := LabelSettings.new()
		gaya.font_size = 9
		gaya.font_color = Color(1.0, 1.0, 1.0, 1.0)
		gaya.outline_size = 3
		gaya.outline_color = Color(0.0, 0.0, 0.0, 1.0)
		label_hp.label_settings = gaya

		musuh.add_child(label_hp)

	label_hp.text = str(max(hp_sekarang, 0)) + "/" + str(hp_maks)
	label_hp.modulate = Color(1, 1, 1, 1)
	label_hp.visible = true

	# Reset pemasa hilang: tween lama dibuang, tween baru bermula
	if label_hp.has_meta("tween_hp"):
		var tw_lama = label_hp.get_meta("tween_hp")
		if tw_lama is Tween and is_instance_valid(tw_lama):
			tw_lama.kill()

	var tw := label_hp.create_tween()
	tw.tween_interval(MASA_HP_KELIHATAN)
	tw.tween_property(label_hp, "modulate", Color(1, 1, 1, 0), MASA_HP_PUDAR)
	tw.tween_callback(func():
		if is_instance_valid(label_hp):
			label_hp.visible = false
	)
	label_hp.set_meta("tween_hp", tw)
