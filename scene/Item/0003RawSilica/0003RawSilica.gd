extends Area2D

# --- ITEM INFORMATION SETTINGS (Can be filled in the Inspector) ---
@export var id_barang : String = "item_0003"
@export var nama_barang : String = "Raw Silica"
@export var category : String = "Uncommon"
@export_multiline var description : String = "Coarse mineral crystals critical for manufacturing basic electronic components and early-game Solar Panels."
@export var ikon_barang : Texture2D

func _ready() -> void:
	# Disable input/touch functions on this node because it is now automatically collected by the magnet Tween
	set_process_input(false)
	print("Item System: ", nama_barang, " ('", id_barang, "') [", category, "] has been spawned!")
