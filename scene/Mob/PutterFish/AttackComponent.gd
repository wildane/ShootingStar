extends Node

@export_group("Attack Settings")
@export var bite_damage: int = 10             # Jumlah damage setiap kali bersentuhan
@export var knockback_distance: float = 25.0  # Jarak tolak player ke belakang

@export_group("Pufferfish Custom Settings")
@export var detection_radius: float = 20.0    # Jarak 20px untuk terus aktif
@export var normal_scale: Vector2 = Vector2(1.0, 1.0)   
@export var inflated_scale: Vector2 = Vector2(3.0, 3.0) 
@export var puff_color: Color = Color(1.0, 0.4, 0.4)    
@export var inflate_animation_speed: float = 15.0 
@export var deflate_animation_speed: float = 4.0 

# Pengisytiharan wajib bagi mengelakkan Parser Error
@onready var parent_entity: CharacterBody2D = get_parent()

func execute_bite_attack(target_player: Node2D) -> void:
	print(parent_entity.name, ": RADIUS 20PX DIKESAN -> INSTANT ACTIVE!")
	
	# --- PAKSA IKAN KEMBUNG SERTA-MERTA ---
	parent_entity.set("is_inflated", true)
	
	# --- MENCEDERAKAN PLAYER SECARA AUTOMATIK ---
	if is_instance_valid(target_player):
		if target_player.has_node("HealthComponent"):
			target_player.get_node("HealthComponent").take_damage(bite_damage)
		elif target_player.has_method("take_damage"):
			target_player.take_damage(bite_damage) 
		elif "health" in target_player:
			target_player.health -= bite_damage

	# --- LOGIK SENTAKAN LUARAN (KNOCKBACK PLAYER) ---
	if is_instance_valid(target_player):
		var knockback_direction: Vector2 = (target_player.global_position - parent_entity.global_position).normalized()
		var target_knockback_pos: Vector2 = target_player.global_position + (knockback_direction * knockback_distance)
		
		var knockback_tween = parent_entity.create_tween()
		knockback_tween.tween_property(target_player, "global_position", target_knockback_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		if "target_pos" in target_player:
			target_player.target_pos = target_knockback_pos

	# --- KEMPISKAN BALIK VISUAL SECARA AUTOMATIK ---
	var deflate_tween = parent_entity.create_tween()
	deflate_tween.tween_interval(0.2) 
	deflate_tween.tween_callback(func():
		if is_instance_valid(parent_entity):
			parent_entity.set("is_inflated", false)
			if parent_entity.has_method("_pick_random_direction"):
				parent_entity._pick_random_direction()
	)
