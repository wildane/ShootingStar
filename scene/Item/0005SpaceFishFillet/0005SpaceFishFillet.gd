extends Area2D

# --- ITEM INFORMATION SETTINGS (Can be filled in the Inspector) ---
@export var id_barang : String = "item_0005"
@export var nama_barang : String = "Space Fish Fillet"
@export var category : String = "Common"
@export_multiline var description : String = "Organic protein source. Consumed to restore player Suit Stamina/HP."
@export var ikon_barang : Texture2D

func _ready() -> void:
	# Disable input/touch functions on this node because it is now automatically collected by the magnet Tween
	set_process_input(false)
	print("Item System: ", nama_barang, " ('", id_barang, "') [", category, "] has been spawned!")
