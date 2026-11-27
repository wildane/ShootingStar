class_name PowerGrid
extends RefCounted

## Pengurus kuasa hibrid:
## - Lantai/dinding/pintu yang bersambung 4-jiran (BuildGrid) membentuk satu
##   rangkaian kuasa.
## - Inverter menerima watt dari solar dalam radius secara wireless. Satu solar
##   hanya diassign kepada satu inverter terdekat.
## - Perabot atas rangkaian menggunakan bajet watt rangkaian itu.
## - Kiraan semula hanya bila state bina/roboh/perubahan pendaftaran berubah.
##
## API awam dikekalkan serasi dengan skrip sedia ada.

const SAIZ_SEL: float = 64.0
const SELA_KIRA_MINIMUM: float = 0.10
const BAJET_MS_DEFAULT: float = 4.0

# Registry nod aktif.
static var _inverters: Array = []          # Array[Node2D]
static var _solar: Array = []              # Array[Node2D]
static var _perabot: Array = []            # Array[Node2D] (power consumers)

# Keadaan dirty/coalesce.
static var _kotor: bool = true
static var _sedang_kira: bool = false
static var _masa_kira_terakhir: float = -1000.0
static var _perlu_kira_segera: bool = true

# Metrik debug (kos sifar bila tidak dibaca).
static var debug_aktif: bool = false
static var stat_kiraan: int = 0
static var stat_kiraan_penuh: int = 0
static var stat_kiraan_incremental: int = 0
static var stat_dirty_semua: int = 0
static var stat_dirty_inverter: int = 0
static var stat_masa_terakhir_ms: float = 0.0
static var stat_nod_diproses: int = 0
static var stat_inverter_diproses: int = 0
static var stat_solar_diproses: int = 0
static var stat_perabot_diproses: int = 0
static var stat_sebab_terakhir: String = "init"
static var stat_amaran: String = ""

static func _nod_sah(nod: Node) -> bool:
	return nod != null and is_instance_valid(nod) and not nod.is_queued_for_deletion() and nod.is_inside_tree()

static func reset() -> void:
	_inverters.clear()
	_solar.clear()
	_perabot.clear()
	_kotor = true
	_sedang_kira = false
	_masa_kira_terakhir = -1000.0
	_perlu_kira_segera = true
	stat_kiraan = 0
	stat_kiraan_penuh = 0
	stat_kiraan_incremental = 0
	stat_dirty_semua = 0
	stat_dirty_inverter = 0
	stat_masa_terakhir_ms = 0.0
	stat_nod_diproses = 0
	stat_inverter_diproses = 0
	stat_solar_diproses = 0
	stat_perabot_diproses = 0
	stat_sebab_terakhir = "reset"
	stat_amaran = ""

static func _padam_dari_array(arr: Array, nod: Node) -> void:
	var idx := arr.find(nod)
	if idx >= 0:
		arr.remove_at(idx)

# --- Pendaftaran awam ---

static func daftar_inverter(nod: Node2D) -> void:
	if nod == null or _inverters.find(nod) >= 0:
		return
	_inverters.append(nod)
	tanda_kotor_semua("daftar_inverter")

static func nyahdaftar_inverter(nod: Node2D) -> void:
	if nod == null:
		return
	_padam_dari_array(_inverters, nod)
	tanda_kotor_semua("nyahdaftar_inverter")

static func daftar_solar(nod: Node2D) -> void:
	if nod == null or _solar.find(nod) >= 0:
		return
	_solar.append(nod)
	tanda_kotor_semua("daftar_solar")

static func nyahdaftar_solar(nod: Node2D) -> void:
	if nod == null:
		return
	_padam_dari_array(_solar, nod)
	tanda_kotor_semua("nyahdaftar_solar")

static func daftar_perabot(nod: Node2D) -> void:
	if nod == null or _perabot.find(nod) >= 0:
		return
	_perabot.append(nod)
	tanda_kotor_semua("daftar_perabot")

static func nyahdaftar_perabot(nod: Node2D) -> void:
	if nod == null:
		return
	_padam_dari_array(_perabot, nod)
	tanda_kotor_semua("nyahdaftar_perabot")

static func kemas_kini_pos_nod(_nod: Node2D, _jenis: String) -> void:
	# Kedudukan dibaca semasa kira; tiada indeks spatial dikekalkan.
	tanda_kotor_semua("kemas_kini_pos_nod")

# --- Dirty ---

static func tanda_kotor_semua(sebab: String = "manual") -> void:
	_kotor = true
	_perlu_kira_segera = true
	stat_dirty_semua += 1
	stat_sebab_terakhir = sebab

static func tanda_kotor_inverter(_inv: Node2D, sebab: String = "inverter") -> void:
	# Sistem hibrid mengira semula rangkaian penuh bila kotor; lebih selamat
	# dan kosnya rendah kerana hanya dicetus oleh perubahan bina/roboh.
	stat_dirty_inverter += 1
	tanda_kotor_semua(sebab)

static func tanda_kotor_dari_pos(_pos: Vector2, _radius: float, sebab: String = "pos") -> void:
	tanda_kotor_semua(sebab)

# --- Senarai sah ---

static func _inverters_sah() -> Array:
	var hasil: Array = []
	for inv in _inverters:
		if _nod_sah(inv):
			hasil.append(inv)
	return hasil

static func _solar_sah() -> Array:
	var hasil: Array = []
	for s in _solar:
		if _nod_sah(s):
			hasil.append(s)
	return hasil

static func _perabot_sah() -> Array:
	var hasil: Array = []
	for p in _perabot:
		if _nod_sah(p) and "power_required" in p:
			hasil.append(p)
	return hasil

static func _bersihkan_registry() -> void:
	_inverters = _inverters_sah()
	_solar = _solar_sah()
	_perabot = _perabot_sah()

# --- BuildGrid / rangkaian struktur ---

static func _get_build_grid(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var grids := tree.get_nodes_in_group("BuildGrid")
	for g in grids:
		if g != null and is_instance_valid(g):
			return g
	return null

static func _sel_grid(grid: Node, pos_global: Vector2) -> Vector2i:
	var saiz_sel := 16
	if grid != null and "SAIZ_SEL" in grid:
		saiz_sel = int(grid.SAIZ_SEL)
	var lokal: Vector2 = grid.to_local(pos_global) if grid != null else pos_global
	return Vector2i(floori(lokal.x / float(saiz_sel)), floori(lokal.y / float(saiz_sel)))

static func _bina_komponen(tile: Dictionary) -> Dictionary:
	# Peta sel -> id komponen. Semua jenis tile (lantai/dinding/pintu) mengalir.
	var komponen: Dictionary = {}
	var id_komp := 0
	for sel in tile.keys():
		if komponen.has(sel):
			continue
		id_komp += 1
		var tindanan: Array = [sel]
		komponen[sel] = id_komp
		while not tindanan.is_empty():
			var cur: Vector2i = tindanan.pop_back()
			for arah in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var jiran: Vector2i = cur + arah
				if tile.has(jiran) and not komponen.has(jiran):
					komponen[jiran] = id_komp
					tindanan.append(jiran)
	return komponen

static func _komponen_nod(nod: Node2D, grid: Node, komponen: Dictionary) -> int:
	if grid == null:
		return -1
	var sel := _sel_grid(grid, nod.global_position)
	return int(komponen.get(sel, -1))

# Rect dunia bagi sesebuah zon bina (gabungan semua bentuk kolider anaknya).
static func _rect_zon(zon: Area2D) -> Rect2:
	var hasil := Rect2(zon.global_position, Vector2.ZERO)
	var ada: bool = false
	for anak in zon.get_children():
		if not (anak is CollisionShape2D) or anak.shape == null:
			continue
		var bentuk := anak as CollisionShape2D
		var setempat: Rect2 = bentuk.shape.get_rect()
		var xf: Transform2D = bentuk.global_transform
		var bucu := [
			xf * setempat.position,
			xf * Vector2(setempat.end.x, setempat.position.y),
			xf * setempat.end,
			xf * Vector2(setempat.position.x, setempat.end.y),
		]
		var min_v: Vector2 = bucu[0]
		var max_v: Vector2 = bucu[0]
		for s in bucu:
			min_v = min_v.min(s)
			max_v = max_v.max(s)
		var segi := Rect2(min_v, max_v - min_v)
		hasil = segi if not ada else hasil.merge(segi)
		ada = true
	return hasil

# Sel BuildGrid yang pusatnya berada di dalam rect ini.
static func _sel_dalam_rect(grid: Node, rect: Rect2) -> Array:
	var hasil: Array = []
	if grid == null:
		return hasil
	var saiz_sel := 16
	if "SAIZ_SEL" in grid:
		saiz_sel = int(grid.SAIZ_SEL)
	var kiri_atas := _sel_grid(grid, rect.position)
	var kanan_bawah := _sel_grid(grid, rect.end)
	for x in range(kiri_atas.x, kanan_bawah.x + 1):
		for y in range(kiri_atas.y, kanan_bawah.y + 1):
			var sel := Vector2i(x, y)
			var tengah: Vector2 = grid.to_global(Vector2((float(x) + 0.5) * float(saiz_sel), (float(y) + 0.5) * float(saiz_sel)))
			if rect.has_point(tengah):
				hasil.append(sel)
	return hasil

# Zon bina sedia ada dalam scene (contoh: lantai base pada png) bukan
# sebahagian daripada BuildGrid._tile, jadi PowerGrid menjadikannya rangkaian
# kuasa sendiri. Perabot/inverter di atas zon yang sama berkongsi bekalan, dan
# tile BuildGrid di dalam zon dicantumkan dengan rangkaian zon itu.
static func _senarai_zon(tree: SceneTree, grid: Node, komponen: Dictionary, tile: Dictionary) -> Array:
	var hasil: Array = []
	var id_zon := 0
	for nilai in komponen.values():
		id_zon = maxi(id_zon, int(nilai))
	for nod in tree.get_nodes_in_group("BuildableZone"):
		if not _nod_sah(nod) or not (nod is Area2D):
			continue
		id_zon += 1
		var rect := _rect_zon(nod as Area2D)
		var dicantum: Array = []
		for sel in _sel_dalam_rect(grid, rect):
			if tile.has(sel) and komponen.has(sel):
				var id_sel := int(komponen[sel])
				if dicantum.find(id_sel) < 0:
					dicantum.append(id_sel)
		if not dicantum.is_empty():
			for sel in komponen.keys():
				if dicantum.find(int(komponen[sel])) >= 0:
					komponen[sel] = id_zon
		hasil.append({"nod": nod, "rect": rect, "komp": id_zon})
	return hasil

# Komponen rangkaian bagi sesuatu nod: tile BuildGrid dahulu, kemudian zon
# bina sedia ada yang menutupi kedudukan nod.
static func _komponen_nod_zon(nod: Node2D, grid: Node, komponen: Dictionary, zon_info: Array) -> int:
	var komp := _komponen_nod(nod, grid, komponen)
	if komp >= 0:
		return komp
	var pos := nod.global_position
	for info in zon_info:
		var rect: Rect2 = info["rect"]
		if rect.has_point(pos):
			return int(info["komp"])
	return -1

# --- Proses utama ---

static func perlu_kira() -> bool:
	return _kotor

static func proses(tree: SceneTree, paksa: bool = false) -> void:
	if _sedang_kira or tree == null:
		return
	if not paksa and not _kotor:
		return
	var sekarang := Time.get_ticks_msec() / 1000.0
	if not paksa and not _perlu_kira_segera and sekarang - _masa_kira_terakhir < SELA_KIRA_MINIMUM:
		return

	_sedang_kira = true
	_kotor = false
	_perlu_kira_segera = false
	_masa_kira_terakhir = sekarang
	var mula_ms := Time.get_ticks_msec()

	_bersihkan_registry()
	_seed_dari_group_jika_perlu(tree)

	var inverters := _inverters_sah()
	var semua_solar := _solar_sah()
	var semua_perabot := _perabot_sah()

	# Bersihkan rujukan perabot/inverter tidak sah.
	_bersihkan_rujukan_perabot(semua_perabot)

	var grid := _get_build_grid(tree)
	var tile: Dictionary = {}
	if grid != null and "_tile" in grid:
		tile = grid._tile
	var komponen := _bina_komponen(tile)
	var zon_info := _senarai_zon(tree, grid, komponen, tile)

	# Reset paparan inverter dahulu; akan dikemas kini mengikut rangkaian.
	for inv: Node2D in inverters:
		_set_kuasa_inverter(inv, 0.0, 0.0)

	# 1) Solar wireless -> inverter terdekat (satu solar satu inverter).
	var kuasa_inverter: Dictionary = {} # instance_id -> float
	for inv: Node2D in inverters:
		kuasa_inverter[inv.get_instance_id()] = 0.0

	for solar: Node2D in semua_solar:
		var terbaik: Node2D = null
		var jarak_terbaik_sq := INF
		for inv: Node2D in inverters:
			var radius := 300.0
			if "jarak_cantuman" in solar:
				radius = float(solar.jarak_cantuman)
			elif "radius_inverter_to_solar" in inv:
				radius = float(inv.radius_inverter_to_solar)
			var dsq := solar.global_position.distance_squared_to(inv.global_position)
			if dsq > radius * radius:
				continue
			var id_inv := inv.get_instance_id()
			var id_terbaik := terbaik.get_instance_id() if terbaik != null else -1
			if dsq < jarak_terbaik_sq or (is_equal_approx(dsq, jarak_terbaik_sq) and (terbaik == null or id_inv < id_terbaik)):
				terbaik = inv
				jarak_terbaik_sq = dsq

		if terbaik != null:
			if solar.has_method("set_owner_inverter"):
				solar.set_owner_inverter(terbaik)
			else:
				solar.inverter_pembeli = terbaik
			var watt := 100.0
			if "power_production" in solar:
				watt = float(solar.power_production)
			var id_terbaik_inv := terbaik.get_instance_id()
			kuasa_inverter[id_terbaik_inv] = float(kuasa_inverter.get(id_terbaik_inv, 0.0)) + watt
		else:
			var pemilik = solar.inverter_pembeli if "inverter_pembeli" in solar else null
			if pemilik != null:
				if is_instance_valid(pemilik) and solar.has_method("release_owner_inverter"):
					solar.release_owner_inverter(pemilik)
				else:
					solar.inverter_pembeli = null

	# 2) Kumpul inverter ikut rangkaian struktur.
	var bekalan_rangkaian: Dictionary = {} # komp_id -> float
	var inverter_rangkaian: Dictionary = {} # komp_id -> Array[Node2D]
	for inv: Node2D in inverters:
		var komp := _komponen_nod_zon(inv, grid, komponen, zon_info)
		var bekalan := float(kuasa_inverter.get(inv.get_instance_id(), 0.0))
		if komp < 0:
			# Inverter tiada pada rangkaian struktur: tiada agihan ke perabot.
			_set_kuasa_inverter(inv, bekalan, 0.0)
			continue
		bekalan_rangkaian[komp] = float(bekalan_rangkaian.get(komp, 0.0)) + bekalan
		if not inverter_rangkaian.has(komp):
			inverter_rangkaian[komp] = []
		var senarai_inv: Array = inverter_rangkaian[komp]
		senarai_inv.append(inv)

	# 3) Agih kuasa rangkaian kepada perabot atas rangkaian yang sama.
	var guna_rangkaian: Dictionary = {} # komp_id -> float
	var baki_rangkaian: Dictionary = {} # komp_id -> float
	for komp in bekalan_rangkaian.keys():
		baki_rangkaian[komp] = float(bekalan_rangkaian[komp])
		guna_rangkaian[komp] = 0.0

	for perabot: Node2D in semua_perabot:
		if not perabot.has_method("set_power_status"):
			continue
		var komp_p := _komponen_nod_zon(perabot, grid, komponen, zon_info)
		if komp_p < 0 or not baki_rangkaian.has(komp_p):
			_matikan_perabot(perabot, null)
			continue

		var pembekal: Node2D = null
		var invs: Array = inverter_rangkaian.get(komp_p, [])
		if not invs.is_empty():
			pembekal = invs[0]

		var perlu := float(perabot.power_required) if "power_required" in perabot else 0.0
		var baki := float(baki_rangkaian.get(komp_p, 0.0))
		if baki >= perlu and float(bekalan_rangkaian.get(komp_p, 0.0)) > 0.0:
			perabot.set_power_status(true, pembekal)
			baki_rangkaian[komp_p] = baki - perlu
			guna_rangkaian[komp_p] = float(guna_rangkaian.get(komp_p, 0.0)) + perlu
		else:
			perabot.set_power_status(false, pembekal)

	# 4) Kemas kini paparan semua inverter dalam rangkaian.
	for komp in inverter_rangkaian.keys():
		var bekalan := float(bekalan_rangkaian.get(komp, 0.0))
		var guna := float(guna_rangkaian.get(komp, 0.0))
		for inv: Node2D in inverter_rangkaian[komp]:
			if _nod_sah(inv):
				_set_kuasa_inverter(inv, bekalan, guna)

	# Inverter yang tiada rangkaian tetapi tiada bekalan pun perlu paparan konsisten.
	for inv: Node2D in inverters:
		if not _nod_sah(inv):
			continue
		# Jika inverter berada pada rangkaian, ia sudah dikemas kini.
		var komp_inv := _komponen_nod_zon(inv, grid, komponen, zon_info)
		if komp_inv < 0:
			var bekalan_inv := float(kuasa_inverter.get(inv.get_instance_id(), 0.0))
			# Bekalan wireless diterima tetapi tiada rangkaian untuk diagih.
			_set_kuasa_inverter(inv, bekalan_inv, 0.0)

	_rekod_stat(mula_ms, inverters.size(), semua_solar.size(), semua_perabot.size())
	_sedang_kira = false

static func _matikan_perabot(perabot: Node, pembekal: Node2D) -> void:
	if not _nod_sah(perabot) or not perabot.has_method("set_power_status"):
		return
	var ada_kuasa: bool = "has_power" in perabot and bool(perabot.has_power)
	var ada_pembekal: bool = "inverter_pembekal" in perabot and perabot.inverter_pembekal != null
	if ada_kuasa or ada_pembekal or pembekal != null:
		perabot.set_power_status(false, pembekal)

static func _bersihkan_rujukan_perabot(semua_perabot: Array) -> void:
	for perabot: Node2D in semua_perabot:
		if not _nod_sah(perabot):
			continue
		var pembekal = perabot.inverter_pembekal if "inverter_pembekal" in perabot else null
		if pembekal != null and not _nod_sah(pembekal):
			if perabot.has_method("set_power_status"):
				perabot.set_power_status(false, null)

static func _set_kuasa_inverter(inv: Node2D, bekalan: float, guna: float) -> void:
	if not _nod_sah(inv):
		return
	var baki := bekalan - guna
	if "total_power_supply" in inv:
		inv.total_power_supply = bekalan
	if "total_power_requirement" in inv:
		inv.total_power_requirement = guna
	if "baki_tenaga" in inv:
		inv.baki_tenaga = baki
	if "_grid_kotor" in inv:
		inv._grid_kotor = false
	if inv.has_method("_kemas_kini_paparan_skrin"):
		inv._kemas_kini_paparan_skrin()

static func _seed_dari_group_jika_perlu(tree: SceneTree) -> void:
	if _inverters.is_empty():
		for n in tree.get_nodes_in_group("PowerInverter"):
			if _nod_sah(n) and n is Node2D and _inverters.find(n) < 0:
				_inverters.append(n)
	if _solar.is_empty():
		for n in tree.get_nodes_in_group("SolarModule"):
			if _nod_sah(n) and n is Node2D and _solar.find(n) < 0:
				_solar.append(n)
	if _perabot.is_empty():
		for n in tree.get_nodes_in_group("Furniture"):
			if _nod_sah(n) and n is Node2D and "power_required" in n and _perabot.find(n) < 0:
				_perabot.append(n)

static func _rekod_stat(mula_ms: int, inv_count: int, solar_count: int, perabot_count: int) -> void:
	stat_kiraan += 1
	stat_kiraan_penuh += 1
	stat_masa_terakhir_ms = float(Time.get_ticks_msec() - mula_ms)
	stat_inverter_diproses = inv_count
	stat_solar_diproses = solar_count
	stat_perabot_diproses = perabot_count
	stat_nod_diproses = inv_count + solar_count + perabot_count
	if stat_masa_terakhir_ms > BAJET_MS_DEFAULT:
		stat_amaran = "Kiraan kuasa melebihi bajet: %.2f ms" % stat_masa_terakhir_ms
	else:
		stat_amaran = ""

# --- Debug ---

static func get_stats() -> Dictionary:
	return {
		"kiraan": stat_kiraan,
		"kiraan_penuh": stat_kiraan_penuh,
		"kiraan_incremental": stat_kiraan_incremental,
		"dirty_semua": stat_dirty_semua,
		"dirty_inverter": stat_dirty_inverter,
		"masa_terakhir_ms": stat_masa_terakhir_ms,
		"inverter_diproses": stat_inverter_diproses,
		"solar_diproses": stat_solar_diproses,
		"perabot_diproses": stat_perabot_diproses,
		"nod_diproses": stat_nod_diproses,
		"sebab_terakhir": stat_sebab_terakhir,
		"amaran": stat_amaran,
		"inverter_berdaftar": _inverters.size(),
		"solar_berdaftar": _solar.size(),
		"perabot_berdaftar": _perabot.size(),
		"kotor_semua": _kotor,
		"inverter_kotor": 0,
	}
