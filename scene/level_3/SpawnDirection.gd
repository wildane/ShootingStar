extends Control

@onready var arrow_sprite: Sprite2D = $ArrowSprite

# Koordinat sasaran yang tetap (X: 144, Y: 176)
var target_position: Vector2 = Vector2(144.0, 176.0)
var player: CharacterBody2D = null

func _process(_delta: float) -> void:
	# Jika local player belum spawn, cari semula di dalam kumpulan "Player"
	if not is_instance_valid(player):
		var all_players = get_tree().get_nodes_in_group("Player")
		
		for p in all_players:
			if p is CharacterBody2D and p.get_meta("local", false) == true:
				player = p
				break
				
		if not player:
			return
			
	# 1. Kira vektor arah dari posisi global Local Player menuju ke koordinat sasaran
	var direction_to_target: Vector2 = target_position - player.global_position
	
	# 2. DIUBAH: Gunakan 'rotation' biasa untuk memaksa Sprite2D berpusing pada paksinya sendiri
	if arrow_sprite:
		arrow_sprite.rotation = direction_to_target.angle()
		
		# Nota Tambahan: Jika imej anak panah asal anda menghadap ke ATAS, 
		# buang tanda '#' pada baris di bawah untuk aktifkan pembetulan sudut:
		# arrow_sprite.rotation = direction_to_target.angle() + deg_to_rad(90)
