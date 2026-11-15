extends Area2D

# --- ITEM INFORMATION SETTINGS (Can be filled in the Inspector) ---
@export var id_barang : String = "item_0000"
@export var nama_barang : String = "name"
@export var category : String = "common"
@export_multiline var description : String = "text"
@export var ikon_barang : Texture2D

func _ready() -> void:
	# Disable input/touch functions on this node because it is now automatically collected by the magnet Tween
	set_process_input(false)
	print("Item System: ", nama_barang, " ('", id_barang, "') [", category, "] has been spawned!")
