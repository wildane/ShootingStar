extends Node

@export_group("Health Settings")
@export var max_hp: int = 5
@export var panic_duration: float = 1.5

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
		if parent_fish.has_method("trigger_panic_movement"):
			parent_fish.trigger_panic_movement()
			
		if parent_fish.sprite:
			var tw = create_tween()
			tw.tween_property(parent_fish.sprite, "modulate", Color(2.0, 0.3, 0.3, 1.0), 0.1)
			tw.tween_property(parent_fish.sprite, "modulate", Color.WHITE, 0.2)

func play_death_sequence() -> void:
	parent_fish.is_dying = true
	Sfx.mainkan("letupan", -10.0, 1.15)
	
	if parent_fish.has_node("DetectionArea"):
		var area = parent_fish.get_node("DetectionArea")
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	
	if parent_fish.sprite:
		var tw = create_tween().set_loops(4)
		tw.tween_property(parent_fish.sprite, "modulate", Color(5.0, 5.0, 5.0, 1.0), 0.05)
		tw.tween_property(parent_fish.sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.05)
		
		var fade_tw = create_tween()
		fade_tw.tween_property(parent_fish.sprite, "modulate:a", 0.0, 0.5)
		
	await get_tree().create_timer(0.5).timeout
	
	if parent_fish.has_node("DropComponent"):
		parent_fish.get_node("DropComponent").trigger_drop()
	else:
		print("Galaxy Fish Error: Node anak 'DropComponent' tidak dijumpai!")
		
	parent_fish.queue_free()
