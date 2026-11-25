extends SceneTree

## Ujian regresi headless untuk PowerGrid hibrid.
## Jalankan: Godot --headless --path . -s res://tests/test_power_grid.gd

const PowerGridRef = preload("res://scene/level_3/build_system/PowerInverter/PowerGrid.gd")

var _lulus := 0
var _gagal := 0

class MockBuildGrid extends Node2D:
	const SAIZ_SEL: int = 16
	var _tile: Dictionary = {} # Vector2i -> jenis

	func _ready() -> void:
		add_to_group("BuildGrid")

	func tambah_lantai(sel: Vector2i) -> void:
		_tile[sel] = 0 # JENIS_LANTAI

	func tambah_dinding(sel: Vector2i) -> void:
		_tile[sel] = 1 # JENIS_DINDING

	func tambah_pintu(sel: Vector2i) -> void:
		_tile[sel] = 2 # JENIS_PINTU

	func buang_sel(sel: Vector2i) -> void:
		_tile.erase(sel)

class MockInverter extends Node2D:
	var radius_inverter_to_solar: float = 300.0
	var radius_inverter_to_furniture: float = 250.0
	var total_power_supply: float = 0.0
	var total_power_requirement: float = 0.0
	var baki_tenaga: float = 0.0
	var _grid_kotor: bool = true
	func _ready():
		add_to_group("PowerInverter")
	func _kemas_kini_paparan_skrin() -> void:
		pass

class MockSolar extends Node2D:
	var power_production: float = 100.0
	var jarak_cantuman: float = 300.0
	var inverter_pembeli: Node2D = null
	func _ready():
		add_to_group("SolarModule")
	func set_owner_inverter(inv: Node2D) -> void:
		inverter_pembeli = inv
	func release_owner_inverter(inv: Node2D) -> void:
		if inverter_pembeli == inv:
			inverter_pembeli = null

class MockPerabot extends Node2D:
	var power_required: float = 20.0
	var has_power: bool = false
	var inverter_pembekal: Node2D = null
	func _ready():
		add_to_group("Furniture")
	func set_power_status(status: bool, pembekal: Node2D = null) -> void:
		has_power = status
		if status:
			inverter_pembekal = pembekal
		else:
			if inverter_pembekal == pembekal or pembekal == null:
				inverter_pembekal = null

func _init() -> void:
	call_deferred("_jalankan")

func _jalankan() -> void:
	PowerGridRef.reset()
	await _uji_asas_rangkaian()
	await _uji_tiada_rangkaian()
	await _uji_dinding_jambatan()
	await _uji_solar_terdekat()
	await _uji_solar_luar_radius()
	await _uji_rangkaian_terpisah()
	await _uji_tiada_inverter_bersihkan()
	await _uji_nyahdaftar_solar()
	await _uji_bina_roboh_kotor()
	await _uji_tekanan_berulang()
	print("UJIAN POWERGRID: %d lulus, %d gagal" % [_lulus, _gagal])
	if _gagal > 0:
		quit(1)
	else:
		quit(0)

func _assert(nama: String, keadaan: bool) -> void:
	if keadaan:
		_lulus += 1
		print("  [OK] ", nama)
	else:
		_gagal += 1
		print("  [GAGAL] ", nama)

func _buat_grid() -> MockBuildGrid:
	var g := MockBuildGrid.new()
	root.add_child(g)
	return g

func _sel(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / 16.0), floori(pos.y / 16.0))

func _isi_lantai(grid: MockBuildGrid, dari: Vector2i, ke: Vector2i) -> void:
	for x in range(mini(dari.x, ke.x), maxi(dari.x, ke.x) + 1):
		for y in range(mini(dari.y, ke.y), maxi(dari.y, ke.y) + 1):
			grid.tambah_lantai(Vector2i(x, y))

func _buat_inverter(pos: Vector2) -> MockInverter:
	var n := MockInverter.new()
	n.global_position = pos
	root.add_child(n)
	PowerGridRef.daftar_inverter(n)
	return n

func _buat_solar(pos: Vector2, kuasa: float = 100.0) -> MockSolar:
	var n := MockSolar.new()
	n.global_position = pos
	n.power_production = kuasa
	root.add_child(n)
	PowerGridRef.daftar_solar(n)
	return n

func _buat_perabot(pos: Vector2, perlu: float = 20.0) -> MockPerabot:
	var n := MockPerabot.new()
	n.global_position = pos
	n.power_required = perlu
	root.add_child(n)
	PowerGridRef.daftar_perabot(n)
	return n

func _proses() -> void:
	PowerGridRef.proses(self, true)

func _bersih(nod: Node) -> void:
	if is_instance_valid(nod):
		nod.queue_free()

func _uji_asas_rangkaian() -> void:
	print("Ujian asas rangkaian struktur")
	PowerGridRef.reset()
	var grid := _buat_grid()
	_isi_lantai(grid, Vector2i(0, 0), Vector2i(10, 2))
	var inv := _buat_inverter(Vector2(16, 16))
	var s := _buat_solar(Vector2(100, 16), 100.0) # wireless dalam radius
	var p := _buat_perabot(Vector2(64, 16), 20.0)
	_proses()
	_assert("perabot atas rangkaian dapat kuasa", p.has_power and p.inverter_pembekal == inv)
	_assert("inverter kira bekalan rangkaian", inv.total_power_supply == 100.0)
	_assert("inverter kira keperluan rangkaian", inv.total_power_requirement == 20.0)
	_assert("baki betul", inv.baki_tenaga == 80.0)
	_assert("solar assign ke inverter", s.inverter_pembeli == inv)
	_bersih(p); _bersih(s); _bersih(inv); _bersih(grid)
	await create_timer(0.05).timeout

func _uji_tiada_rangkaian() -> void:
	print("Ujian tiada rangkaian struktur")
	PowerGridRef.reset()
	var grid := _buat_grid() # tiada tile
	var inv := _buat_inverter(Vector2(16, 16))
	var s := _buat_solar(Vector2(100, 16), 100.0)
	var p := _buat_perabot(Vector2(64, 16), 20.0)
	_proses()
	_assert("perabot tiada kuasa tanpa rangkaian", not p.has_power)
	_assert("solar masih assign ke inverter terdekat", s.inverter_pembeli == inv)
	_bersih(p); _bersih(s); _bersih(inv); _bersih(grid)
	await create_timer(0.05).timeout

func _uji_dinding_jambatan() -> void:
	print("Ujian lantai dipisah dinding/pintu bersambung")
	PowerGridRef.reset()
	var grid := _buat_grid()
	# Dua kawasan lantai dipisah ruang kosong, disambung oleh dinding.
	_isi_lantai(grid, Vector2i(0, 0), Vector2i(1, 0))
	_isi_lantai(grid, Vector2i(3, 0), Vector2i(4, 0))
	grid.tambah_dinding(Vector2i(2, 0))
	var inv := _buat_inverter(Vector2(8, 8))   # atas sel (0,0)
	var s := _buat_solar(Vector2(40, 8), 100.0)
	var p := _buat_perabot(Vector2(56, 8), 20.0) # atas sel (3,0), seberang dinding
	_proses()
	_assert("perabot seberang dinding dapat kuasa", p.has_power)
	# Ganti dinding dengan pintu pun patut bersambung.
	grid.buang_sel(Vector2i(2, 0))
	grid.tambah_pintu(Vector2i(2, 0))
	PowerGridRef.tanda_kotor_semua("uji_pintu")
	_proses()
	_assert("perabot seberang pintu dapat kuasa", p.has_power)
	_bersih(p); _bersih(s); _bersih(inv); _bersih(grid)
	await create_timer(0.05).timeout

func _uji_solar_terdekat() -> void:
	print("Ujian satu solar assign ke inverter terdekat")
	PowerGridRef.reset()
	var grid := _buat_grid()
	_isi_lantai(grid, Vector2i(0, 0), Vector2i(20, 2))
	var inv_dekat := _buat_inverter(Vector2(80, 16))   # jarak 20 dari solar
	var inv_jauh := _buat_inverter(Vector2(160, 16))   # jarak 60 dari solar
	var s := _buat_solar(Vector2(100, 16), 100.0)
	var p := _buat_perabot(Vector2(16, 16), 20.0)
	_proses()
	_assert("solar assign ke inverter terdekat", s.inverter_pembeli == inv_dekat)
	_assert("inverter terdekat dapat bekalan", inv_dekat.total_power_supply == 100.0)
	_assert("inverter jauh tidak jadi pemilik solar", s.inverter_pembeli != inv_jauh)
	_assert("perabot pada rangkaian sama dapat kuasa", p.has_power)
	_bersih(p); _bersih(s); _bersih(inv_jauh); _bersih(inv_dekat); _bersih(grid)
	await create_timer(0.05).timeout

func _uji_solar_luar_radius() -> void:
	print("Ujian solar luar radius tidak assign")
	PowerGridRef.reset()
	var grid := _buat_grid()
	_isi_lantai(grid, Vector2i(0, 0), Vector2i(5, 1))
	var inv := _buat_inverter(Vector2(16, 16))
	inv.radius_inverter_to_solar = 50.0
	var s := _buat_solar(Vector2(200, 16), 100.0)
	s.jarak_cantuman = 50.0
	var p := _buat_perabot(Vector2(32, 16), 20.0)
	_proses()
	_assert("solar luar radius tidak assign", s.inverter_pembeli == null)
	_assert("perabot tiada kuasa", not p.has_power)
	_bersih(p); _bersih(s); _bersih(inv); _bersih(grid)
	await create_timer(0.05).timeout

func _uji_rangkaian_terpisah() -> void:
	print("Ujian dua rangkaian terpisah")
	PowerGridRef.reset()
	var grid := _buat_grid()
	_isi_lantai(grid, Vector2i(0, 0), Vector2i(2, 0))   # rangkaian A
	_isi_lantai(grid, Vector2i(10, 0), Vector2i(12, 0)) # rangkaian B, terpisah
	var inv_a := _buat_inverter(Vector2(8, 8))
	var inv_b := _buat_inverter(Vector2(168, 8))
	var s_a := _buat_solar(Vector2(24, 8), 100.0)
	var s_b := _buat_solar(Vector2(184, 8), 100.0)
	var p_a := _buat_perabot(Vector2(40, 8), 20.0)  # atas rangkaian A
	var p_b := _buat_perabot(Vector2(200, 8), 20.0) # atas rangkaian B
	_proses()
	_assert("perabot A dapat kuasa rangkaian A", p_a.has_power)
	_assert("perabot B dapat kuasa rangkaian B", p_b.has_power)
	# Buang solar A: perabot A mati, perabot B kekal.
	PowerGridRef.nyahdaftar_solar(s_a)
	s_a.queue_free()
	await create_timer(0.05).timeout
	_proses()
	_assert("perabot A mati selepas solar A buang", not p_a.has_power)
	_assert("perabot B kekal hidup", p_b.has_power)
	_bersih(p_a); _bersih(p_b); _bersih(s_b); _bersih(inv_a); _bersih(inv_b); _bersih(grid)
	await create_timer(0.05).timeout

func _uji_tiada_inverter_bersihkan() -> void:
	print("Ujian tiada inverter bersihkan kuasa")
	PowerGridRef.reset()
	var grid := _buat_grid()
	_isi_lantai(grid, Vector2i(0, 0), Vector2i(10, 1))
	var inv := _buat_inverter(Vector2(16, 16))
	var s := _buat_solar(Vector2(80, 16), 100.0)
	var p := _buat_perabot(Vector2(48, 16), 20.0)
	_proses()
	_assert("sebelum buang ada kuasa", p.has_power)
	PowerGridRef.nyahdaftar_inverter(inv)
	inv.queue_free()
	await create_timer(0.05).timeout
	_proses()
	_assert("selepas buang tiada kuasa", not p.has_power and p.inverter_pembekal == null)
	_assert("solar dibebaskan", s.inverter_pembeli == null)
	_bersih(p); _bersih(s); _bersih(grid)
	await create_timer(0.05).timeout

func _uji_nyahdaftar_solar() -> void:
	print("Ujian nyahdaftar solar")
	PowerGridRef.reset()
	var grid := _buat_grid()
	_isi_lantai(grid, Vector2i(0, 0), Vector2i(10, 1))
	var inv := _buat_inverter(Vector2(16, 16))
	var s := _buat_solar(Vector2(80, 16), 100.0)
	var p := _buat_perabot(Vector2(48, 16), 20.0)
	_proses()
	_assert("kuasa ada sebelum solar buang", p.has_power)
	PowerGridRef.nyahdaftar_solar(s)
	s.queue_free()
	await create_timer(0.05).timeout
	_proses()
	_assert("kuasa tiada selepas solar buang", not p.has_power)
	_bersih(p); _bersih(inv); _bersih(grid)
	await create_timer(0.05).timeout

func _uji_bina_roboh_kotor() -> void:
	print("Ujian grid bina/roboh mencetus kira semula")
	PowerGridRef.reset()
	var grid := _buat_grid()
	_isi_lantai(grid, Vector2i(0, 0), Vector2i(1, 0))
	_isi_lantai(grid, Vector2i(3, 0), Vector2i(4, 0)) # terpisah
	var inv := _buat_inverter(Vector2(8, 8))      # sel (0,0)
	var s := _buat_solar(Vector2(24, 8), 100.0)
	var p := _buat_perabot(Vector2(56, 8), 20.0)  # sel (3,0)
	_proses()
	_assert("terpisah tiada kuasa", not p.has_power)
	# Sambung dengan lantai di tengah.
	grid.tambah_lantai(Vector2i(2, 0))
	PowerGridRef.tanda_kotor_semua("uji_bina")
	_proses()
	_assert("bersambung dapat kuasa", p.has_power)
	# Roboh jambatan.
	grid.buang_sel(Vector2i(2, 0))
	PowerGridRef.tanda_kotor_semua("uji_roboh")
	_proses()
	_assert("diputus tiada kuasa", not p.has_power)
	_bersih(p); _bersih(s); _bersih(inv); _bersih(grid)
	await create_timer(0.05).timeout

func _uji_tekanan_berulang() -> void:
	print("Ujian tekanan berulang")
	PowerGridRef.reset()
	var grid := _buat_grid()
	# Bina lantai besar untuk semua nod.
	_isi_lantai(grid, Vector2i(-5, -5), Vector2i(200, 50))
	var invs: Array = []
	var solars: Array = []
	var perabots: Array = []
	for i in range(20):
		invs.append(_buat_inverter(Vector2(i * 120, 0)))
	for i in range(100):
		solars.append(_buat_solar(Vector2((i % 20) * 120 + 20, (i / 20) * 20), 50.0))
	for i in range(200):
		perabots.append(_buat_perabot(Vector2((i % 20) * 120 + 40, (i / 20) * 10), 10.0))
	var t0 := Time.get_ticks_usec()
	PowerGridRef.proses(self, true)
	var us := Time.get_ticks_usec() - t0
	var stats: Dictionary = PowerGridRef.get_stats()
	_assert("tekanan selesai", stats.get("kiraan", 0) >= 1)
	_assert("semua nod diproses", int(stats.get("nod_diproses", 0)) >= 320)
	print("  [INFO] masa_ms=%.2f nod=%d inv=%d" % [us / 1000.0, int(stats.get("nod_diproses", 0)), int(stats.get("inverter_diproses", 0))])
	var buang: Node = perabots.pop_back()
	PowerGridRef.nyahdaftar_perabot(buang)
	buang.queue_free()
	await create_timer(0.05).timeout
	var t1 := Time.get_ticks_usec()
	PowerGridRef.proses(self, true)
	var us2 := Time.get_ticks_usec() - t1
	print("  [INFO] selepas ubah masa_ms=%.2f kiraan=%d" % [us2 / 1000.0, int(PowerGridRef.get_stats().get("kiraan", 0))])
	_assert("kemas kini selepas ubah", int(PowerGridRef.get_stats().get("kiraan", 0)) >= 2)
	for n in perabots:
		_bersih(n)
	for n in solars:
		_bersih(n)
	for n in invs:
		_bersih(n)
	_bersih(grid)
	await create_timer(0.05).timeout
