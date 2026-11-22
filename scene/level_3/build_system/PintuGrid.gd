class_name PintuGrid
extends Node2D

## Paun navigasi untuk tile pintu yang dibina pemain di BuildGrid.
##
## Dinding yang dibina pemain berada pada layer 4 (nilai 8), jadi robot
## pekerja menganggapnya penghalang. Pintu pula penghalang sementara: kolider
## pintu dimatikan bila pemain atau robot menghampiri. Supaya sistem laluan
## robot tahu pintu itu boleh dilalui, node ini didaftarkan dalam group
## "PintuGrid" dan memberikan dua titik pada kedua-dua belah pintu.
##
## Robot tidak perlu teleport di sini (tidak seperti Doorway_Actual): pintu
## ini betul-betul terbuka, jadi robot cuma berjalan melaluinya. Robot
## mengenal pasti ini kerana node ini tiada fungsi lalu_automatik().

var grid: Node = null
var sel: Vector2i = Vector2i.ZERO
var saiz_sel: float = 16.0

## Dua titik di kiri/kanan atau atas/bawah pintu, mengikut arah dinding di
## sebelahnya supaya sambungan laluan merentasi pintu, bukan memanjang dinding.
func titik_pintasan() -> Array[Vector2]:
	var paksi := Vector2.RIGHT
	if grid != null and is_instance_valid(grid) and grid.has_method("paksi_lintasan"):
		paksi = grid.paksi_lintasan(sel)
	var jarak: float = saiz_sel + 4.0
	return [global_position - paksi * jarak, global_position + paksi * jarak]
