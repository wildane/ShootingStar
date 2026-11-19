extends RefCounted
## Reka bentuk vektor robot pekerja (gaya rata / flat vector).
##
## Semua bentuk dijana dalam ruang reka bentuk sekitar ±19 px, kemudian
## diskalakan. Fail ini menghasilkan dua perkara daripada satu lukisan:
##   1. badan robot di skrin (draw_colored_polygon / draw_circle), dan
##   2. ikon resipi Fabricator (raster ke ImageTexture).
## Tiada fail imej baru diperlukan, jadi ikon kekal tajam pada semua saiz.

const AKSEN: Color = Color(0.45, 1.0, 0.55)
const AKSEN_LOMBONG: Color = Color(1.0, 0.82, 0.35)
const AKSEN_CAS: Color = Color(0.45, 0.85, 1.0)
const AKSEN_BAIKI: Color = Color(0.55, 1.0, 0.6)


## Senarai lapisan daripada belakang ke depan. Setiap lapisan sama ada
## {"jenis": "poligon", "titik": PackedVector2Array, "warna": Color}
## atau {"jenis": "bulatan", "pusat": Vector2, "jejari": float, "warna": Color}.
static func bentuk(skala: float, aksen: Color = AKSEN, kilat: float = 0.0) -> Array:
	var gelap := _warna(Color(0.06, 0.08, 0.11), kilat)
	var badan := _warna(Color(0.19, 0.23, 0.29), kilat)
	var besi := _warna(Color(0.33, 0.39, 0.47), kilat)
	var cahaya := _warna(aksen, kilat)
	var senarai: Array = []

	# 4 lengan pepenjuru (di belakang badan).
	for i in range(4):
		var arah: Vector2 = Vector2.RIGHT.rotated(PI * 0.25 + PI * 0.5 * float(i))
		var tepi: Vector2 = arah.orthogonal()
		senarai.append({
			"jenis": "poligon",
			"titik": _poligon(PackedVector2Array([
				arah * 3.0 + tepi * 2.4, arah * 16.6 + tepi * 2.4,
				arah * 16.6 - tepi * 2.4, arah * 3.0 - tepi * 2.4,
			]), skala),
			"warna": gelap,
		})

	# Badan: oktagon garis luar gelap + oktagon besi.
	senarai.append({"jenis": "poligon", "titik": _bulatan(11.9, 8, skala), "warna": gelap})
	senarai.append({"jenis": "poligon", "titik": _bulatan(10.4, 8, skala), "warna": badan})

	# 4 rotor di hujung lengan.
	for i in range(4):
		var pusat: Vector2 = Vector2.RIGHT.rotated(PI * 0.25 + PI * 0.5 * float(i)) * 16.6 * skala
		senarai.append({"jenis": "bulatan", "pusat": pusat, "jejari": 4.2 * skala, "warna": gelap})
		senarai.append({"jenis": "bulatan", "pusat": pusat, "jejari": 3.0 * skala, "warna": besi})

	# Teras tenaga: warnanya bertukar ikut keadaan robot.
	senarai.append({"jenis": "bulatan", "pusat": Vector2.ZERO, "jejari": 6.6 * skala, "warna": gelap})
	senarai.append({"jenis": "bulatan", "pusat": Vector2.ZERO, "jejari": 5.4 * skala, "warna": cahaya})
	senarai.append({
		"jenis": "bulatan",
		"pusat": Vector2(0.0, -0.8) * skala,
		"jejari": 2.6 * skala,
		"warna": _warna(Color(1.0, 1.0, 1.0, 0.9), kilat),
	})

	# Gerudi perlombongan di bawah.
	senarai.append({
		"jenis": "poligon",
		"titik": _poligon(PackedVector2Array([
			Vector2(-4.4, 7.4), Vector2(4.4, 7.4), Vector2(0.0, 15.6),
		]), skala),
		"warna": gelap,
	})
	senarai.append({
		"jenis": "poligon",
		"titik": _poligon(PackedVector2Array([
			Vector2(-2.9, 7.6), Vector2(2.9, 7.6), Vector2(0.0, 13.6),
		]), skala),
		"warna": _warna(AKSEN_LOMBONG, kilat),
	})
	return senarai


## Raster bentuk di atas menjadi tekstur ikon (latar lutsinar, tepi licin
## melalui 2x2 sampel setiap piksel).
static func buat_ikon(saiz: int = 48, aksen: Color = AKSEN) -> ImageTexture:
	var imej := Image.create_empty(saiz, saiz, false, Image.FORMAT_RGBA8)
	imej.fill(Color(0.0, 0.0, 0.0, 0.0))
	var senarai := bentuk(float(saiz) / 44.0, aksen)
	var tengah := float(saiz) * 0.5
	var sampel := 2
	var bilangan_sampel := float(sampel * sampel)

	for y in range(saiz):
		for x in range(saiz):
			var campur := Color(0.0, 0.0, 0.0, 0.0)
			var kira := 0.0
			for sy in range(sampel):
				for sx in range(sampel):
					var p := Vector2(
						float(x) + (float(sx) + 0.5) / float(sampel) - tengah,
						float(y) + (float(sy) + 0.5) / float(sampel) - tengah
					)
					for i in range(senarai.size() - 1, -1, -1):
						var lapisan: Dictionary = senarai[i]
						if _dalam(lapisan, p):
							campur += lapisan["warna"]
							kira += 1.0
							break
			if kira > 0.0:
				imej.set_pixel(x, y, Color(
					campur.r / kira, campur.g / kira, campur.b / kira, kira / bilangan_sampel
				))
	return ImageTexture.create_from_image(imej)


static func _dalam(lapisan: Dictionary, p: Vector2) -> bool:
	if str(lapisan.get("jenis", "")) == "bulatan":
		var jejari: float = float(lapisan["jejari"])
		return p.distance_squared_to(lapisan["pusat"]) <= jejari * jejari
	var titik: PackedVector2Array = lapisan["titik"]
	var n := titik.size()
	if n < 3:
		return false
	var dalam := false
	var j := n - 1
	for i in range(n):
		var a: Vector2 = titik[i]
		var b: Vector2 = titik[j]
		if (a.y > p.y) != (b.y > p.y):
			var potong: float = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
			if p.x < potong:
				dalam = not dalam
		j = i
	return dalam


static func _warna(asas: Color, kilat: float) -> Color:
	if kilat <= 0.0:
		return asas
	var tambah := 1.0 + kilat * 1.6
	return Color(
		minf(1.0, asas.r * tambah), minf(1.0, asas.g * tambah),
		minf(1.0, asas.b * tambah), asas.a
	)


static func _poligon(titik: PackedVector2Array, skala: float) -> PackedVector2Array:
	var hasil := PackedVector2Array()
	for titik_satu in titik:
		hasil.append(titik_satu * skala)
	return hasil


static func _bulatan(jejari: float, bilangan: int, skala: float) -> PackedVector2Array:
	var hasil := PackedVector2Array()
	for i in range(bilangan):
		hasil.append(Vector2.RIGHT.rotated(TAU * float(i) / float(bilangan)) * jejari * skala)
	return hasil
