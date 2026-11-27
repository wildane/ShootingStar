extends SceneTree

# Ujian butang Ready di menu threat:
#   1. lancar_sekarang() lancar gelombang serta-merta walaupun pemasa masih jauh.
#   2. Selepas gelombang keluar, butang tak boleh tekan lagi (tiada gelombang menunggu).
#   3. Butang Ready dalam MenuThreat hidup/mati ikut keadaan threat.

class AsteroidUjian extends Node2D:
	var jejari: float = 150.0

	func boleh_bina_di(_pos: Vector2) -> bool:
		return true


var lulus: bool = true


func _init() -> void:
	call_deferred("_jalan")


func _semak(syarat: bool, mesej: String) -> void:
	print(("LULUS  " if syarat else "GAGAL  ") + mesej)
	if not syarat:
		lulus = false


func _jalan() -> void:
	StorThreat.reset()

	var akar := Node2D.new()
	akar.name = "LevelUjian"
	root.add_child(akar)
	current_scene = akar

	var bekas := Node2D.new()
	bekas.name = "Y_Sort_Container"
	akar.add_child(bekas)

	var asteroid := AsteroidUjian.new()
	asteroid.name = "Asteroid"
	asteroid.add_to_group("Asteroid")
	akar.add_child(asteroid)
	asteroid.global_position = Vector2(300, 300)

	var serangan: Node = load("res://scene/Mob/SeranganBalas.gd").new()
	serangan.name = "SeranganBalas"
	akar.add_child(serangan)

	# Tiada gelombang menunggu: Ready tak buat apa-apa.
	StorThreat.bunuh = 0
	StorThreat.masa_serang = -1.0
	_semak(serangan.call("lancar_sekarang") == false, "tanpa threat: Ready tak lancar apa-apa")
	_semak(bekas.get_child_count() == 0, "tiada raider keluar tanpa threat")

	# Gelombang menunggu (pemasa 120s): Ready lancar sekarang.
	StorThreat.bunuh = 20
	StorThreat.masa_serang = 120.0
	var berjaya: bool = serangan.call("lancar_sekarang")
	_semak(berjaya, "Ready lancar gelombang walaupun pemasa 120 saat")
	var bilangan: int = bekas.get_child_count()
	_semak(bilangan >= 1 and bilangan <= 2, "raider keluar ikut threat 20%% (%d raider)" % bilangan)
	_semak(StorThreat.masa_serang < 0.0, "pemasa berhenti selepas Ready")
	var semua_penyerang := true
	for anak in bekas.get_children():
		if not bool(anak.get("mod_penyerang")):
			semua_penyerang = false
	_semak(semua_penyerang, "semua raider guna mod penyerang")

	# Tekan lagi: tiada gelombang menunggu, jadi tak spawn gelombang kedua.
	_semak(serangan.call("lancar_sekarang") == false, "Ready kedua tak spawn gelombang baru")
	_semak(bekas.get_child_count() == bilangan, "jumlah raider tak bertambah")

	# Butang Ready dalam menu ikut keadaan.
	var menu: PanelContainer = load("res://scene/ui/MenuThreat.gd").new()
	akar.add_child(menu)
	var butang: Button = menu.get("_butang_ready")
	_semak(butang != null, "menu threat ada butang Ready")
	if butang != null:
		_semak(butang.disabled, "Ready mati bila tiada gelombang menunggu")
		StorThreat.masa_serang = 90.0
		menu.call("_kemas_kini")
		_semak(not butang.disabled, "Ready hidup bila gelombang menunggu")

	StorThreat.reset()
	print("LULUS=", lulus)
	quit(0 if lulus else 1)
