extends Node2D

@onready var sprite = $Sprite2D

func _ready():
	# Paksa sentiasa berada di lapisan paling atas sekali
	z_index = 100 

# Fungsi tukar gambar yang selamat untuk mobile
func tukar_rupa_hologram(laluan_gambar: String):
	if sprite:
		# Muatkan gambar baharu ke dalam slot Texture Inspector
		var gambar_baru = load(laluan_gambar)
		if gambar_baru:
			sprite.texture = gambar_baru
