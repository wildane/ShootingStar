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
const OFSET_HP: Vector2 = Vector2(0.0, -20.0)

var _ikut_musuh: Node2D = null
var _ofset_ikut: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	if _ikut_musuh == null:
		return
	if not is_instance_valid(_ikut_musuh):
		queue_free()
		return
	global_position = _ikut_musuh.global_position + _ofset_ikut
	global_rotation = 0.0

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

	var penunjuk: DamageNumber = musuh.get_node_or_null(NAMA_NODE_HP)
	if penunjuk == null:
		penunjuk = DamageNumber.new()
		penunjuk.name = NAMA_NODE_HP
		penunjuk.z_index = 100
		penunjuk.z_as_relative = false
		penunjuk.set_as_top_level(true)

		# Bar HP bergaya sama dengan HUD player; saiz tetap untuk semua musuh
		var bar := HpBar.cipta(HpBar.SAIZ_MUSUH, HpBar.FON_MUSUH)
		bar.name = "BarHp"
		bar.position = -HpBar.SAIZ_MUSUH * 0.5
		penunjuk.add_child(bar)

		musuh.add_child(penunjuk)
		penunjuk._ikut_musuh = musuh as Node2D
		penunjuk._ofset_ikut = OFSET_HP

	var bar_hp: HpBar = penunjuk.get_node_or_null("BarHp")
	if bar_hp:
		bar_hp.tetapkan(float(hp_sekarang) / float(hp_maks), "%d/%d" % [max(hp_sekarang, 0), hp_maks])
	penunjuk.modulate = Color(1, 1, 1, 1)
	penunjuk.visible = true

	# Pastikan ikut musuh dan kekal tegak
	penunjuk._ikut_musuh = musuh as Node2D
	penunjuk._ofset_ikut = OFSET_HP
	penunjuk.global_rotation = 0.0

	# Reset pemasa hilang: tween lama dibuang, tween baru bermula
	if penunjuk.has_meta("tween_hp"):
		var tw_lama = penunjuk.get_meta("tween_hp")
		if tw_lama is Tween and is_instance_valid(tw_lama):
			tw_lama.kill()

	var tw := penunjuk.create_tween()
	tw.tween_interval(MASA_HP_KELIHATAN)
	tw.tween_property(penunjuk, "modulate", Color(1, 1, 1, 0), MASA_HP_PUDAR)
	tw.tween_callback(func():
		if is_instance_valid(penunjuk):
			penunjuk.visible = false
	)
	penunjuk.set_meta("tween_hp", tw)
