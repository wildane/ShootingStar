extends RefCounted
## Reka bentuk vektor robot pekerja (gaya rata / flat vector): pose TERBANG
## mendatar seperti "superman". Kepala dan gerudi menghala ke +x (arah
## gerakan), badan mendatar, kaki terjuntai ke belakang (-x).
##
## Semua bentuk dijana dalam ruang reka bentuk sekitar x -27..+23, y -7..+6
## (unit reka bentuk), kemudian diskalakan. Fail ini menghasilkan dua
## perkara daripada satu lukisan:
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
##
## Parameter animasi (semua pilihan; nilai lalai = pose statik untuk ikon):
##   terbang — 0..1, panjang api penyembur di belakang kaki (0 = api padam)
##   gerudi  — jarak gerudi ditolak ke hadapan semasa melombong
##   degup   — 0..1, denyutan teras tenaga semasa mengecas
##   pusing  — putaran seluruh reka bentuk (radian), digunakan untuk ikon
##             supaya pose mendatar nampak serong dan memenuhi slot ikon.
static func bentuk(
	skala: float,
	aksen: Color = AKSEN,
	kilat: float = 0.0,
	terbang: float = 0.0,
	gerudi: float = 0.0,
	degup: float = 0.0,
	pusing: float = 0.0
) -> Array:
	var gelap := _warna(Color(0.06, 0.08, 0.11), kilat)
	var badan := _warna(Color(0.19, 0.23, 0.29), kilat)
	var besi := _warna(Color(0.33, 0.39, 0.47), kilat)
	var cahaya := _warna(aksen, kilat)
	var putih := _warna(Color(1.0, 1.0, 1.0, 0.9), kilat)
	var api := Color(0.45, 0.85, 1.0, 0.55)
	var api_teras := _warna(Color(0.85, 0.97, 1.0, 0.9), kilat)
	var senarai: Array = []

	# --- API PENYEMBUR: menembak ke belakang dari bawah kaki ---
	if terbang > 0.0:
		var panjang: float = 6.2 * terbang
		for sisi in [-1.0, 1.0]:
			var y: float = 2.1 * sisi
			senarai.append(_poli(PackedVector2Array([
				Vector2(-15.7, y - 1.5), Vector2(-15.7, y + 1.5),
				Vector2(-15.7 - panjang, y),
			]), skala, api))
			senarai.append(_poli(PackedVector2Array([
				Vector2(-15.8, y - 0.8), Vector2(-15.8, y + 0.8),
				Vector2(-15.8 - panjang * 0.6, y),
			]), skala, api_teras))

	# --- Lengan belakang: terjuntai ke belakang dan ke atas badan ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(4.8, -2.8), Vector2(3.4, -4.8),
		Vector2(-3.2, -7.4), Vector2(-5.0, -5.8),
	]), skala, gelap))
	senarai.append(_poli(PackedVector2Array([
		Vector2(4.4, -3.0), Vector2(3.4, -4.5),
		Vector2(-2.6, -6.6), Vector2(-3.8, -5.2),
	]), skala, besi))
	senarai.append(_bulat(Vector2(-4.2, -6.6), 1.8, skala, gelap))

	# --- Kaki terjuntai ke belakang, sedikit terpisah ---
	for sisi in [-1.0, 1.0]:
		senarai.append(_poli(PackedVector2Array([
			Vector2(-6.0, 4.2 * sisi), Vector2(-5.6, 0.8 * sisi),
			Vector2(-12.6, 0.8 * sisi), Vector2(-13.0, 3.8 * sisi),
		]), skala, gelap))
		senarai.append(_poli(PackedVector2Array([
			Vector2(-8.5, 3.4 * sisi), Vector2(-8.5, 1.0 * sisi),
			Vector2(-12.4, 1.0 * sisi), Vector2(-12.4, 3.4 * sisi),
		]), skala, besi))
		senarai.append(_poli(PackedVector2Array([
			Vector2(-15.6, 3.8 * sisi), Vector2(-12.6, 3.8 * sisi),
			Vector2(-12.6, 0.6 * sisi), Vector2(-15.6, 0.6 * sisi),
		]), skala, gelap))

	# --- Pinggul ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(-8.5, -3.4), Vector2(-5.0, -4.0),
		Vector2(-5.0, 4.0), Vector2(-8.5, 3.4),
	]), skala, gelap))

	# --- Torso mendatar: dada di hadapan (+x), pinggul di belakang ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(6.2, -4.4), Vector2(6.8, 0.0), Vector2(6.2, 4.4),
		Vector2(-4.0, 5.2), Vector2(-7.5, 3.0),
		Vector2(-7.5, -3.0), Vector2(-4.0, -5.2),
	]), skala, gelap))
	senarai.append(_poli(PackedVector2Array([
		Vector2(5.1, -3.5), Vector2(5.7, 0.0), Vector2(5.1, 3.5),
		Vector2(-3.4, 4.1), Vector2(-6.3, 2.3),
		Vector2(-6.3, -2.3), Vector2(-3.4, -4.1),
	]), skala, badan))
	# Plat dada besi di bahagian hadapan torso.
	senarai.append(_poli(PackedVector2Array([
		Vector2(1.8, -3.2), Vector2(5.8, -2.6),
		Vector2(5.8, 2.6), Vector2(1.8, 3.2),
	]), skala, besi))

	# Teras tenaga di dada: warnanya bertukar ikut keadaan robot, dan
	# berdenyut (dengan halo) semasa robot mengecas.
	if degup > 0.0:
		senarai.append(_bulat(
			Vector2(0.0, 0.3), 3.2 + degup * 2.4, skala,
			Color(cahaya.r, cahaya.g, cahaya.b, 0.22)
		))
	senarai.append(_bulat(Vector2(0.0, 0.3), 2.7, skala, gelap))
	senarai.append(_bulat(Vector2(0.0, 0.3), 2.0 + degup * 0.9, skala, cahaya))
	senarai.append(_bulat(Vector2(-0.5, -0.2), 0.8, skala, putih))

	# --- Bahu: sendi bulat; lengan hadapan di bawah, lengan belakang di atas ---
	senarai.append(_bulat(Vector2(5.0, 3.0), 2.4, skala, gelap))
	senarai.append(_bulat(Vector2(5.0, 3.0), 1.6, skala, besi))
	senarai.append(_bulat(Vector2(4.8, -2.8), 2.2, skala, gelap))
	senarai.append(_bulat(Vector2(4.8, -2.8), 1.5, skala, besi))

	# --- Leher dan kepala menghala ke hadapan (+x) ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(6.2, -3.4), Vector2(10.2, -3.4),
		Vector2(10.2, 0.6), Vector2(6.2, 0.6),
	]), skala, gelap))
	senarai.append({"jenis": "poligon", "titik": _bulatan(5.4, 8, skala, Vector2(13.2, -2.2)), "warna": gelap})
	senarai.append({"jenis": "poligon", "titik": _bulatan(4.1, 8, skala, Vector2(13.2, -2.2)), "warna": besi})
	# Visor di muka depan kepala.
	senarai.append(_poli(PackedVector2Array([
		Vector2(14.8, -4.8), Vector2(17.2, -3.6),
		Vector2(17.2, -0.8), Vector2(14.8, 0.4),
	]), skala, cahaya))
	senarai.append(_poli(PackedVector2Array([
		Vector2(15.3, -4.0), Vector2(16.4, -3.2),
		Vector2(16.4, -1.2), Vector2(15.3, -0.6),
	]), skala, putih))

	# Antena kecil di belakang atas kepala (warna besi supaya jelas).
	senarai.append(_poli(PackedVector2Array([
		Vector2(11.4, -6.4), Vector2(10.4, -7.2),
		Vector2(8.8, -9.4), Vector2(9.9, -9.0),
	]), skala, besi))
	senarai.append(_bulat(Vector2(9.1, -9.2), 1.2, skala, cahaya))

	# --- Lengan hadapan lurus ke depan di bawah kepala, memegang gerudi ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(5.2, 3.0), Vector2(6.8, 6.2),
		Vector2(14.2, 6.4), Vector2(14.2, 4.2),
	]), skala, gelap))
	senarai.append(_bulat(Vector2(15.0, 5.4), 2.1, skala, besi))

	# Gerudi menghala ke depan (+x); ditolak ke hadapan semasa melombong.
	var tolak := Vector2(gerudi, 0.0)
	senarai.append(_poli(_alih(PackedVector2Array([
		Vector2(14.6, 3.4), Vector2(15.4, 7.8), Vector2(23.8, 5.6),
	]), tolak), skala, gelap))
	senarai.append(_poli(_alih(PackedVector2Array([
		Vector2(15.2, 4.4), Vector2(15.8, 7.0), Vector2(20.8, 5.7),
	]), tolak), skala, _warna(AKSEN_LOMBONG, kilat)))

	if pusing != 0.0:
		senarai = _pusingkan(senarai, pusing)
	return senarai


## Raster bentuk di atas menjadi tekstur ikon (latar lutsinar, tepi licin
## melalui 2x2 sampel setiap piksel). Pose mendatar dipusing sedikit supaya
## nampak serong dan memenuhi slot ikon.
static func buat_ikon(saiz: int = 48, aksen: Color = AKSEN) -> ImageTexture:
	var imej := Image.create_empty(saiz, saiz, false, Image.FORMAT_RGBA8)
	imej.fill(Color(0.0, 0.0, 0.0, 0.0))
	var senarai := bentuk(float(saiz) / 58.0, aksen, 0.0, 0.0, 0.0, 0.0, -PI * 0.34)
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


# Pusingkan semua lapisan sekitar titik asal (untuk ikon serong).
static func _pusingkan(lapisan_senarai: Array, sudut: float) -> Array:
	var hasil: Array = []
	for lapisan in lapisan_senarai:
		if str(lapisan.get("jenis", "")) == "bulatan":
			hasil.append({
				"jenis": "bulatan",
				"pusat": (lapisan["pusat"] as Vector2).rotated(sudut),
				"jejari": lapisan["jejari"],
				"warna": lapisan["warna"],
			})
		else:
			var titik: PackedVector2Array = lapisan["titik"]
			var baru := PackedVector2Array()
			for titik_satu in titik:
				baru.append(titik_satu.rotated(sudut))
			hasil.append({"jenis": "poligon", "titik": baru, "warna": lapisan["warna"]})
	return hasil


static func _poli(titik: PackedVector2Array, skala: float, warna: Color) -> Dictionary:
	return {"jenis": "poligon", "titik": _poligon(titik, skala), "warna": warna}


static func _bulat(pusat: Vector2, jejari: float, skala: float, warna: Color) -> Dictionary:
	return {"jenis": "bulatan", "pusat": pusat * skala, "jejari": jejari * skala, "warna": warna}


static func _alih(titik: PackedVector2Array, jarak: Vector2) -> PackedVector2Array:
	var hasil := PackedVector2Array()
	for titik_satu in titik:
		hasil.append(titik_satu + jarak)
	return hasil


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
