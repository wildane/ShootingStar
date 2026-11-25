extends Node

@export_group("Player Health Settings")
@export var max_hp: int = 10

var hp: int = 10
var is_dead: bool = false
var active_hit_tween: Tween = null

@onready var player = get_parent()

# ==========================================
# AUTO-MINUM PROTEIN DRINK
# ==========================================
# Disimpan di komponen HP sendiri (bukan autoload) supaya ia tetap berjalan
# walau di mana projek dibuka. Minum sebaik HP turun dari HP penuh selagi ada
# stok dalam inventori, dengan cooldown 5 saat.
const ID_PROTEIN_DRINK: String = "item_0012"
const NAMA_PROTEIN_DRINK: String = "Protein Drink"
const IKON_PROTEIN_DRINK: Texture2D = preload("res://scene/Item/0012ProteinDrink/Image_protein_drink.png")
const PEMULIHAN_PROTEIN: int = 1
const COOLDOWN_PROTEIN: float = 5.0

var _baki_cooldown_protein: float = 0.0

func _ready() -> void:
	hp = max_hp

func _process(delta: float) -> void:
	if _baki_cooldown_protein > 0.0:
		_baki_cooldown_protein = maxf(_baki_cooldown_protein - delta, 0.0)
	_cuba_minum_protein()

# Minum satu Protein Drink kalau HP di bawah maksimum dan stok ada.
func _cuba_minum_protein() -> void:
	if not is_inside_tree() or is_dead or hp <= 0 or hp >= max_hp:
		return
	if _baki_cooldown_protein > 0.0:
		return
	# Hanya pemain (bukan mob) yang minum.
	if not is_instance_valid(player) or not player.is_in_group("Player"):
		return
	if not InventoryManager.tolak_item(ID_PROTEIN_DRINK, 1):
		return

	hp = mini(hp + PEMULIHAN_PROTEIN, max_hp)
	_baki_cooldown_protein = COOLDOWN_PROTEIN
	DropComponent.tunjuk_popup_bahan(
		IKON_PROTEIN_DRINK, -1, NAMA_PROTEIN_DRINK, player.global_position, player
	)
	print("Protein Drink: dimimum automatik. HP sekarang ", hp, "/", max_hp)

func take_damage(amount: float) -> void:
	if is_dead: return
	
	hp -= int(amount)
	print("PLAYER HP -> Hits left: ", hp, " / ", max_hp)

	# Nombor damage terapung di atas player (HP kekal dipaparkan di HUD skrin)
	if is_instance_valid(player):
		DamageNumber.tunjuk(player, player.global_position, amount)
	
	if hp <= 0:
		play_player_death_sequence()
	else:
		_cuba_minum_protein()
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
