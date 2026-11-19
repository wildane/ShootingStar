extends RefCounted

## Sistem navigasi grid untuk robot pekerja.
##
## Cara kerja:
## 1. Imbas seluruh kawasan (kotak yang diberi) dengan bentuk bulatan kecil
##    pada layer dinding (2), lalu tandakan sel yang kosong sebagai boleh lalu.
## 2. Sambung sel-sel kosong dengan AStar2D.
## 3. Setiap pintu didaftarkan sebagai pautan khas antara dua sisinya, jadi
##    laluan yang dikira akan "lalu pintu" bila itu satu-satunya jalan.
## 4. Hasilnya senarai titik {"pos": Vector2, "pintu": Node2D}. Titik yang ada
##    "pintu" bermaksud robot kena panggil lalu_automatik() di situ.

const LAPIS_DINDING: int = 2
const LEBAR_ROBOT: float = 5.0

var saiz_sel: float = 8.0
var kotak: Rect2 = Rect2()
var sedia: bool = false

var _kol: int = 0
var _bar: int = 0
var _bebas: PackedByteArray = PackedByteArray()
var _astar: AStar2D = AStar2D.new()
var _laluan_pintu: Dictionary = {}
var _ruang: PhysicsDirectSpaceState2D = null


## Bina grid kebolehlaluan untuk kawasan ini.
func bina(ruang: PhysicsDirectSpaceState2D, kawasan: Rect2, pengecualian: Array = []) -> void:
	_ruang = ruang
	kotak = kawasan
	sedia = false
	_astar.clear()
	_laluan_pintu.clear()
	if ruang == null:
		return

	saiz_sel = maxf(4.0, saiz_sel)
	# Hadkan bilangan sel supaya grid kekal ringan pada telefon.
	while (kawasan.size.x / saiz_sel) * (kawasan.size.y / saiz_sel) > 2400.0:
		saiz_sel *= 1.3
	_kol = maxi(1, int(ceil(kawasan.size.x / saiz_sel)))
	_bar = maxi(1, int(ceil(kawasan.size.y / saiz_sel)))
	_bebas = PackedByteArray()
	_bebas.resize(_kol * _bar)
	_bebas.fill(0)

	var bulatan := CircleShape2D.new()
	# Radius badan robot + sedikit ruang supaya sel yang dipilih benar-benar
	# boleh dilalui dan laluan tidak menggesel dinding.
	bulatan.radius = LEBAR_ROBOT + 1.5

	var pertanyaan := PhysicsShapeQueryParameters2D.new()
	pertanyaan.shape = bulatan
	pertanyaan.collision_mask = LAPIS_DINDING
	pertanyaan.collide_with_bodies = true
	pertanyaan.collide_with_areas = false
	pertanyaan.exclude = pengecualian

	for bar in _bar:
		for kol in _kol:
			var indeks: int = bar * _kol + kol
			pertanyaan.transform = Transform2D(0.0, pusat_sel(kol, bar))
			if ruang.intersect_shape(pertanyaan, 1).is_empty():
				_bebas[indeks] = 1
				_astar.add_point(indeks, pusat_sel(kol, bar))

	# Sambung jiran kanan dan bawah sahaja (pautan dua hala).
	for bar in _bar:
		for kol in _kol:
			var indeks: int = bar * _kol + kol
			if _bebas[indeks] == 0:
				continue
			if kol + 1 < _kol and _bebas[indeks + 1] == 1:
				_astar.connect_points(indeks, indeks + 1, true)
			if bar + 1 < _bar and _bebas[indeks + _kol] == 1:
				_astar.connect_points(indeks, indeks + _kol, true)

	sedia = true


func pusat_sel(kol: int, bar: int) -> Vector2:
	return kotak.position + Vector2((kol + 0.5) * saiz_sel, (bar + 0.5) * saiz_sel)


## Daftar satu pintu sebagai pautan dua hala antara dua sisinya.
func tambah_pintu(pintu: Node2D) -> void:
	if not sedia or not is_instance_valid(pintu):
		return
	if not pintu.has_method("titik_pintasan"):
		return
	var titik: Array = pintu.call("titik_pintasan")
	if titik.size() < 2:
		return
	var a: int = _indeks_bebas_terdekat(titik[0], 3)
	var b: int = _indeks_bebas_terdekat(titik[1], 3)
	if a < 0 or b < 0 or a == b:
		return
	if _astar.has_point(a) and _astar.has_point(b):
		if not _astar.are_points_connected(a, b):
			_astar.connect_points(a, b, true)
		_laluan_pintu[a] = {"ke": b, "pintu": pintu}
		_laluan_pintu[b] = {"ke": a, "pintu": pintu}


## Kira laluan dari -> ke. Pintu dimasukkan sebagai jalan keluar/masuk.
func cari_laluan(dari: Vector2, ke: Vector2, senarai_pintu: Array = []) -> Array:
	var hasil: Array = []
	if not sedia:
		return hasil

	for nod in senarai_pintu:
		if nod is Node2D:
			tambah_pintu(nod)

	var mula: int = _indeks_bebas_terdekat(dari, 6)
	var tamat: int = _indeks_bebas_terdekat(ke, 6)
	if mula < 0 or tamat < 0:
		return hasil

	var id_laluan: PackedInt64Array = _astar.get_id_path(mula, tamat)
	if id_laluan.is_empty():
		return hasil

	var titik: Array = []
	for i in id_laluan.size():
		var id: int = id_laluan[i]
		var pintu: Node2D = null
		if i + 1 < id_laluan.size():
			var seterusnya: int = id_laluan[i + 1]
			if _laluan_pintu.has(id) and int(_laluan_pintu[id]["ke"]) == seterusnya:
				pintu = _laluan_pintu[id]["pintu"]
		titik.append({"pos": _astar.get_point_position(id), "pintu": pintu})

	return _lancarkan(titik)


# ----------------------------------------------------------
# DALAMAN
# ----------------------------------------------------------
func _indeks_bebas_terdekat(pos: Vector2, radius_sel: int) -> int:
	if _bebas.is_empty():
		return -1
	var kol_pusat := int(floor((pos.x - kotak.position.x) / saiz_sel))
	var bar_pusat := int(floor((pos.y - kotak.position.y) / saiz_sel))
	for r in range(0, radius_sel + 1):
		var terbaik: int = -1
		var jarak_terbaik := INF
		for bar in range(bar_pusat - r, bar_pusat + r + 1):
			for kol in range(kol_pusat - r, kol_pusat + r + 1):
				if kol < 0 or kol >= _kol or bar < 0 or bar >= _bar:
					continue
				var indeks: int = bar * _kol + kol
				if _bebas[indeks] == 0:
					continue
				var jarak: float = pusat_sel(kol, bar).distance_squared_to(pos)
				if jarak < jarak_terbaik:
					jarak_terbaik = jarak
					terbaik = indeks
		if terbaik >= 0:
			return terbaik
	return -1


# Buang titik pertengahan yang boleh dilangkau terus tanpa langgar dinding.
func _lancarkan(titik: Array) -> Array:
	if titik.size() <= 2:
		return titik
	var hasil: Array = []
	var i := 0
	while i < titik.size():
		hasil.append(titik[i])
		if titik[i]["pintu"] != null:
			i += 1
			continue
		var terbaik: int = i
		var j: int = i + 1
		while j < titik.size():
			if titik[j]["pintu"] != null:
				break
			if _bebas_lurus(titik[i]["pos"], titik[j]["pos"]):
				terbaik = j
			j += 1
		if terbaik > i:
			i = terbaik
		else:
			i += 1
	return hasil


# Laluan lurus bebas dinding? Diuji dengan tiga sinar selari supaya robot
# tidak "potong sudut" terlalu rapat dengan dinding.
func _bebas_lurus(a: Vector2, b: Vector2) -> bool:
	if _ruang == null:
		return true
	var arah := b - a
	if arah.length() < 0.5:
		return true
	var sisi := arah.normalized().orthogonal() * (LEBAR_ROBOT + 1.0)
	for ofset in [Vector2.ZERO, sisi, -sisi]:
		var pertanyaan := PhysicsRayQueryParameters2D.create(a + ofset, b + ofset, LAPIS_DINDING)
		pertanyaan.collide_with_areas = false
		if not _ruang.intersect_ray(pertanyaan).is_empty():
			return false
	return true
