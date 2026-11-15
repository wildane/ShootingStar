extends Node

@export_group("Attack Settings")
@export var bite_cooldown_time: float = 1.0  # Jeda masa antara setiap gigitan (1 saat)
@export var bite_damage: int = 10             # Jumlah damage setiap kali gigit
@export var dash_distance: float = 10.0       # Jarak lajak sentakan serangan (10px)

var bite_cooldown_timer: float = 0.0
@onready var parent_entity: CharacterBody2D = get_parent()

func _physics_process(delta: float) -> void:
	if bite_cooldown_timer > 0.0:
		bite_cooldown_timer -= delta

func execute_bite_attack(target_player: Node2D) -> void:
	# Sekiranya cooldown belum habis, atau musuh sedang dalam proses dash serangan, sekat serangan
	if bite_cooldown_timer > 0.0 or parent_entity.get("is_attacking_dash") == true:
		return
		
	bite_cooldown_timer = bite_cooldown_time
	print(parent_entity.name, ": BERJAYA GIGIT PLAYER!")
	
	# --- 🌟 PENGUNCIAN ARAH & PUTARAN (ROTATION LOCK) 🌟 ---
	parent_entity.set("is_attacking_dash", true)
	parent_entity.velocity = Vector2.ZERO 
	
	# PEMBETULAN: Paksa piranha pusing menghadap player serta-merta sebelum mengira arah dash
	if is_instance_valid(target_player):
		var dir_to_player = (target_player.global_position - parent_entity.global_position).normalized()
		parent_entity.rotation = dir_to_player.angle() # Piranha akan pusing ke arah player di sini
	
	var start_pos = parent_entity.global_position
	# Sekarang, arah kanan (Vector2.RIGHT) piranha sudah tepat menghadap player
	var dash_offset = Vector2.RIGHT.rotated(parent_entity.rotation) * dash_distance
	var target_dash_pos = start_pos + dash_offset
	
	var attack_tween = parent_entity.create_tween().set_parallel(false)
	
	# Ambil rujukan sprite daripada parent jika ada untuk animasi scale
	var sprite = parent_entity.get_node_or_null("Sprite2D")
	if is_instance_valid(sprite):
		var scale_tween = parent_entity.create_tween()
		scale_tween.tween_property(sprite, "scale", Vector2(0.17, 0.17), 0.05)
		scale_tween.tween_property(sprite, "scale", Vector2(0.15, 0.15), 0.1)
	
	# Lajak ke hadapan (10px) - Mengikut arah putaran yang sudah dikunci tadi
	attack_tween.tween_property(parent_entity, "global_position", target_dash_pos, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Tarik ke belakang semula ke posisi asal secara lancar
	attack_tween.tween_property(parent_entity, "global_position", start_pos, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Lepaskan kunci pergerakan apabila animasi selesai
	attack_tween.tween_callback(func(): parent_entity.set("is_attacking_dash", false))

	# --- 🌟 MENCEDERAKAN PLAYER SECARA AUTOMATIK 🌟 ---
	if is_instance_valid(target_player):
		# Jika player mempunyai HealthComponent
		if target_player.has_node("HealthComponent"):
			target_player.get_node("HealthComponent").take_damage(bite_damage)
		# Jika player mempunyai fungsi take_damage terus pada skrip utamanya
		elif target_player.has_method("take_damage"):
			target_player.take_damage(bite_damage) 
		# Jika player menggunakan pembolehubah kesihatan biasa
		elif "health" in target_player:
			target_player.health -= bite_damage
