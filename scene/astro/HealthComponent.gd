extends Node

@export_group("Player Health Settings")
@export var max_hp: int = 10

var hp: int = 10
var is_dead: bool = false
var active_hit_tween: Tween = null

@onready var player = get_parent()

func _ready() -> void:
	hp = max_hp

func take_damage(amount: float) -> void:
	if is_dead: return
	
	hp -= int(amount)
	print("PLAYER HP -> Hits left: ", hp, " / ", max_hp)

	# Nombor damage terapung + paparan HP di atas player (sama seperti musuh)
	if is_instance_valid(player):
		DamageNumber.tunjuk(player, player.global_position, amount)
		DamageNumber.tunjuk_hp(player, hp, max_hp)
	
	if hp <= 0:
		play_player_death_sequence()
	else:
		var target_sprite = _find_player_sprite()
		if is_instance_valid(target_sprite):
			_trigger_hit_flash_effect(target_sprite)
		else:
			print("Ralat Visual: HealthComponent gagal jumpa sebarang Sprite pada Player!")

func _find_player_sprite() -> Node2D:
	if player.get("sprite") != null:
		return player.get("sprite")
	if player.has_node("Sprite2D"):
		return player.get_node("Sprite2D")
	if player.has_node("AnimatedSprite2D"):
		return player.get_node("AnimatedSprite2D")
	for child in player.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null

func _trigger_hit_flash_effect(sprite_node: Node2D) -> void:
	if not is_instance_valid(sprite_node): return
	if active_hit_tween and active_hit_tween.is_valid():
		active_hit_tween.kill()

	var hit_color = Color(3.5, 0.2, 0.2, 1.0)
	var original_color = Color.WHITE

	active_hit_tween = create_tween()
	active_hit_tween.tween_property(sprite_node, "modulate", hit_color, 0.05)
	active_hit_tween.tween_property(sprite_node, "modulate:a", 0.2, 0.05)
	active_hit_tween.tween_property(sprite_node, "modulate", original_color, 0.05)
	active_hit_tween.tween_property(sprite_node, "modulate:a", 1.0, 0.05)
	active_hit_tween.tween_property(sprite_node, "modulate", hit_color, 0.05)
	active_hit_tween.tween_property(sprite_node, "modulate:a", 0.2, 0.05)
	active_hit_tween.tween_property(sprite_node, "modulate", original_color, 0.05)
	active_hit_tween.tween_property(sprite_node, "modulate:a", 1.0, 0.05)

func play_player_death_sequence() -> void:
	is_dead = true
	
	if active_hit_tween and active_hit_tween.is_valid():
		active_hit_tween.kill()
	
	player.set_physics_process(false)
	player.set_process(false)
	
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO
		player.set_collision_layer_value(1, false)
		player.set_collision_mask_value(1, false)
	
	var target_sprite = _find_player_sprite()
		
	if is_instance_valid(target_sprite):
		var tw = create_tween().set_loops(4)
		tw.tween_property(target_sprite, "modulate", Color(5.0, 5.0, 5.0, 1.0), 0.05)
		tw.tween_property(target_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.05)
		
		var fade_tw = create_tween()
		fade_tw.tween_property(target_sprite, "modulate:a", 0.0, 0.5)
		
	await get_tree().create_timer(0.6).timeout
	
	# 🌟 PANGGIL RESPAWN COMPONENT YANG BAHARU SECARA SELAMAT 🌟
	if player.has_node("RespawnComponent"):
		player.get_node("RespawnComponent").execute_player_respawn(self, target_sprite)
	else:
		print("Ralat Aliran: Node anak 'RespawnComponent' tidak dijumpai pada Player!")
		# Pelan sandaran jika anda terlupa pasang node: hidupkan cara lama
		player.global_position = Vector2.ZERO
		hp = max_hp
		is_dead = false
		if is_instance_valid(target_sprite): target_sprite.modulate = Color.WHITE
		player.set_physics_process(true)
		player.set_process(true)
