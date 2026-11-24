class_name PowerGrid
extends RefCounted

## Pengurus grid kuasa berpusat: registry nod, indeks spatial sel, dirty scope,
## coalesce kemas kini, dan metrik debug. Semua fungsi static supaya mudah
## dipanggil dari nod binaan tanpa autoload.
##
## Kebenaran diutamakan: perubahan solar/inverter/load memaksa kira penuh;
## perubahan perabot boleh dikira incremental mengikut inverter terjejas.

const SAIZ_SEL: float = 64.0
const SELA_KIRA_MINIMUM: float = 0.10
const BAJET_MS_DEFAULT: float = 4.0

# Registry nod aktif.
static var _inverters: Array = []          # Array[Node2D]
static var _solar: Array = []              # Array[Node2D]
static var _perabot: Array = []            # Array[Node2D] (power consumers)

# Indeks spatial sel -> Array nod. Dipakai untuk pertanyaan julat pantas.
static var _sel_inverter: Dictionary = {}  # Vector2i -> Array[Node2D]
static var _sel_solar: Dictionary = {}
static var _sel_perabot: Dictionary = {}

# Peta nod -> sel semasa untuk nyahdaftar pantas.
static var _sel_nod: Dictionary = {}       # instance_id -> { "sel": Vector2i, "jenis": String }

# Keadaan dirty/coalesce.
static var _kotor_semua: bool = true
static var _inverter_kotor: Dictionary = {} # instance_id -> Node2D
static var _sedang_kira: bool = false
static var _masa_kira_terakhir: float = -1000.0
static var _perlu_kira_segera: bool = false

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

# --- Utiliti sel ---

static func _sel_dari_pos(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / SAIZ_SEL), floori(pos.y / SAIZ_SEL))

static func _padam_dari_array(arr: Array, nod: Node) -> void:
	var idx := arr.find(nod)
	if idx >= 0:
		arr.remove_at(idx)

static func _daftar_sel(peta: Dictionary, nod: Node2D, jenis: String) -> void:
	var id: int = int(nod.get_instance_id())
	_nyahdaftar_sel_id(id)
	var sel := _sel_dari_pos(nod.global_position)
	if not peta.has(sel):
		peta[sel] = []
	var bucket: Array = peta[sel]
	if bucket.find(nod) < 0:
		bucket.append(nod)
	_sel_nod[id] = {"sel": sel, "jenis": jenis, "nod": nod}

static func _nyahdaftar_sel_id(id: int) -> void:
	if not _sel_nod.has(id):
		return
	var info: Dictionary = _sel_nod[id]
	_sel_nod.erase(id)
	var sel: Vector2i = info.get("sel", Vector2i.ZERO)
	var jenis: String = info.get("jenis", "")
	var nod: Node = info.get("nod", null)
	var peta: Dictionary = {}
	match jenis:
		"inverter": peta = _sel_inverter
		"solar": peta = _sel_solar
		"perabot": peta = _sel_perabot
		_: return
	if not peta.has(sel):
		return
	var bucket: Array = peta[sel]
	if nod != null:
		_padam_dari_array(bucket, nod)
	if bucket.is_empty():
		peta.erase(sel)

static func _nod_sah(nod: Node) -> bool:
	return nod != null and is_instance_valid(nod) and not nod.is_queued_for_deletion() and nod.is_inside_tree()

static func reset() -> void:
	_inverters.clear()
	_solar.clear()
	_perabot.clear()
	_sel_inverter.clear()
	_sel_solar.clear()
	_sel_perabot.clear()
	_sel_nod.clear()
	_kotor_semua = true
	_inverter_kotor.clear()
	_sedang_kira = false
	_masa_kira_terakhir = -1000.0
	_perlu_kira_segera = false
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

static func _pertanyaan_sel(peta: Dictionary, pos: Vector2, radius: float) -> Array:
	var hasil: Array = []
	var dilihat: Dictionary = {}
	var min_sel := _sel_dari_pos(pos - Vector2(radius, radius))
	var max_sel := _sel_dari_pos(pos + Vector2(radius, radius))
	for x in range(min_sel.x, max_sel.x + 1):
		for y in range(min_sel.y, max_sel.y + 1):
			var sel := Vector2i(x, y)
			if not peta.has(sel):
				continue
			for nod in peta[sel]:
				if nod == null or not is_instance_valid(nod):
					continue
				var id: int = int(nod.get_instance_id())
				if dilihat.has(id):
					continue
				dilihat[id] = true
				hasil.append(nod)
	return hasil

# --- Pendaftaran awam ---

static func daftar_inverter(nod: Node2D) -> void:
	if nod == null or _inverters.find(nod) >= 0:
		return
	_inverters.append(nod)
	_daftar_sel(_sel_inverter, nod, "inverter")
	tanda_kotor_semua("daftar_inverter")

static func nyahdaftar_inverter(nod: Node2D) -> void:
	if nod == null:
		return
	_padam_dari_array(_inverters, nod)
	_nyahdaftar_sel_id(nod.get_instance_id())
	_inverter_kotor.erase(nod.get_instance_id())
	# Buang inverter boleh memutus pemilikan solar/perabot merentasi grid.
	tanda_kotor_semua("nyahdaftar_inverter")

static func daftar_solar(nod: Node2D) -> void:
	if nod == null or _solar.find(nod) >= 0:
		return
	_solar.append(nod)
	_daftar_sel(_sel_solar, nod, "solar")
	# Solar boleh menyambung rantai; guna kira penuh untuk kebenaran.
	tanda_kotor_semua("daftar_solar")

static func nyahdaftar_solar(nod: Node2D) -> void:
	if nod == null:
		return
	_padam_dari_array(_solar, nod)
	_nyahdaftar_sel_id(nod.get_instance_id())
	tanda_kotor_semua("nyahdaftar_solar")

static func daftar_perabot(nod: Node2D) -> void:
	if nod == null or _perabot.find(nod) >= 0:
		return
	_perabot.append(nod)
	_daftar_sel(_sel_perabot, nod, "perabot")
	tanda_kotor_dari_pos(nod.global_position, _radius_perabot_maks(), "daftar_perabot")

static func nyahdaftar_perabot(nod: Node2D) -> void:
	if nod == null:
		return
	var pos := nod.global_position
	_padam_dari_array(_perabot, nod)
	_nyahdaftar_sel_id(nod.get_instance_id())
	tanda_kotor_dari_pos(pos, _radius_perabot_maks(), "nyahdaftar_perabot")

static func kemas_kini_pos_nod(nod: Node2D, jenis: String) -> void:
	if not _nod_sah(nod):
		return
	var peta: Dictionary = {}
	match jenis:
		"inverter": peta = _sel_inverter
		"solar": peta = _sel_solar
		"perabot": peta = _sel_perabot
		_: return
	_daftar_sel(peta, nod, jenis)

# --- Dirty ---

static func tanda_kotor_semua(sebab: String = "manual") -> void:
	_kotor_semua = true
	_inverter_kotor.clear()
	_perlu_kira_segera = true
	stat_dirty_semua += 1
	stat_sebab_terakhir = sebab

static func tanda_kotor_inverter(inv: Node2D, sebab: String = "inverter") -> void:
	if inv == null or not is_instance_valid(inv):
		return
	_inverter_kotor[inv.get_instance_id()] = inv
	_perlu_kira_segera = true
	stat_dirty_inverter += 1
	stat_sebab_terakhir = sebab

static func tanda_kotor_dari_pos(pos: Vector2, radius: float, sebab: String = "pos") -> void:
	# Jika tiada inverter berdaftar, kekalkan kotor semua supaya fallback selamat.
	if _inverters.is_empty():
		tanda_kotor_semua(sebab)
		return
	var ada_terjejas := false
	var radius_maks := _radius_liputan_maks() + radius
	var calon := _pertanyaan_sel(_sel_inverter, pos, radius_maks)
	if calon.is_empty():
		calon = _inverters_sah()
	for inv in calon:
		if not _nod_sah(inv):
			continue
		var liputan := _radius_liputan_inverter(inv)
		var had := radius + liputan
		if inv.global_position.distance_squared_to(pos) <= had * had:
			tanda_kotor_inverter(inv, sebab)
			ada_terjejas = true
	if not ada_terjejas:
		# Perubahan di luar liputan semua inverter: tiada kesan kuasa.
		stat_sebab_terakhir = sebab + ":tiada_kesan"

static func _radius_liputan_maks() -> float:
	var maks_r := 256.0
	for inv in _inverters_sah():
		maks_r = maxf(maks_r, _radius_liputan_inverter(inv))
	return maks_r

static func _radius_liputan_inverter(inv: Node2D) -> float:
	var r_solar := 0.0
	var r_perabot := 0.0
	if "radius_inverter_to_solar" in inv:
		r_solar = float(inv.radius_inverter_to_solar)
	if "radius_inverter_to_furniture" in inv:
		r_perabot = float(inv.radius_inverter_to_furniture)
	return maxf(r_solar, r_perabot)

static func _radius_perabot_maks() -> float:
	var maks_r := 256.0
	for inv in _inverters_sah():
		if "radius_inverter_to_furniture" in inv:
			maks_r = maxf(maks_r, float(inv.radius_inverter_to_furniture))
	return maks_r

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
	# Bersihkan indeks sel nod yang sudah tidak sah.
	var id_buang: Array = []
	for id in _sel_nod.keys():
		var info: Dictionary = _sel_nod[id]
		var nod: Node = info.get("nod", null)
		if not _nod_sah(nod):
			id_buang.append(id)
	for id in id_buang:
		_nyahdaftar_sel_id(id)

# --- Proses utama ---

static func perlu_kira() -> bool:
	return _kotor_semua or not _inverter_kotor.is_empty()

static func proses(tree: SceneTree, paksa: bool = false) -> void:
	if _sedang_kira or tree == null:
		return
	if not paksa and not perlu_kira():
		return
	var sekarang := Time.get_ticks_msec() / 1000.0
	if not paksa and not _perlu_kira_segera and sekarang - _masa_kira_terakhir < SELA_KIRA_MINIMUM:
		return

	_sedang_kira = true
	_perlu_kira_segera = false
	_masa_kira_terakhir = sekarang
	var mula_ms := Time.get_ticks_msec()

	_bersihkan_registry()
	# Fallback: jika registry kosong tetapi group ada (nod belum sempat daftar),
	# bina dari group supaya tingkah laku tidak rosak.
	_seed_dari_group_jika_perlu(tree)

	var inverters := _inverters_sah()
	var semua_solar := _solar_sah()
	var semua_perabot := _perabot_sah()

	var penuh := _kotor_semua or inverters.is_empty()
	var sasaran: Array = inverters
	if not penuh:
		sasaran = []
		for id in _inverter_kotor.keys():
			var nod: Node = _inverter_kotor[id]
			if _nod_sah(nod):
				sasaran.append(nod)
		if sasaran.is_empty():
			_kotor_semua = false
			_inverter_kotor.clear()
			_sedang_kira = false
			return

	_kotor_semua = false
	_inverter_kotor.clear()

	# Bersihkan rujukan perabot tidak sah/freed.
	_bersihkan_rujukan_perabot(semua_perabot)

	if inverters.is_empty():
		_reset_tiada_inverter(semua_solar, semua_perabot)
		_rekod_stat(mula_ms, penuh, 0, semua_solar.size(), semua_perabot.size())
		_sedang_kira = false
		return

	# Lepaskan solar milik inverter yang tidak wujud.
	for solar in semua_solar:
		var pemilik = solar.inverter_pembeli
		if pemilik == null:
			continue
		if not _nod_sah(pemilik):
			if is_instance_valid(pemilik):
				solar.release_owner_inverter(pemilik)
			else:
				solar.inverter_pembeli = null

	# Untuk kebenaran multi-inverter, bila kira penuh guna semua inverter;
	# bila incremental, kira inverter sasaran tetapi kekalkan pemilikan inverter
	# lain yang masih sah. Solar/perabot milik inverter sasaran dibebaskan dulu.
	if not penuh:
		_bebaskan_milik_inverter_sasaran(sasaran, semua_solar, semua_perabot)

	for inv in sasaran:
		_kira_inverter(inv, semua_solar, semua_perabot)

	_rekod_stat(mula_ms, penuh, sasaran.size(), semua_solar.size(), semua_perabot.size())
	_sedang_kira = false

static func _seed_dari_group_jika_perlu(tree: SceneTree) -> void:
	if _inverters.is_empty():
		for n in tree.get_nodes_in_group("PowerInverter"):
			if _nod_sah(n) and n is Node2D:
				_inverters.append(n)
				_daftar_sel(_sel_inverter, n, "inverter")
	if _solar.is_empty():
		for n in tree.get_nodes_in_group("SolarModule"):
			if _nod_sah(n) and n is Node2D:
				_solar.append(n)
				_daftar_sel(_sel_solar, n, "solar")
	if _perabot.is_empty():
		for n in tree.get_nodes_in_group("Furniture"):
			if _nod_sah(n) and n is Node2D and "power_required" in n:
				_perabot.append(n)
				_daftar_sel(_sel_perabot, n, "perabot")

static func _rekod_stat(mula_ms: int, penuh: bool, inv_count: int, solar_count: int, perabot_count: int) -> void:
	stat_kiraan += 1
	if penuh:
		stat_kiraan_penuh += 1
	else:
		stat_kiraan_incremental += 1
	stat_masa_terakhir_ms = float(Time.get_ticks_msec() - mula_ms)
	stat_inverter_diproses = inv_count
	stat_solar_diproses = solar_count
	stat_perabot_diproses = perabot_count
	stat_nod_diproses = inv_count + solar_count + perabot_count
	if stat_masa_terakhir_ms > BAJET_MS_DEFAULT:
		stat_amaran = "Kiraan kuasa melebihi bajet: %.2f ms" % stat_masa_terakhir_ms
	else:
		stat_amaran = ""

static func _bersihkan_rujukan_perabot(semua_perabot: Array) -> void:
	for perabot in semua_perabot:
		if not _nod_sah(perabot):
			continue
		var pembekal = perabot.inverter_pembekal if "inverter_pembekal" in perabot else null
		if pembekal != null and not _nod_sah(pembekal):
			if perabot.has_method("set_power_status"):
				perabot.set_power_status(false, null)

static func _reset_tiada_inverter(semua_solar: Array, semua_perabot: Array) -> void:
	for solar in semua_solar:
		if not _nod_sah(solar):
			continue
		var pemilik = solar.inverter_pembeli
		if pemilik != null:
			if is_instance_valid(pemilik):
				solar.release_owner_inverter(pemilik)
			else:
				solar.inverter_pembeli = null
	for perabot in semua_perabot:
		if not _nod_sah(perabot) or not perabot.has_method("set_power_status"):
			continue
		var ada_kuasa: bool = "has_power" in perabot and perabot.has_power
		var ada_pembekal: bool = "inverter_pembekal" in perabot and perabot.inverter_pembekal != null
		if ada_kuasa or ada_pembekal:
			perabot.set_power_status(false, null)

static func _bebaskan_milik_inverter_sasaran(sasaran: Array, semua_solar: Array, semua_perabot: Array) -> void:
	var sasaran_id: Dictionary = {}
	for inv in sasaran:
		if is_instance_valid(inv):
			sasaran_id[inv.get_instance_id()] = true
	for solar in semua_solar:
		if not _nod_sah(solar):
			continue
		var pemilik = solar.inverter_pembeli
		if pemilik != null and is_instance_valid(pemilik) and sasaran_id.has(pemilik.get_instance_id()):
			solar.release_owner_inverter(pemilik)
	for perabot in semua_perabot:
		if not _nod_sah(perabot) or not perabot.has_method("set_power_status"):
			continue
		var pembekal = perabot.inverter_pembekal if "inverter_pembekal" in perabot else null
		if pembekal != null and is_instance_valid(pembekal) and sasaran_id.has(pembekal.get_instance_id()):
			perabot.set_power_status(false, null)

# --- Pengiraan per inverter ---

static func _kira_inverter(inv: Node2D, semua_solar: Array, semua_perabot: Array) -> void:
	if not _nod_sah(inv):
		return
	if "total_power_supply" in inv:
		inv._grid_kotor = false

	var pos_inverter: Vector2 = inv.global_position
	if semua_solar.is_empty():
		_set_kuasa_kosong(inv)
		_kemas_kini_status_perabot_tiada_kuasa(inv, semua_perabot)
		return

	# Pertanyaan spatial: calon solar dalam liputan inverter + jarak cantuman maks.
	var radius_solar_cari := float(inv.radius_inverter_to_solar)
	for s in semua_solar:
		if _nod_sah(s) and "jarak_cantuman" in s:
			radius_solar_cari = maxf(radius_solar_cari, float(s.jarak_cantuman))
	var calon_solar := _pertanyaan_sel(_sel_solar, pos_inverter, radius_solar_cari)
	if calon_solar.is_empty():
		calon_solar = semua_solar

	var solar_bersambung: Dictionary = {}
	var senarai_semak: Array = []
	var dalam_semak: Dictionary = {}

	for solar in calon_solar:
		if not _nod_sah(solar):
			continue
		var pemilik = solar.inverter_pembeli
		if pemilik != null and pemilik != inv and _nod_sah(pemilik):
			continue
		var pos_solar: Vector2 = solar.global_position
		if pos_solar == Vector2.ZERO and pos_inverter != Vector2.ZERO:
			continue
		var had_jarak: float = solar.jarak_cantuman if "jarak_cantuman" in solar else inv.radius_inverter_to_solar
		if pos_inverter.distance_squared_to(pos_solar) <= had_jarak * had_jarak:
			senarai_semak.append(solar)
			dalam_semak[solar] = true
			solar.set_owner_inverter(inv)

	var jumlah_supply: float = 0.0
	while senarai_semak.size() > 0:
		var semasa = senarai_semak.pop_back()
		dalam_semak.erase(semasa)
		if not _nod_sah(semasa) or solar_bersambung.has(semasa):
			continue
		solar_bersambung[semasa] = true
		jumlah_supply += semasa.power_production if "power_production" in semasa else 100.0
		var had_cantuman: float = semasa.jarak_cantuman if "jarak_cantuman" in semasa else 300.0
		var had_cantuman_sq: float = had_cantuman * had_cantuman
		var pos_semasa: Vector2 = semasa.global_position
		var calon_rantai := _pertanyaan_sel(_sel_solar, pos_semasa, had_cantuman)
		if calon_rantai.is_empty():
			calon_rantai = semua_solar
		for solar_lain in calon_rantai:
			if not _nod_sah(solar_lain) or solar_bersambung.has(solar_lain) or dalam_semak.has(solar_lain):
				continue
			var pemilik_lain = solar_lain.inverter_pembeli
			if pemilik_lain != null and pemilik_lain != inv and _nod_sah(pemilik_lain):
				continue
			var pos_lain: Vector2 = solar_lain.global_position
			if pos_lain == Vector2.ZERO and pos_inverter != Vector2.ZERO:
				continue
			if pos_semasa.distance_squared_to(pos_lain) <= had_cantuman_sq:
				senarai_semak.append(solar_lain)
				dalam_semak[solar_lain] = true
				solar_lain.set_owner_inverter(inv)

	for solar in semua_solar:
		if _nod_sah(solar) and solar.inverter_pembeli == inv and not solar_bersambung.has(solar):
			solar.release_owner_inverter(inv)

	var radius_perabot_sq: float = inv.radius_inverter_to_furniture * inv.radius_inverter_to_furniture
	var jumlah_requirement: float = 0.0
	var tenaga_tersedia_semasa: float = jumlah_supply
	var calon_perabot := _pertanyaan_sel(_sel_perabot, pos_inverter, inv.radius_inverter_to_furniture)
	if calon_perabot.is_empty() and not semua_perabot.is_empty():
		calon_perabot = semua_perabot
	# Kemas kini perabot dalam liputan calon spatial; perabot di luar liputan
	# yang masih milik inverter ini juga perlu dilepaskan.
	var diproses_perabot: Dictionary = {}
	for perabot in calon_perabot:
		if not _nod_sah(perabot):
			continue
		diproses_perabot[perabot.get_instance_id()] = true
		if pos_inverter.distance_squared_to(perabot.global_position) <= radius_perabot_sq:
			if not perabot.has_power or perabot.inverter_pembekal == inv:
				jumlah_requirement += perabot.power_required
				if perabot.has_method("set_power_status"):
					if tenaga_tersedia_semasa >= perabot.power_required and jumlah_supply > 0.0:
						perabot.set_power_status(true, inv)
						tenaga_tersedia_semasa -= perabot.power_required
					else:
						perabot.set_power_status(false, inv)
		else:
			if "inverter_pembekal" in perabot and perabot.inverter_pembekal == inv and perabot.has_method("set_power_status"):
				perabot.set_power_status(false, inv)
	for perabot in semua_perabot:
		if not _nod_sah(perabot) or diproses_perabot.has(perabot.get_instance_id()):
			continue
		if "inverter_pembekal" in perabot and perabot.inverter_pembekal == inv and perabot.has_method("set_power_status"):
			perabot.set_power_status(false, inv)

	var baki_dikira: float = jumlah_supply - jumlah_requirement
	if inv.total_power_supply != jumlah_supply or inv.total_power_requirement != jumlah_requirement or inv.baki_tenaga != baki_dikira:
		inv.total_power_supply = jumlah_supply
		inv.total_power_requirement = jumlah_requirement
		inv.baki_tenaga = baki_dikira
		inv._kemas_kini_paparan_skrin()

static func _set_kuasa_kosong(inv: Node2D) -> void:
	if inv.total_power_supply != 0.0 or inv.total_power_requirement != 0.0:
		inv.total_power_supply = 0.0
		inv.total_power_requirement = 0.0
		inv.baki_tenaga = 0.0
		inv._kemas_kini_paparan_skrin()

static func _kemas_kini_status_perabot_tiada_kuasa(inv: Node2D, semua_perabot: Array) -> void:
	for perabot in semua_perabot:
		if _nod_sah(perabot) and "inverter_pembekal" in perabot and perabot.inverter_pembekal == inv and perabot.has_method("set_power_status"):
			perabot.set_power_status(false, inv)

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
		"kotor_semua": _kotor_semua,
		"inverter_kotor": _inverter_kotor.size(),
	}
