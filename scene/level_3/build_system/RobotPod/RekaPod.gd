extends RefCounted
## Reka bentuk vektor pod robot pekerja (gaya rata, sama keluarga dengan
## RekaRobot.gd). Satu lukisan menghasilkan dua perkara:
##   1. pod di dunia (dilukis oleh pod_actual.gd melalui draw_colored_polygon /
##      draw_circle), dan
##   2. ikon butang bina + hologram preview (raster ke ImageTexture).
##
## Ruang reka bentuk: x -20..20, y -26..2 (0 = lantai, y negatif = atas).
## Kanopi kaca (lapisan_kaca) hanya dilukis apabila robot sedang mengecas.

const AKSEN: Color = Color(0.45, 0.85, 1.0)
const AKSEN_MATI: Color = Color(1.0, 0.35, 0.35)

const GELAP: Color = Color(0.06, 0.08, 0.11)
const BESI: Color = Color(0.22, 0.27, 0.34)
const BESI_CERAH: Color = Color(0.35, 0.42, 0.50)
const KUSYEN: Color = Color(0.13, 0.17, 0.23)
const KUSYEN_ATAS: Color = Color(0.26, 0.32, 0.40)


## Semua bentuk pod kecuali kaca kanopi dan robot. Dilukis sebelum robot
## supaya robot kelihatan berada di dalam pod.
static func lapisan_belakang(ada_kuasa: bool) -> Array:
	var senarai: Array = []
	var lampu: Color = AKSEN if ada_kuasa else AKSEN_MATI
	var lampu_redup: Color = Color(AKSEN.r, AKSEN.g, AKSEN.b, 0.35) if ada_kuasa else Color(0.4, 0.4, 0.45)

	# --- Alas dan kaki pod ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(-17.0, -1.0), Vector2(17.0, -1.0),
		Vector2(14.5, -7.0), Vector2(-14.5, -7.0),
	]), GELAP))
	senarai.append(_poli(PackedVector2Array([
		Vector2(-15.0, -2.2), Vector2(15.0, -2.2),
		Vector2(13.5, -6.2), Vector2(-13.5, -6.2),
	]), BESI))
	senarai.append(_poli(PackedVector2Array([
		Vector2(-12.6, -1.0), Vector2(-9.2, -1.0),
		Vector2(-10.2, 1.8), Vector2(-13.8, 1.8),
	]), GELAP))
	senarai.append(_poli(PackedVector2Array([
		Vector2(12.6, -1.0), Vector2(9.2, -1.0),
		Vector2(10.2, 1.8), Vector2(13.8, 1.8),
	]), GELAP))

	# --- Rangka tempurung pod ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(-16.0, -6.0), Vector2(-13.5, -21.0),
		Vector2(13.5, -21.0), Vector2(16.0, -6.0),
	]), GELAP))
	senarai.append(_poli(PackedVector2Array([
		Vector2(-14.3, -7.4), Vector2(-12.4, -19.6),
		Vector2(12.4, -19.6), Vector2(14.3, -7.4),
	]), BESI))

	# --- Tilam tempat robot baring ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(-11.6, -8.0), Vector2(-10.6, -18.0),
		Vector2(10.6, -18.0), Vector2(11.6, -8.0),
	]), KUSYEN))
	senarai.append(_poli(PackedVector2Array([
		Vector2(-10.4, -12.8), Vector2(10.4, -12.8),
		Vector2(10.1, -9.6), Vector2(-10.1, -9.6),
	]), KUSYEN_ATAS))

	# --- Rel sisi dan bolt ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(-17.0, -6.0), Vector2(-15.5, -6.0),
		Vector2(-14.3, -20.2), Vector2(-15.8, -20.2),
	]), BESI_CERAH))
	senarai.append(_poli(PackedVector2Array([
		Vector2(17.0, -6.0), Vector2(15.5, -6.0),
		Vector2(14.3, -20.2), Vector2(15.8, -20.2),
	]), BESI_CERAH))
	senarai.append(_bulat(Vector2(-12.0, -5.0), 1.0, BESI_CERAH))
	senarai.append(_bulat(Vector2(12.0, -5.0), 1.0, BESI_CERAH))

	# --- Antena dan lampu status ---
	senarai.append(_poli(PackedVector2Array([
		Vector2(13.4, -19.0), Vector2(14.8, -19.0),
		Vector2(15.5, -24.0), Vector2(14.3, -24.0),
	]), BESI))
	senarai.append(_bulat(Vector2(14.9, -24.6), 1.1, lampu))

	# Tiga lampu kecil di muka alas: kuasa / sedia / cas.
	senarai.append(_bulat(Vector2(-6.0, -4.2), 1.1, lampu))
	senarai.append(_bulat(Vector2(0.0, -4.2), 1.1, lampu_redup))
	senarai.append(_bulat(Vector2(6.0, -4.2), 1.1, lampu_redup))

	return senarai


## Kaca kanopi (lutsinar) yang dilukis SELEPAS robot, jadi robot nampak
## baring di dalam pod semasa mengecas.
static func lapisan_kaca() -> Array:
	var senarai: Array = []
	senarai.append(_poli(PackedVector2Array([
		Vector2(-14.6, -18.2), Vector2(14.6, -18.2),
		Vector2(15.2, -7.0), Vector2(-15.2, -7.0),
	]), Color(0.55, 0.82, 1.0, 0.13)))
	senarai.append(_poli(PackedVector2Array([
		Vector2(-13.8, -18.6), Vector2(13.8, -18.6),
		Vector2(14.1, -19.8), Vector2(-14.1, -19.8),
	]), Color(0.65, 0.88, 1.0, 0.4)))
	senarai.append(_poli(PackedVector2Array([
		Vector2(-10.6, -17.1), Vector2(4.0, -17.1),
		Vector2(3.2, -16.0), Vector2(-9.8, -16.0),
	]), Color(1.0, 1.0, 1.0, 0.09)))
	return senarai


## Raster lukisan pod (tanpa robot) menjadi tekstur ikon untuk butang bina
## dan hologram preview. Saiz reka bentuk 44 unit dimuatkan dalam saiz piksel.
static func buat_ikon(saiz: int = 48) -> ImageTexture:
	var imej := Image.create_empty(saiz, saiz, false, Image.FORMAT_RGBA8)
	imej.fill(Color(0.0, 0.0, 0.0, 0.0))
	var lapisan := lapisan_belakang(true)
	var skala_garis := float(saiz) / 44.0
	var tengah := float(saiz) * 0.5
	var tengah_y := -12.0
	var sampel := 2
	var bilangan_sampel := float(sampel * sampel)

	for y in range(saiz):
		for x in range(saiz):
			var campur := Color(0.0, 0.0, 0.0, 0.0)
			var kira := 0.0
			for sy in range(sampel):
				for sx in range(sampel):
					var p := Vector2(
						(float(x) + (float(sx) + 0.5) / float(sampel) - tengah) / skala_garis,
						(float(y) + (float(sy) + 0.5) / float(sampel) - tengah) / skala_garis + tengah_y
					)
					for i in range(lapisan.size() - 1, -1, -1):
						if _dalam(lapisan[i], p):
							campur += lapisan[i]["warna"]
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


static func _poli(titik: PackedVector2Array, warna: Color) -> Dictionary:
	return {"jenis": "poligon", "titik": titik, "warna": warna}


static func _bulat(pusat: Vector2, jejari: float, warna: Color) -> Dictionary:
	return {"jenis": "bulatan", "pusat": pusat, "jejari": jejari, "warna": warna}
