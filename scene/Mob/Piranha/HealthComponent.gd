extends Node

@export_group("Health Settings")
@export var max_hp: int = 5

var hp: int = 5
@onready var parent_fish = get_parent() 

func _ready() -> void:
	hp = max_hp

func take_damage(amount: float) -> void:
	if parent_fish.is_dying: return
	
	hp -= int(amount)
	print("CHASE -> Galaxy Fish hits left: ", hp, " / ", max_hp)
	
	if hp <= 0:
		play_death_sequence()
	else:
		# 🌟 EFEK KELIP ALPHA (DIPERLAHAMKAN KE 0.1 SAAT) 🌟
		if parent_fish.sprite:
			var tw = create_tween()
			# Hilang (Alpha 0.0) -> Ada balik (Alpha 1.0) -> Ulang 2 kali
			tw.tween_property(parent_fish.sprite, "modulate:a", 0.0, 0.1)
			tw.tween_property(parent_fish.sprite, "modulate:a", 1.0, 0.1)
			tw.tween_property(parent_fish.sprite, "modulate:a", 0.0, 0.1)
			tw.tween_property(parent_fish.sprite, "modulate:a", 1.0, 0.1)

func play_death_sequence() -> void:
	parent_fish.is_dying = true
	Sfx.mainkan_di("letupan", parent_fish.global_position, -10.0, 1.15)
	
	# Menutup kawasan pengesan perlanggaran secara selamat
	if parent_fish.has_node("DetectionArea"):
		var area = parent_fish.get_node("DetectionArea")
		if area.has_method("set_deferred"):
			if "monitoring" in area: area.set_deferred("monitoring", false)
			if "monitorable" in area: area.set_deferred("monitorable", false)
	
	# Animasi kelipan putih sebelum ikan padam ( queue_free )
	if parent_fish.sprite:
		var tw = create_tween().set_loops(4)
		tw.tween_property(parent_fish.sprite, "modulate", Color(5.0, 5.0, 5.0, 1.0), 0.05)
		tw.tween_property(parent_fish.sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.05)
		
		var fade_tw = create_tween()
		fade_tw.tween_property(parent_fish.sprite, "modulate:a", 0.0, 0.5)
		
	await get_tree().create_timer(0.5).timeout
	
	# Mengaktifkan fungsi drop item sekiranya ada DropComponent
	if parent_fish.has_node("DropComponent"):
		var drop_node = parent_fish.get_node("DropComponent")
		if drop_node.has_method("trigger_drop"):
			drop_node.trigger_drop()
	else:
		print("Galaxy Fish Error: Node anak 'DropComponent' tidak dijumpai!")
		
	parent_fish.queue_free()
