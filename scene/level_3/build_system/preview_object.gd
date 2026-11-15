extends Node2D

@onready var sprite = $Sprite2D
@onready var area_penderia = $Area2D 

# 💡 KUNCI UTAMA: Pemboleh ubah wajib dinamakan 'boleh_pasang' supaya skrip level_3 boleh baca!
var boleh_pasang: bool = false

func _ready():
	z_index = 100 
	if area_penderia:
		area_penderia.monitoring = true
		area_penderia.monitorable = true

func _physics_process(_delta):
	if not is_instance_valid(area_penderia):
		return
		
	var list_area = area_penderia.get_overlapping_areas()
	# 👤 Ambil senarai badan fizikal untuk mengesan Player (CharacterBody2D)
	var list_bodies = area_penderia.get_overlapping_bodies()
	
	var kaunter_lantai: int = 0
	var melanggar_dinding: bool = false 
	var melanggar_player: bool = false
	
	# Semak sebarang perlanggaran objek bertumpu Area2D (Dinding Baru)
	for objek in list_area:
		if not is_instance_valid(objek):
			continue
		if objek.collision_layer == 1 or objek.collision_layer == 2:
			melanggar_dinding = true
			break 
		elif objek.collision_layer == 4 or objek.collision_layer == 3:
			kaunter_lantai += 1

	# 👤 Semak jika ada Player (CharacterBody2D) bertembung dengan meja preview
	for badan in list_bodies:
		if not is_instance_valid(badan):
			continue
		if badan is CharacterBody2D:
			melanggar_player = true
			break # Jumpa player! Terus sekat binaan

	# Keputusan warna modulasi dan mengemas kini status kelayakan binaan
	# 🎯 TAPISAN KETAT: Mesti atas lantai (> 0), TIADA dinding, DAN TIADA player
	if kaunter_lantai > 0 and not melanggar_dinding and not melanggar_player:
		if sprite: sprite.modulate = Color(0.3, 1.0, 0.3, 0.5) # Hijau Lutsinar (Selamat)
		boleh_pasang = true  # 💡 Ditukar kepada TRUE supaya butang confirm berfungsi!
	else:
		if sprite: sprite.modulate = Color(1.0, 0.3, 0.3, 0.5) # Merah Lutsinar (Disekat)
		boleh_pasang = false # 💡 Ditukar kepada FALSE jika terkeluar/kena dinding/kena player
