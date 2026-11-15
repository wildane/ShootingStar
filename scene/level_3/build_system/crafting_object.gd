extends StaticBody2D # 💡 DAH TUKAR JADI STATICBODY2D SECARA MUTLAK

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func tetapkan_objek(texture_path, saiz_kotak: Vector2, nilai_skala: Vector2 = Vector2(1, 1)):
	
	# 1. Muatkan gambar asset ke dalam Sprite2D
	if texture_path is String:
		sprite.texture = load(texture_path)
	elif texture_path is Texture2D:
		sprite.texture = texture_path
	
	# 2. Bina bentuk kotak fizikal baharu mengikut ukuran asal objek
	var kotak_baru = RectangleShape2D.new()
	kotak_baru.size = saiz_kotak
	collision.shape = kotak_baru
	
	# 3. Mengaplikasikan skala kekal (Visual & Fizik akan auto-ikut mengecil)
	scale = nilai_skala
	
	# 4. 🎯 TETAPAN LAYER UNTUK SEKAT PLAYER & KESAN HOLOGRAM:
	# Kita set Layer = 1 supaya Player tersangkut, DAN pada masa yang sama, 
	# sistem hologram (Preview) kita semalam pun boleh kesan pelanggaran ini!
	collision_layer = 1
	collision_mask = 0
