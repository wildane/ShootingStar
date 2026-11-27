extends SceneTree

# Ujian sistem serangan pangkalan:
#   1. SeranganBalas cari asteroid pangkalan dan spawn di kelilingnya.
#   2. BuildGrid boleh cari tile terdekat dan menghancurkannya.
#   3. HuskLurkerRaider cari sasaran (tile / perabot) dan musnahkan 1 serangan.

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
	var akar := Node2D.new()
	akar.name = "LevelUjian"
	root.add_child(akar)
	current_scene = akar

	# --- Asteroid pangkalan ---
	var asteroid := AsteroidUjian.new()
	asteroid.name = "Asteroid"
	asteroid.jejari = 150.0
	asteroid.add_to_group("Asteroid")
	akar.add_child(asteroid)
	asteroid.global_position = Vector2(200, 200)

	# --- Grid binaan ---
	var grid: Node2D = load("res://scene/level_3/build_system/BuildGrid.gd").new()
	grid.name = "BuildGrid"
	akar.add_child(grid)
	grid.muat_data_save({
		"tiles": [
			{"x": 12, "y": 12, "jenis": 1},  # dinding, tengah (200,200)
			{"x": 13, "y": 12, "jenis": 0},  # lantai, tengah (216,200)
		],
	})

	# --- SeranganBalas: pusat/jejari asteroid + titik spawn keliling ---
	var serangan: Node = load("res://scene/Mob/SeranganBalas.gd").new()
	akar.add_child(serangan)
	var kawasan: Dictionary = serangan._kawasan_pangkalan()
	_semak(kawasan.get("pusat", Vector2.ZERO).is_equal_approx(Vector2(200, 200)),
		"pusat pangkalan ikut asteroid (%s)" % str(kawasan.get("pusat")))
	_semak(is_equal_approx(float(kawasan.get("jejari", 0.0)), 150.0),
		"jejari asteroid = 150")
	_semak(kawasan.get("pusat_bina", Vector2.ZERO).is_equal_approx(Vector2(208, 200)),
		"pusat binaan = purata tile (%s)" % str(kawasan.get("pusat_bina")))

	var keliling_ok: bool = true
	for i in 6:
		var titik: Vector2 = serangan._posisi_spawn(i, 6, Vector2(200, 200), 150.0)
		var jarak: float = titik.distance_to(Vector2(200, 200))
		if jarak < 150.0 + serangan.jarak_min_spawn - 0.5 \
			or jarak > 150.0 + serangan.tambahan_jarak_spawn + 0.5:
			keliling_ok = false
			print("  spawn %d jarak %.1f" % [i, jarak])
	_semak(keliling_ok, "semua spawn berada di keliling asteroid")

	# --- Grid: sasaran terdekat + hancur 1 serangan ---
	var dekat: Dictionary = grid.sasaran_terdekat(Vector2(200, 200), 100.0)
	_semak(dekat.get("grid", Vector2i(-1, -1)) == Vector2i(12, 12),
		"sasaran terdekat = tile dinding (12,12)")
	_semak(grid.hancurkan(Vector2i(12, 12)), "hancurkan() buang tile dinding")
	var selepas: Dictionary = grid.sasaran_terdekat(Vector2(200, 200), 100.0)
	_semak(selepas.get("grid", Vector2i(-1, -1)) == Vector2i(13, 12),
		"tile dinding hilang, lantai jadi sasaran seterusnya")
	_semak(grid.hancurkan(Vector2i(13, 12)), "hancurkan() buang tile lantai")
	_semak(grid.sasaran_terdekat(Vector2(200, 200), 100.0).is_empty(),
		"tiada tile lagi selepas kedua-duanya musnah")

	# --- Raider: cari perabot dan musnahkan satu serangan ---
	var perabot := Node2D.new()
	perabot.name = "PerabotUjian"
	perabot.add_to_group("Furniture")
	akar.add_child(perabot)
	perabot.global_position = Vector2(216, 200)

	var raider: Node2D = load("res://scene/Mob/HuskLurkerRaider/HuskLurkerRaider.tscn").instantiate()
	raider.masa_teleport = 0.05
	akar.add_child(raider)
	raider.global_position = Vector2(234, 205)
	raider.set("mod_penyerang", true)
	raider.set("posisi_pangkalan", Vector2(200, 200))

	# Raider kedua jauh dari pangkalan: laju mesti laju jalan biasa, bukan chase.
	var raider_jauh: Node2D = load("res://scene/Mob/HuskLurkerRaider/HuskLurkerRaider.tscn").instantiate()
	raider_jauh.masa_teleport = 999.0
	akar.add_child(raider_jauh)
	raider_jauh.global_position = Vector2(900, 900)
	raider_jauh.set("mod_penyerang", true)
	raider_jauh.set("posisi_pangkalan", Vector2(1100, 1100))
	var laju: float = raider_jauh.call("_gerak_penyerang", 0.016, null, 999999.0, false)
	_semak(is_equal_approx(laju, float(raider_jauh.get("wander_speed"))),
		"raider jalan laju normal (%.1f), bukan chase (%.1f)" % [laju, float(raider_jauh.get("chase_speed"))])
	_semak(not bool(raider_jauh.get("sedang_kejar")), "raider tak masuk mod chase")
	raider_jauh.queue_free()

	# Tunggu teleport habis, kemudian beri masa AI bertindak.
	await create_timer(0.6).timeout
	_semak(not bool(raider.get("_dalam_teleport")), "raider keluar dari teleport")
	_semak(not is_instance_valid(perabot), "raider musnahkan perabot dengan 1 serangan")

	print("LULUS=", lulus)
	quit()
