extends RefCounted
class_name StorThreat

## Kiraan threat yang dikongsi seluruh game (static) dan disimpan ke cakera:
##   bunuh       - jumlah husk yang dibunuh (1 bunuhan = 1% threat)
##   masa_serang - baki saat sebelum serangan (-1 = tiada serangan berjalan)
##
## Static supaya nilai kekal merentas muat semula scene dan boleh dibaca menu
## walaupun pemantau serangan belum siap dimuatkan. Nilai juga ditulis ke
## user://threat.json supaya threat dan pemasa kekal selepas game ditutup.

const MASA_SERANGAN: float = 180.0  # 3 minit selepas bunuhan pertama
const LALUAN_SIMPAN: String = "user://threat.json"

## Julat penyerang bagi setiap tangga 10% threat:
## 10% = 1, 20% = 1-2, 30% = 2-3, 40% = 3, 50% = 3-4,
## 60% = 4, 70% = 4-5, 80% = 5, 90% = 5-6, 100% = 6.
const JULAT_RAIDER: Array[Vector2i] = [
	Vector2i(0, 0),  # 0%
	Vector2i(1, 1),  # 10%
	Vector2i(1, 2),  # 20%
	Vector2i(2, 3),  # 30%
	Vector2i(3, 3),  # 40%
	Vector2i(3, 4),  # 50%
	Vector2i(4, 4),  # 60%
	Vector2i(4, 5),  # 70%
	Vector2i(5, 5),  # 80%
	Vector2i(5, 6),  # 90%
	Vector2i(6, 6),  # 100%
]

static var bunuh: int = 0
static var masa_serang: float = -1.0

static var _dimuat: bool = false

# ---- nilai terkira ----

# Threat dalam peratus (1 bunuhan = 1%), maksimum 100%.
static func peratus() -> int:
	return clampi(bunuh, 0, 100)

# Julat bilangan penyerang untuk threat semasa (contoh: 20% -> 1-2).
static func julat_raider() -> Vector2i:
	var tangga: int = clampi(peratus() / 10, 0, JULAT_RAIDER.size() - 1)
	return JULAT_RAIDER[tangga]

# Bilangan penyerang sebenar untuk gelombang ini (rawak antara julat).
static func bilangan_raider() -> int:
	var julat: Vector2i = julat_raider()
	return randi_range(julat.x, julat.y)

# ---- kitaran serangan ----

# Dipanggil HuskLurker setiap kali ia tumbang. Pemasa hanya bermula pada
# bunuhan pertama selepas gelombang sebelumnya; bunuhan seterusnya semasa
# kiraan detik hanya menambah threat untuk gelombang itu.
static func daftar_bunuh() -> void:
	muat()
	bunuh += 1
	if masa_serang < 0.0 and bunuh > 0:
		masa_serang = MASA_SERANGAN
		print("StorThreat: bunuhan baru, serangan balas dalam %.0f saat (threat %d%%)" % [MASA_SERANGAN, peratus()])
	simpan()

# Gelombang sudah dilancarkan: pemasa berhenti dan hanya bermula semula
# apabila pemain membunuh husk lagi. Threat (bunuh) dikekalkan.
static func selesai_gelombang() -> void:
	masa_serang = -1.0
	simpan()

static func set_masa(baki: float) -> void:
	masa_serang = baki

static func reset() -> void:
	bunuh = 0
	masa_serang = -1.0
	_dimuat = true
	simpan()

# ---- simpan / muat ----

# Snapshot untuk fail simpanan slot: threat dan baki masa pada saat itu.
# Nilai cakera (threat.json) terus berubah selepas pemain bunuh husk atau
# menunggu, jadi load slot mesti pulihkan salinan slot, bukan cakera.
static func data_simpanan() -> Dictionary:
	muat()
	return {"bunuh": bunuh, "masa": masa_serang}

# Pulihkan threat daripada fail simpanan slot yang dimuatkan.
static func pakai_data_simpanan(data: Dictionary) -> void:
	if data.is_empty():
		return
	bunuh = maxi(0, int(data.get("bunuh", 0)))
	var baki: float = float(data.get("masa", -1.0))
	masa_serang = baki if baki > 0.0 else -1.0
	_dimuat = true
	simpan()
	print("StorThreat: pulih dari simpanan, threat %d%%, baki %.1f saat" % [peratus(), masa_serang])

# Baca nilai tersimpan sekali sahaja (selamat dipanggil berulang kali).
static func muat() -> void:
	if _dimuat:
		return
	_dimuat = true
	if not FileAccess.file_exists(LALUAN_SIMPAN):
		return
	var fail := FileAccess.open(LALUAN_SIMPAN, FileAccess.READ)
	if fail == null:
		return
	var data: Variant = JSON.parse_string(fail.get_as_text())
	fail = null
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	bunuh = maxi(0, int(d.get("bunuh", 0)))
	var baki: float = float(d.get("masa", -1.0))
	# Simpan sebagai -1 (tiada serangan) atau baki saat positif.
	masa_serang = baki if baki >= 0.0 else -1.0

static func simpan() -> void:
	var fail := FileAccess.open(LALUAN_SIMPAN, FileAccess.WRITE)
	if fail == null:
		return
	fail.store_string(JSON.stringify({"bunuh": bunuh, "masa": masa_serang}))
	fail = null
