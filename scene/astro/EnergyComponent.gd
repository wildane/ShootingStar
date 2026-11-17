extends Node

## Tenaga pemain: digunakan untuk bergerak di angkasa dan untuk drone menembak.

@export_group("Tenaga")
@export var max_energy: float = 100.0

@export_group("Penggunaan")
@export var kos_gerak_sesaat: float = 0.5   # tenaga dipakai setiap saat bergerak (sangat jimat)
@export var kos_tembakan: float = 6.0       # kos lalai jika drone tak tetapkan kos sendiri

@export_group("Pemulihan (Guna Solar)")
@export var pulih_sesaat: float = 0.1       # cas perlahan, macam panel solar
@export var masa_rehat: float = 1.0         # tunggu sebelum mula cas

var tenaga: float = 100.0
var _baki_rehat: float = 0.0
var kadar_cas_semasa: float = 0.0           # kadar cas sebenar, untuk paparan HUD
var _stesen_cas: Array[Node] = []           # Charging Station yang sedang mengecas
var _efek_cas: Node2D = null                # kesan arka semasa dicas
var _efek_aktif_terakhir: bool = false

func _ready() -> void:
	tenaga = max_energy
	kadar_cas_semasa = pulih_sesaat
	_sediakan_efek_cas()
	set_process(true)

# Kesan visual arka berputar di sekeliling badan player semasa dicas stesen.
func _sediakan_efek_cas() -> void:
	if _efek_cas != null:
		return
	var skrip = load("res://scene/astro/ChargeEffect.gd")
	if skrip == null:
		return
	_efek_cas = Node2D.new()
	_efek_cas.name = "EfekCas"
	_efek_cas.set_script(skrip)
	_efek_cas.position = Vector2.ZERO
	# Jadi anak terus player (bukan child EnergyComponent) supaya kesan
	# boleh ikut SpriteBase dan SpriteAngkasa dan lukis atas kedua-duanya.
	var ibu: Node = get_parent()
	if ibu == null:
		ibu = self
	ibu.add_child(_efek_cas)
	print("[Cas] EfekCas dicipta bawah ", ibu.name)

func _kemas_kini_efek_cas() -> void:
	if _efek_cas == null or not ("aktif" in _efek_cas):
		return
	# Kesan hanya bila kadar cas benar-benar meningkat (dicas stesen)
	# dan tenaga belum penuh.
	var mengecas: bool = tenaga < max_energy - 0.001 and kadar_cas_semasa > pulih_sesaat + 0.001
	_efek_cas.aktif = mengecas
	if mengecas != _efek_aktif_terakhir:
		_efek_aktif_terakhir = mengecas
		print("[Cas] kesan cas ", "HIDUP" if mengecas else "MATI", "  kadar=", kadar_cas_semasa)

func _process(delta: float) -> void:
	kadar_cas_semasa = _kira_kadar_cas()
	_kemas_kini_efek_cas()
	if _baki_rehat > 0.0:
		_baki_rehat -= delta
		return
	if tenaga < max_energy:
		tenaga = minf(max_energy, tenaga + kadar_cas_semasa * delta)

## Kadar cas semasa: asas pulih_sesaat, atau lebih tinggi bila berada
## dalam julat Charging Station yang berkuasa.
func _kira_kadar_cas() -> float:
	var kadar: float = pulih_sesaat
	var j: int = _stesen_cas.size() - 1
	while j >= 0:
		var stesen = _stesen_cas[j]
		if not is_instance_valid(stesen):
			_stesen_cas.remove_at(j)
		else:
			var kadar_stesen: float = stesen.kadar_cas_semasa if ("kadar_cas_semasa" in stesen) else 0.0
			if kadar_stesen > 0.0:
				kadar = maxf(kadar, kadar_stesen)
		j -= 1
	return kadar

func daftar_stesen_cas(stesen: Node) -> void:
	if stesen == null or _stesen_cas.has(stesen):
		return
	_stesen_cas.append(stesen)

func nyahdaftar_stesen_cas(stesen: Node) -> void:
	_stesen_cas.erase(stesen)

func nisbah() -> float:
	if max_energy <= 0.0:
		return 0.0
	return clampf(tenaga / max_energy, 0.0, 1.0)

func ada_tenaga() -> bool:
	return tenaga > 0.0

## Panggil setiap frame semasa pemain bergerak.
func guna_gerak(delta: float) -> void:
	if tenaga <= 0.0:
		return
	tenaga = maxf(0.0, tenaga - kos_gerak_sesaat * delta)
	_baki_rehat = masa_rehat

## Cuba bayar kos tembakan. Pulangkan true jika tembakan dibenarkan.
func guna_tembakan(kos: float = -1.0) -> bool:
	var kos_sebenar: float = kos_tembakan if kos < 0.0 else kos
	if tenaga < kos_sebenar:
		return false
	tenaga -= kos_sebenar
	_baki_rehat = masa_rehat
	return true

func isi_penuh() -> void:
	tenaga = max_energy
	_baki_rehat = 0.0
