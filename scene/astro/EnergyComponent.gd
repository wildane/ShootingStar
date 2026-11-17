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

@export_group("Bonus Inverter")
@export var pembahagi_baki: float = 10.0    # baki load inverter yang tak dipakai / 10 jadi kadar cas

var tenaga: float = 100.0
var _baki_rehat: float = 0.0
var kadar_cas_semasa: float = 0.0           # kadar cas sebenar, untuk paparan HUD
var _inverter_pencaj: Array[Node] = []      # inverter yang sedang membekalkan bonus cas
var _stesen_cas: Array[Node] = []           # Charging Station yang sedang mengecas

func _ready() -> void:
	tenaga = max_energy
	kadar_cas_semasa = pulih_sesaat
	set_process(true)

func _process(delta: float) -> void:
	kadar_cas_semasa = _kira_kadar_cas()
	if _baki_rehat > 0.0:
		_baki_rehat -= delta
		return
	if tenaga < max_energy:
		tenaga = minf(max_energy, tenaga + kadar_cas_semasa * delta)

## Kadar cas semasa: asas pulih_sesaat, naik jadi baki_tenaga / pembahagi_baki
## untuk inverter yang ada baki load tak dipakai.
func _kira_kadar_cas() -> float:
	var kadar: float = pulih_sesaat
	var pembahagi: float = pembahagi_baki if pembahagi_baki > 0.001 else 0.001
	var i: int = _inverter_pencaj.size() - 1
	while i >= 0:
		var inverter = _inverter_pencaj[i]
		if not is_instance_valid(inverter):
			_inverter_pencaj.remove_at(i)
		else:
			var baki: float = inverter.baki_tenaga if ("baki_tenaga" in inverter) else 0.0
			if baki > 0.0:
				kadar = maxf(kadar, baki / pembahagi)
		i -= 1

	# Charging Station berkuasa dalam julat memberi kadar cas tetap
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

func daftar_inverter_pencaj(inverter: Node) -> void:
	if inverter == null or _inverter_pencaj.has(inverter):
		return
	_inverter_pencaj.append(inverter)

func nyahdaftar_inverter_pencaj(inverter: Node) -> void:
	_inverter_pencaj.erase(inverter)

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
