extends RefCounted
## Reka bentuk vektor robot pekerja (gaya rata / flat vector), bentuk humanoid.
##
## Semua bentuk dijana dalam ruang reka design sekitar ±11 x ±19 unit, kemudian
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
	var putih := _warna(Color(1.0, 1.0, 1.0, 0.9), kilat)
	var senarai: Array = []

	# --- Lengan belakang (kiri skrin), di belakang badan ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(-6.8, -4.8), Vector2(-8.9, -2.8),
		Vector2(-11.0, 2.2), Vector2(-8.4, 3.4),
	]), skala, gelap))
	# Jalur besi pada lengan belakang supaya bentuknya jelas pada latar gelap.
	senarai.append(_poli(PackedVector2Array([
		Vector2(-8.1, -3.5), Vector2(-9.1, -2.7),
		Vector2(-10.3, 0.7), Vector2(-9.3, 1.0),
	]), skala, besi))
	senarai.append(_bulat(Vector2(-9.4, 2.7), 1.9, skala, gelap))

	# --- Kaki: peha gelap, plat kering besi, kasut ---
	for sisi in [-1.0, 1.0]:
		senarai.append(_poli(PackedVector2Array([
			Vector2(1.4 * sisi, 1.8), Vector2(6.4 * sisi, 1.8),
			Vector2(5.8 * sisi, 15.2), Vector2(1.8 * sisi, 15.2),
		]), skala, gelap))
		senarai.append(_poli(PackedVector2Array([
			Vector2(2.4 * sisi, 5.0), Vector2(5.6 * sisi, 5.0),
			Vector2(5.2 * sisi, 14.4), Vector2(2.7 * sisi, 14.4),
		]), skala, besi))
		senarai.append(_poli(PackedVector2Array([
			Vector2(1.6 * sisi, 15.4), Vector2(7.2 * sisi, 15.4),
			Vector2(7.2 * sisi, 18.4), Vector2(1.6 * sisi, 18.4),
		]), skala, gelap))

	# --- Pinggul ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(-4.9, 0.4), Vector2(4.9, 0.4),
		Vector2(4.2, 3.2), Vector2(-4.2, 3.2),
	]), skala, gelap))

	# --- Torso: garis luar gelap + plat badan ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(-7.4, -4.6), Vector2(7.4, -4.6), Vector2(6.2, 1.5),
		Vector2(4.6, 5.2), Vector2(-4.6, 5.2), Vector2(-6.2, 1.5),
	]), skala, gelap))
	senarai.append(_poli(PackedVector2Array([
		Vector2(-6.3, -3.6), Vector2(6.3, -3.6), Vector2(5.2, 1.4),
		Vector2(3.9, 4.2), Vector2(-3.9, 4.2), Vector2(-5.2, 1.4),
	]), skala, badan))
	# Dada: plat besi di bahagian atas.
	senarai.append(_poli(PackedVector2Array([
		Vector2(-4.6, -3.2), Vector2(4.6, -3.2),
		Vector2(3.6, -1.0), Vector2(-3.6, -1.0),
	]), skala, besi))

	# Teras tenaga di dada: warnanya bertukar ikut keadaan robot.
	senarai.append(_bulat(Vector2(0.0, 1.4), 2.7, skala, gelap))
	senarai.append(_bulat(Vector2(0.0, 1.4), 2.0, skala, cahaya))
	senarai.append(_bulat(Vector2(-0.5, 0.8), 0.8, skala, putih))

	# --- Bahu: sendi bulat di kiri dan kanan torso ---
	for sisi in [-1.0, 1.0]:
		senarai.append(_bulat(Vector2(7.1 * sisi, -3.9), 2.6, skala, gelap))
		senarai.append(_bulat(Vector2(7.1 * sisi, -3.9), 1.7, skala, besi))

	# --- Leher ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(-1.7, -6.6), Vector2(1.7, -6.6),
		Vector2(1.7, -4.0), Vector2(-1.7, -4.0),
	]), skala, gelap))

	# --- Kepala: garis luar gelap, muka besi, visor bercahaya ---
	senarai.append({"jenis": "poligon", "titik": _bulatan(4.9, 8, skala, Vector2(0.0, -10.6)), "warna": gelap})
	senarai.append({"jenis": "poligon", "titik": _bulatan(3.7, 8, skala, Vector2(0.0, -10.6)), "warna": besi})
	senarai.append(_poli(PackedVector2Array([
		Vector2(-2.7, -12.1), Vector2(2.7, -12.1),
		Vector2(2.7, -9.7), Vector2(-2.7, -9.7),
	]), skala, cahaya))
	senarai.append(_poli(PackedVector2Array([
		Vector2(-2.1, -11.6), Vector2(0.6, -11.6),
		Vector2(0.6, -10.4), Vector2(-2.1, -10.4),
	]), skala, putih))

	# --- Antena pendek di atas kepala ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(-0.55, -15.2), Vector2(0.55, -15.2),
		Vector2(0.55, -17.7), Vector2(-0.55, -17.7),
	]), skala, gelap))
	senarai.append(_bulat(Vector2(0.0, -18.2), 1.3, skala, cahaya))

	# --- Lengan depan (kanan skrin) memegang gerudi perlombongan ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(7.0, -4.6), Vector2(8.8, -3.0),
		Vector2(10.4, 2.4), Vector2(8.4, 3.2),
	]), skala, gelap))
	senarai.append(_bulat(Vector2(9.4, 3.0), 1.9, skala, besi))

	# Gerudi: hujung tirus ke bawah, mata gerudi berwarna lombong.
	senarai.append(_poli(PackedVector2Array([
		Vector2(7.8, 4.0), Vector2(11.6, 4.0), Vector2(9.7, 14.0),
	]), skala, gelap))
	senarai.append(_poli(PackedVector2Array([
		Vector2(8.6, 4.4), Vector2(10.8, 4.4), Vector2(9.7, 11.8),
	]), skala, _warna(AKSEN_LOMBONG, kilat)))
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


static func _poli(titik: PackedVector2Array, skala: float, warna: Color) -> Dictionary:
	return {"jenis": "poligon", "titik": _poligon(titik, skala), "warna": warna}


static func _bulat(pusat: Vector2, jejari: float, skala: float, warna: Color) -> Dictionary:
	return {"jenis": "bulatan", "pusat": pusat * skala, "jejari": jejari * skala, "warna": warna}


static func _poligon(titik: PackedVector2Array, skala: float) -> PackedVector2Array:
	var hasil := PackedVector2Array()
	for titik_satu in titik:
		hasil.append(titik_satu * skala)
	return hasil


static func _bulatan(jejari: float, bilangan: int, skala: float, pusat: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var hasil := PackedVector2Array()
	for i in range(bilangan):
		var titik := Vector2.RIGHT.rotated(TAU * float(i) / float(bilangan)) * jejari + pusat
		hasil.append(titik * skala)
	return hasil
