extends RefCounted
class_name StorThreat

## Kiraan threat yang dikongsi seluruh game (static):
##   bunuh       - bilangan husk yang dibunuh sejak serangan terakhir
##   masa_serang - baki masa sebelum serangan (-1 = tiada serangan)
##
## Static supaya nilai kekal merentas muat semula scene dan boleh dibaca menu
## walaupun autoload SeranganBalas belum siap dimuatkan.

const MASA_SERANGAN: float = 5.0

static var bunuh: int = 0
static var masa_serang: float = -1.0

# Dipanggil HuskLurker setiap kali ia tumbang.
static func daftar_bunuh() -> void:
	bunuh += 1
	if masa_serang < 0.0:
		masa_serang = MASA_SERANGAN

static func reset() -> void:
	bunuh = 0
	masa_serang = -1.0
