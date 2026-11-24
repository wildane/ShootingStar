extends SceneTree

## Ujian regresi headless untuk PowerGrid (Idea 8).
## Jalankan: Godot --headless --path . -s res://tests/test_power_grid.gd

const PowerGridRef = preload("res://scene/level_3/build_system/PowerInverter/PowerGrid.gd")

var _lulus := 0
var _gagal := 0

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
	func _set_kuasa_kosong() -> void:
		total_power_supply = 0.0
		total_power_requirement = 0.0
		baki_tenaga = 0.0
	func _kemas_kini_status_perabot_tiada_kuasa() -> void:
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
	await _uji_asas()
	await _uji_tiada_inverter_bersihkan()
	await _uji_rujukan_inverter_tidak_sah()
	await _uji_multi_inverter()
	await _uji_incremental_perabot()
	await _uji_nyahdaftar_solar()
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

func _uji_asas() -> void:
	print("Ujian asas bekalan/keperluan")
	PowerGridRef.reset()
	var inv := _buat_inverter(Vector2(0, 0))
	var s := _buat_solar(Vector2(100, 0), 100.0)
	var p := _buat_perabot(Vector2(50, 0), 20.0)
	_proses()
	_assert("perabot dapat kuasa", p.has_power and p.inverter_pembekal == inv)
	_assert("inverter kira bekalan", inv.total_power_supply == 100.0)
	_assert("inverter kira keperluan", inv.total_power_requirement == 20.0)
	_assert("baki betul", inv.baki_tenaga == 80.0)
	_bersih(p); _bersih(s); _bersih(inv)
	await create_timer(0.05).timeout

func _uji_tiada_inverter_bersihkan() -> void:
	print("Ujian tiada inverter bersihkan kuasa")
	PowerGridRef.reset()
	var inv := _buat_inverter(Vector2(0, 0))
	var s := _buat_solar(Vector2(100, 0), 100.0)
	var p := _buat_perabot(Vector2(50, 0), 20.0)
	_proses()
	_assert("sebelum buang ada kuasa", p.has_power)
	PowerGridRef.nyahdaftar_inverter(inv)
	inv.queue_free()
	await create_timer(0.05).timeout
	_proses()
	_assert("selepas buang tiada kuasa", not p.has_power and p.inverter_pembekal == null)
	_assert("solar dibebaskan", s.inverter_pembeli == null)
	_bersih(p); _bersih(s)

func _uji_rujukan_inverter_tidak_sah() -> void:
	print("Ujian rujukan inverter tidak sah")
	PowerGridRef.reset()
	var inv := _buat_inverter(Vector2(0, 0))
	var p := _buat_perabot(Vector2(50, 0), 20.0)
	p.has_power = true
	p.inverter_pembekal = inv
	PowerGridRef.nyahdaftar_inverter(inv)
	inv.queue_free()
	await create_timer(0.05).timeout
	_proses()
	_assert("perabot tidak tersekat pada inverter freed", not p.has_power and p.inverter_pembekal == null)
	_bersih(p)

func _uji_multi_inverter() -> void:
	print("Ujian multi-inverter tidak rampas milik")
	PowerGridRef.reset()
	var inv1 := _buat_inverter(Vector2(0, 0))
	var inv2 := _buat_inverter(Vector2(800, 0))
	var s1 := _buat_solar(Vector2(100, 0), 100.0)
	var s2 := _buat_solar(Vector2(700, 0), 100.0)
	var p1 := _buat_perabot(Vector2(50, 0), 20.0)
	var p2 := _buat_perabot(Vector2(750, 0), 20.0)
	_proses()
	_assert("p1 kuasa inv1", p1.has_power and p1.inverter_pembekal == inv1)
	_assert("p2 kuasa inv2", p2.has_power and p2.inverter_pembekal == inv2)
	_assert("s1 milik inv1", s1.inverter_pembeli == inv1)
	_assert("s2 milik inv2", s2.inverter_pembeli == inv2)
	_bersih(p1); _bersih(p2); _bersih(s1); _bersih(s2); _bersih(inv1); _bersih(inv2)
	await create_timer(0.05).timeout

func _uji_incremental_perabot() -> void:
	print("Ujian dirty incremental perabot")
	PowerGridRef.reset()
	var inv := _buat_inverter(Vector2(0, 0))
	var s := _buat_solar(Vector2(100, 0), 100.0)
	_proses()
	var p := _buat_perabot(Vector2(50, 0), 20.0)
	_proses()
	_assert("perabot baharu dapat kuasa selepas daftar", p.has_power)
	PowerGridRef.nyahdaftar_perabot(p)
	p.queue_free()
	await create_timer(0.05).timeout
	_proses()
	_assert("keperluan turun selepas perabot buang", inv.total_power_requirement == 0.0)
	_bersih(s); _bersih(inv)

func _uji_nyahdaftar_solar() -> void:
	print("Ujian nyahdaftar solar")
	PowerGridRef.reset()
	var inv := _buat_inverter(Vector2(0, 0))
	var s := _buat_solar(Vector2(100, 0), 100.0)
	var p := _buat_perabot(Vector2(50, 0), 20.0)
	_proses()
	_assert("kuasa ada sebelum solar buang", p.has_power)
	PowerGridRef.nyahdaftar_solar(s)
	s.queue_free()
	await create_timer(0.05).timeout
	_proses()
	_assert("kuasa tiada selepas solar buang", not p.has_power)
	_bersih(p); _bersih(inv)


func _uji_tekanan_berulang() -> void:
	print("Ujian senario tekanan berulang (Idea 1)")
	PowerGridRef.reset()
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
	_assert("semua perabot diproses", int(stats.get("nod_diproses", 0)) >= 200)
	print("  [INFO] masa_ms=%.2f nod=%d inv=%d" % [us / 1000.0, int(stats.get("nod_diproses", 0)), int(stats.get("inverter_diproses", 0))])
	# Perubahan kecil: buang satu perabot, pastikan incremental/kemas kini berlaku
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
	await create_timer(0.05).timeout
