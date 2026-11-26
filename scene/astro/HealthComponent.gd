extends Node

@export_group("Player Health Settings")
@export var max_hp: int = 10

var hp: int = 10
var is_dead: bool = false
var active_hit_tween: Tween = null

@onready var player = get_parent()

# ==========================================
# AUTO-PULIH HP: HP PILL (3 HP) / PROTEIN DRINK (1 HP)
# ==========================================
# Disimpan di komponen HP sendiri (bukan autoload) supaya ia tetap berjalan
# walau di mana projek dibuka. Pil dimakan untuk luka >= 3 HP, protein drink
# untuk luka kecil; kedua-duanya berkongsi cooldown 5 saat.
const ID_PROTEIN_DRINK: String = "item_0012"
const NAMA_PROTEIN_DRINK: String = "Protein Drink"
const IKON_PROTEIN_DRINK: Texture2D = preload("res://scene/Item/0012ProteinDrink/Image_protein_drink.png")
const PEMULIHAN_PROTEIN: int = 1

const ID_HP_PILL: String = "item_0013"
const NAMA_HP_PILL: String = "HP Pill"
const IKON_HP_PILL: Texture2D = preload("res://scene/Item/0013HPPill/Image_hp_pill.png")
const PEMULIHAN_PIL: int = 3

const COOLDOWN_PULIH: float = 5.0
var _baki_cooldown_pulih: float = 0.0

# ==========================================
# PERISAI MAGNETIK: SATU ITEM = SATU SERAPAN
# ==========================================
# Setiap Magnetic Shield dalam inventori menyerap satu serangan sepenuhnya,
# kemudian item itu ditolak dari beg. Resipi Fabricator mengeluarkan 10, jadi
# 10 serangan boleh ditahan selagi stok masih ada (tiada cooldown).
const ID_MAGNETIC_SHIELD: String = "item_0014"
const IKON_MAGNETIC_SHIELD: Texture2D = preload("res://scene/Item/0014MagneticShield/Image_shield.png")
const WARNA_PERISAI := Color(0.6, 1.0, 1.0, 1.0)

# Gelembung bulat bercahaya di sekeliling pemain (bukan ikon petak).
const SKRIP_KESAN_PERISAI: GDScript = preload("res://scene/astro/ShieldVisual.gd")
var _kesan_perisai: Node2D = null

func _ready() -> void:
	hp = max_hp

func _process(delta: float) -> void:
	if _baki_cooldown_pulih > 0.0:
		_baki_cooldown_pulih = maxf(_baki_cooldown_pulih - delta, 0.0)
	_cuba_pulih_hp()
	_kemas_kini_kesan_perisai()

func _cuba_pulih_hp() -> void:
	# Pil diutamakan untuk luka besar supaya 3 HP tidak membazir.
	if _cuba_makan_pil():
		return
	_cuba_minum_protein()

func _boleh_pulih() -> bool:
	if not is_inside_tree() or is_dead or hp <= 0 or hp >= max_hp:
		return false
	if _baki_cooldown_pulih > 0.0:
		return false
	# Hanya pemain (bukan mob) yang makan/minum.
	if not is_instance_valid(player) or not player.is_in_group("Player"):
		return false
	return true

# Makan satu HP Pill kalau luka sekurang-kurangnya 3 HP dan stok ada.
func _cuba_makan_pil() -> bool:
	if not _boleh_pulih():
		return false
	if max_hp - hp < PEMULIHAN_PIL:
		return false
	if InventoryManager.bilangan_item(ID_HP_PILL) <= 0:
		return false
	if not InventoryManager.tolak_item(ID_HP_PILL, 1):
		return false

	hp = mini(hp + PEMULIHAN_PIL, max_hp)
	_baki_cooldown_pulih = COOLDOWN_PULIH
	DropComponent.tunjuk_popup_bahan(
		IKON_HP_PILL, -1, NAMA_HP_PILL, player.global_position, player
	)
	print("HP Pill: dimakan automatik. HP sekarang ", hp, "/", max_hp)
	return true

# Minum satu Protein Drink kalau HP di bawah maksimum dan stok ada.
func _cuba_minum_protein() -> void:
	if not _boleh_pulih():
		return
	if not InventoryManager.tolak_item(ID_PROTEIN_DRINK, 1):
		return

	hp = mini(hp + PEMULIHAN_PROTEIN, max_hp)
	_baki_cooldown_pulih = COOLDOWN_PULIH
	DropComponent.tunjuk_popup_bahan(
		IKON_PROTEIN_DRINK, -1, NAMA_PROTEIN_DRINK, player.global_position, player
	)
	print("Protein Drink: dimimum automatik. HP sekarang ", hp, "/", max_hp)

# Perisai sedia digunakan: bukan mob, tidak mati, dan ada sekurang-kurangnya
# satu Magnetic Shield dalam inventori.
func perisai_sedia() -> bool:
	if is_dead:
		return false
	if not is_instance_valid(player) or not player.is_in_group("Player"):
		return false
	return InventoryManager.bilangan_item(ID_MAGNETIC_SHIELD) > 0

# Serap satu serangan penuh, kemudian tolak satu Magnetic Shield dari beg.
func _cuba_serap_dengan_perisai() -> bool:
	if not perisai_sedia():
		return false
	if not InventoryManager.tolak_item(ID_MAGNETIC_SHIELD, 1):
		return false
	var baki_perisai: int = InventoryManager.bilangan_item(ID_MAGNETIC_SHIELD)
	_papar_kesan_perisai()
	_popup_perisai("Shield blocked  x" + str(baki_perisai))
	print("Magnetic Shield: serangan diserap. Baki perisai: ", baki_perisai)
	return true

func _popup_perisai(teks: String) -> void:
	if not is_instance_valid(player):
		return
	DropComponent.tunjuk_popup_terapung(
		IKON_MAGNETIC_SHIELD, teks, player.global_position, self, WARNA_PERISAI
	)

# Gelembung perisai dipaparkan selagi pemain masih ada shield dalam beg.
func _kemas_kini_kesan_perisai() -> void:
	if not perisai_sedia():
		if is_instance_valid(_kesan_perisai):
			_kesan_perisai.visible = false
		return
	if not is_instance_valid(_kesan_perisai):
		_kesan_perisai = _cipta_kesan_perisai()
	if not is_instance_valid(_kesan_perisai):
		return
	_kesan_perisai.visible = true

# Cipta gelembung sebagai anak pemain supaya ia ikut bergerak secara automatik.
func _cipta_kesan_perisai() -> Node2D:
	if not is_instance_valid(player):
		return null
	var gelembung: Node2D = SKRIP_KESAN_PERISAI.new()
	gelembung.name = "KesanPerisai"
	gelembung.z_index = 1
	gelembung.set("jejari", _jejari_perisai())
	player.add_child(gelembung)
	gelembung.position = Vector2.ZERO
	return gelembung

# Jejari ikut saiz sprite pemain supaya gelembung sentiasa mengelilinginya.
func _jejari_perisai() -> float:
	var sprite: Node2D = _find_player_sprite()
	if is_instance_valid(sprite) and sprite is Sprite2D:
		var tekstur: Texture2D = (sprite as Sprite2D).texture
		if tekstur != null:
			var skala: Vector2 = sprite.global_scale.abs()
			var lebar: float = float(tekstur.get_width()) * skala.x
			var tinggi: float = float(tekstur.get_height()) * skala.y
			return maxf(lebar, tinggi) * 0.5 + 6.0
	return 18.0

# Kilauan gelembung sekejap sebagai tanda serangan diserap.
func _papar_kesan_perisai() -> void:
	if not is_instance_valid(_kesan_perisai):
		_kesan_perisai = _cipta_kesan_perisai()
	if not is_instance_valid(_kesan_perisai):
		return
	_kesan_perisai.visible = true
	_kesan_perisai.call("kilat")

func take_damage(amount: float) -> void:
	if is_dead: return

	# Perisai magnetik menyerap serangan penuh sebelum HP dikurangkan.
	if _cuba_serap_dengan_perisai():
		return
	
	hp -= int(amount)
	print("PLAYER HP -> Hits left: ", hp, " / ", max_hp)

	# Nombor damage terapung di atas player (HP kekal dipaparkan di HUD skrin)
	if is_instance_valid(player):
		DamageNumber.tunjuk(player, player.global_position, amount)
	
	if hp <= 0:
		play_player_death_sequence()
	else:
		_cuba_pulih_hp()
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
