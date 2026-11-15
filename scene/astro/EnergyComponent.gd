extends Node

## Tenaga pemain: digunakan untuk bergerak di angkasa dan untuk drone menembak.

@export_group("Tenaga")
@export var max_energy: float = 100.0

@export_group("Penggunaan")
@export var kos_gerak_sesaat: float = 0.5   # tenaga dipakai setiap saat bergerak (sangat jimat)
@export var kos_tembakan: float = 6.0       # kos lalai jika drone tak tetapkan kos sendiri

@export_group("Pemulihan (Guna Solar)")
@export var pulih_sesaat: float = 2.0       # cas perlahan, macam panel solar
@export var masa_rehat: float = 1.0         # tunggu sebelum mula cas

var tenaga: float = 100.0
var _baki_rehat: float = 0.0

func _ready() -> void:
	tenaga = max_energy
	set_process(true)

func _process(delta: float) -> void:
	if _baki_rehat > 0.0:
		_baki_rehat -= delta
		return
	if tenaga < max_energy:
		tenaga = minf(max_energy, tenaga + pulih_sesaat * delta)

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
