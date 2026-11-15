@tool
extends Button

# 1. Tempat untuk heret fail .tscn pilihan anda di dalam panel Inspector
@export var scene_pilihan: PackedScene:
	set(nilai_baru):
		scene_pilihan = nilai_baru
		_kemaskini_nama_butang()

func _ready() -> void:
	# Hubungkan isyarat klik butang ke fungsi penukaran scene
	if not pressed.is_connected(_on_button_pressed):
		pressed.connect(_on_button_pressed)
	
	# Kemaskini teks nama butang semasa game mula diluncurkan
	_kemaskini_nama_butang()

# 2. Fungsi untuk menukar teks butang mengikut nama fail tanpa laluan "res://"
func _kemaskini_nama_butang() -> void:
	if scene_pilihan:
		var laluan_fail: String = scene_pilihan.resource_path # Contoh: "res://scene/level_3.tscn"
		
		# Ambil nama fail sahaja di hujung laluan (cth: "level_3.tscn")
		var nama_fail: String = laluan_fail.get_file()
		
		# Buang sambungan ".tscn" untuk menjadikan nama lebih bersih (cth: "level_3")
		var nama_bersih: String = nama_fail.get_basename()
		
		# Set teks pada butang
		text = nama_bersih
	else:
		text = "Select Scene (Empty)"

# 3. Fungsi yang akan berjalan apabila butang ini diklik oleh pemain
func _on_button_pressed() -> void:
	if scene_pilihan:
		print("Sistem Butang: Bersiap sedia menukar babak dengan transition -> ", scene_pilihan.resource_path)
		
		# Ambil laluan fail teks daripada PackedScene (Contoh: "res://scene/level_3.tscn")
		var laluan_scene: String = scene_pilihan.resource_path
		
		# Panggil fungsi transition global yang diletakkan dalam Autoload (Singleton)
		# Menggunakan call_deferred di sini amat selamat untuk mengelakkan crash pada iOS/Xogot
		SceneTransition.call_deferred("tukar_scene", laluan_scene)
	else:
		print("Amaran: Sila heret fail .tscn ke dalam Inspector butang ini terlebih dahulu!")
