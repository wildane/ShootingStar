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
	_semak(serangan.jarak_min_spawn >= 60.0,
		"spawn jauh dari tepi asteroid (%.0f-%.0f px)" % [serangan.jarak_min_spawn, serangan.tambahan_jarak_spawn])

	# --- Grid: sasaran terdekat + hancur 1 serangan ---
	var dekat: Dictionary = grid.sasaran_terdekat(Vector2(200, 200), 100.0)
	_semak(dekat.get("grid", Vector2i(-1, -1)) == Vector2i(12, 12),
		"sasaran terdekat = tile dinding (12,12)")
	_semak(grid.hancurkan(Vector2i(12, 12)), "hancurkan() buang tile dinding")
	var selepas: Dictionary = grid.sasaran_terdekat(Vector2(200, 200), 100.0)
	_semak(selepas.get("grid", Vector2i(-1, -1)) == Vector2i(13, 12),
		"tile dinding hilang, lantai jadi sasaran seterusnya")
	_semak(grid.sasaran_terdekat(Vector2(200, 200), 100.0, true).is_empty(),
		"raider abaikan lantai: hanya dinding/pintu jadi sasaran")
	_semak(grid.hancurkan(Vector2i(13, 12)), "hancurkan() buang tile lantai")
	_semak(grid.sasaran_terdekat(Vector2(200, 200), 100.0).is_empty(),
		"tiada tile lagi selepas kedua-duanya musnah")

	# --- HP struktur: dinding/pintu 3, lantai 1, dan HP ikut tersimpan ---
	grid.muat_data_save({"tiles": [
		{"x": 10, "y": 10, "jenis": 2},  # pintu
		{"x": 10, "y": 11, "jenis": 0},  # lantai
	]})
	_semak(grid.hp_tile(Vector2i(10, 10)) == 3, "pintu mula dengan HP 3")
	_semak(grid.hp_tile(Vector2i(10, 11)) == 1, "lantai mula dengan HP 1")
	_semak(not grid.kena_serangan(Vector2i(10, 10)), "pintu kena 1 serangan belum pecah")
	_semak(grid.hp_tile(Vector2i(10, 10)) == 2, "pintu HP tinggal 2/3 selepas 1 serangan")
	var badan_pintu: Node = grid.nod_tile(Vector2i(10, 10))
	var bar_pintu: Variant = badan_pintu.get_meta("bar_hp_struktur", null) if badan_pintu != null else null
	_semak(bar_pintu != null and int(bar_pintu.get("baki")) == 2 and int(bar_pintu.get("maksimum")) == 3,
		"bar HP muncul di atas pintu yang kena serangan (2/3)")
	_semak(bar_pintu != null and str(bar_pintu.call("teks_hp")) == "2/3",
		"bar HP tulis baki HP di tengah bar (2/3)")
	if bar_pintu != null:
		bar_pintu.call("_process", 5.0)
		_semak(float(bar_pintu.modulate.a) >= 0.99, "bar HP kekal selepas beberapa saat (tak pudar)")
	grid.muat_data_save(grid.dapatkan_data_save())
	_semak(grid.hp_tile(Vector2i(10, 10)) == 2, "HP tile pulih dari simpanan")
	var badan_pintu2: Node = grid.nod_tile(Vector2i(10, 10))
	var bar_pintu2: Variant = badan_pintu2.get_meta("bar_hp_struktur", null) if badan_pintu2 != null else null
	_semak(bar_pintu2 != null and int(bar_pintu2.get("baki")) == 2,
		"bar HP struktur rosak muncul semula selepas load")
	_semak(not grid.kena_serangan(Vector2i(10, 10)), "pintu kena 2 serangan belum pecah")
	_semak(grid.kena_serangan(Vector2i(10, 10)), "pintu pecah pada serangan ke-3")
	await create_timer(0.1).timeout
	_semak(not is_instance_valid(bar_pintu2),
		"bar HP hilang bersama pintu yang dirobohkan")
	_semak(grid.kena_serangan(Vector2i(10, 11)), "lantai pecah dengan 1 serangan")

	# --- Raider tembak dinding dari jauh, tak perlu sentuh dulu ---
	grid.muat_data_save({"tiles": [{"x": 18, "y": 12, "jenis": 1}]})  # dinding di (296,200)
	var raider_tembak: Node2D = load("res://scene/Mob/HuskLurkerRaider/HuskLurkerRaider.tscn").instantiate()
	raider_tembak.masa_teleport = 0.05
	akar.add_child(raider_tembak)
	raider_tembak.global_position = Vector2(200, 200)
	raider_tembak.set("mod_penyerang", true)
	raider_tembak.set("posisi_pangkalan", Vector2(200, 200))
	raider_tembak.jeda_serang = 0.25
	await create_timer(0.3).timeout
	_semak(not grid.sasaran_terdekat(Vector2(296, 200), 30.0).is_empty(),
		"lendir masih terbang: dinding belum pecah")
	_semak(grid.hp_tile(Vector2i(18, 12)) == 3, "dinding mula dengan HP 3")
	await create_timer(0.7).timeout
	var hp_dinding: int = grid.hp_tile(Vector2i(18, 12))
	_semak(hp_dinding > 0 and hp_dinding < 3,
		"dinding kena lendir tapi belum pecah (HP %d/3)" % hp_dinding)
	await create_timer(1.3).timeout
	_semak(grid.sasaran_terdekat(Vector2(296, 200), 30.0).is_empty(),
		"3 lendir kena dinding dari jauh (~96 px, jarak_serang %.0f): baru dinding pecah" % float(raider_tembak.get("jarak_serang")))
	raider_tembak.queue_free()

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
	raider.jeda_serang = 0.4

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
	await create_timer(0.35).timeout
	_semak(not bool(raider.get("_dalam_teleport")), "raider keluar dari teleport")
	_semak(is_instance_valid(perabot) and int(perabot.get_meta("hp_serangan", 2)) == 1,
		"perabot kena 1 lendir: HP tinggal 1/2, belum pecah")
	var bar_perabot: Variant = perabot.get_meta("bar_hp_struktur", null)
	_semak(bar_perabot != null and int(bar_perabot.get("baki")) == 1 and int(bar_perabot.get("maksimum")) == 2,
		"bar HP muncul di atas perabot yang kena lendir (1/2)")
	_semak(bar_perabot != null and str(bar_perabot.call("teks_hp")) == "1/2",
		"bar HP perabot tulis 1/2")
	await create_timer(0.7).timeout
	_semak(not is_instance_valid(perabot), "perabot kena 2 lendir: baru pecah")

	# --- Raider sampai pangkalan tanpa sasaran: jangan duduk diam, dekati player ---
	var player := Node2D.new()
	player.name = "SpaceShip"
	player.add_to_group("Player")
	akar.add_child(player)
	player.global_position = Vector2(400, 400)

	var raider_diam: Node2D = load("res://scene/Mob/HuskLurkerRaider/HuskLurkerRaider.tscn").instantiate()
	raider_diam.masa_teleport = 999.0
	akar.add_child(raider_diam)
	raider_diam.global_position = Vector2(200, 200)
	raider_diam.set("mod_penyerang", true)
	raider_diam.set("posisi_pangkalan", Vector2(200, 200))
	raider_diam.set("_pos_terakhir", Vector2(200, 200))
	var laju_diam: float = raider_diam.call("_gerak_penyerang", 0.2, player, 280.0, false)
	_semak(is_equal_approx(laju_diam, float(raider_diam.get("wander_speed"))),
		"tiada sasaran di pangkalan: raider tetap berjalan (%.1f), tak duduk diam" % laju_diam)
	var arah_ke_player: Vector2 = (player.global_position - raider_diam.global_position).normalized()
	_semak(Vector2(raider_diam.get("arah")).dot(arah_ke_player) > 0.9,
		"raider pusing ke arah player, bukan menembak sambil duduk")
	raider_diam.queue_free()

	# --- Sasaran dalam jarak serang: raider berhenti dan tembak dari jauh ---
	grid.muat_data_save({"tiles": [{"x": 18, "y": 12, "jenis": 1}]})  # dinding 96 px
	var raider_dekat: Node2D = load("res://scene/Mob/HuskLurkerRaider/HuskLurkerRaider.tscn").instantiate()
	raider_dekat.masa_teleport = 999.0
	akar.add_child(raider_dekat)
	raider_dekat.global_position = Vector2(200, 200)
	raider_dekat.set("mod_penyerang", true)
	raider_dekat.set("posisi_pangkalan", Vector2(200, 200))
	raider_dekat.set("_cooldown_serang", 0.5)  # jangan tembak dulu, uji gerak sahaja
	var laju_dekat: float = raider_dekat.call("_gerak_penyerang", 0.2, null, 999999.0, false)
	_semak(is_equal_approx(laju_dekat, 0.0),
		"sasaran dalam jarak serang: raider berhenti (%.1f), tembak dari jauh" % laju_dekat)
	_semak(raider_dekat.global_position.is_equal_approx(Vector2(200, 200)),
		"raider tak bergerak dekat sasaran dalam jarak tembak")

	# --- Satu serangan sahaja: tak tembak player dan struktur serentak ---
	var player_dekat: Node2D = Node2D.new()
	player_dekat.name = "SpaceShipDekat"
	player_dekat.add_to_group("Player")
	akar.add_child(player_dekat)
	player_dekat.global_position = Vector2(200, 300)  # 100 px dari raider
	raider_dekat.set("_cooldown_serang", 0.0)
	raider_dekat.set("cooldown_lendir", 0.0)
	raider_dekat.call("_gerak_penyerang", 0.016, player_dekat, 100.0, true)
	var bil_lendir: int = 0
	for anak in akar.get_children():
		if str(anak.name).begins_with("Lendir"):
			bil_lendir += 1
	_semak(bil_lendir == 1,
		"raider tembak satu sasaran sahaja setiap kitaran (lendir=%d)" % bil_lendir)
	player_dekat.queue_free()
	raider_dekat.queue_free()

	# --- Lendir tersasar (aim player) kena dinding: dinding tetap kena damage ---
	grid.muat_data_save({"tiles": [{"x": 18, "y": 12, "jenis": 1}]})  # dinding (296,200)
	var lendir_tersasar: Area2D = load("res://scene/Mob/HuskLurkerRaider/LendirRaider.tscn").instantiate()
	akar.add_child(lendir_tersasar)
	lendir_tersasar.global_position = Vector2(272, 200)  # mengarah ke dinding, bukan struktur
	lendir_tersasar.call("tembak", Vector2.RIGHT, 1)
	await create_timer(0.4).timeout
	_semak(grid.hp_tile(Vector2i(18, 12)) == 2,
		"lendir yang tersasar pada dinding tetap merosakkannya (HP 2/3)")

	# --- Player tak boleh tolak husk/raider: dua-dua pejal dan saling mengunci ---
	var astro: Node2D = load("res://scene/astro/astro2.tscn").instantiate()
	var husk: Node2D = load("res://scene/Mob/HuskLurker/HuskLurker.tscn").instantiate()
	var raider_uji: Node2D = load("res://scene/Mob/HuskLurkerRaider/HuskLurkerRaider.tscn").instantiate()
	for musuh in [husk, raider_uji]:
		_semak((astro.collision_mask & musuh.collision_layer) != 0,
			"player pejal dengan %s: tak boleh tolak (mask player %d)" % [musuh.name, astro.collision_mask])
		_semak((musuh.collision_mask & astro.collision_layer) != 0,
			"%s pejal dengan player" % musuh.name)
	astro.free()
	husk.free()
	raider_uji.free()

	# --- HP perabot masuk data slot dan pulih selepas load ---
	var simpan: Node2D = Node2D.new()
	simpan.name = "PerabotSimpan"
	var komponen: Node = load("res://scene/level_3/build_system/SaveComponent.gd").new()
	komponen.name = "SaveComponent"
	simpan.add_child(komponen)
	akar.add_child(simpan)
	simpan.set_meta("hp_serangan", 1)
	var data_perabot: Dictionary = komponen.call("get_data")
	_semak(int(data_perabot.get("hp_serangan", -1)) == 1, "HP perabot 1/2 masuk data slot")
	simpan.set_meta("hp_serangan", 2)  # seolah-olah baru dimuat semula
	var pengurus: Node = load("res://SaveManager.gd").new()
	pengurus.call("_pakai_data_objek", simpan, data_perabot)
	_semak(int(simpan.get_meta("hp_serangan", -1)) == 1, "HP perabot pulih 1/2 selepas load")
	pengurus.free()
	simpan.free()

	print("LULUS=", lulus)
	quit()
