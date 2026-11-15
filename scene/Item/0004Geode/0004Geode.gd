extends Area2D

# --- ITEM INFORMATION SETTINGS (Can be filled in the Inspector) ---
@export var id_barang : String = "item_0004"
@export var nama_barang : String = "Rock Anomaly (Geode)"
@export var category : String = "Rare"
@export_multiline var description : String = "A mysterious, hollow rock containing glowing crystalline structures. Bring it back to the Base Lab to analyze and unlock new Blueprints."
@export var ikon_barang : Texture2D

func _ready() -> void:
	# Disable input/touch functions on this node because it is now automatically collected by the magnet Tween
	set_process_input(false)
	print("Item System: ", nama_barang, " ('", id_barang, "') [", category, "] has been spawned!")
