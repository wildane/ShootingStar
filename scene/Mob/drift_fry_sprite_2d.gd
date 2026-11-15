extends Sprite2D

# Setkan kelajuan animasi (0.1 saat = 10 FPS, kalau nak lambat tukar ke 0.15)
var masa_tunggu: float = 0.1
var pemasa: float = 0.0

func _ready():
	# Beritahu Godot susunan grid gambar baru kau (5 lajur, 2 baris)
	hframes = 5
	vframes = 2
	frame = 0

func _process(delta):
	pemasa += delta
	if pemasa >= masa_tunggu:
		pemasa = 0.0
		# Tukar frame ke gambar seterusnya (0 sampai 9) secara automatik
		frame = (frame + 1) % 10
