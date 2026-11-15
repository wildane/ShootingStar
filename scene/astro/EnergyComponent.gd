extends Node

## Tenaga pemain: digunakan untuk bergerak di angkasa dan untuk drone menembak.

@export_group("Tenaga")
@export var max_energy: float = 100.0

@export_group("Penggunaan")
@export var kos_gerak_sesaat: float = 8.0   # tenaga dipakai setiap saat bergerak
@export var kos_tembakan: float = 6.0       # tenaga dipakai setiap tembakan drone

@export_group("Pemulihan")
@export var pulih_sesaat: float = 14.0      # tenaga dipulihkan setiap saat
@export var masa_rehat: float = 0.7         # tunggu sebelum mula pulih

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
func guna_tembakan() -> bool:
	if tenaga < kos_tembakan:
		return false
	tenaga -= kos_tembakan
	_baki_rehat = masa_rehat
	return true

func isi_penuh() -> void:
	tenaga = max_energy
	_baki_rehat = 0.0
