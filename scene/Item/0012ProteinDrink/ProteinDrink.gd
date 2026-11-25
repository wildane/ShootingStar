extends Area2D

# --- ITEM INFORMATION SETTINGS (Can be filled in the Inspector) ---
@export var id_barang : String = "item_0012"
@export var nama_barang : String = "Protein Drink"
@export var category : String = "Refined"
@export_multiline var description : String = "Protein shake made at the kitchen from water and space fish fillet. Drinking it restores 1 HP. Drinks automatically when HP drops to 1 or less (5 second cooldown) if one is in the inventory."
@export var ikon_barang : Texture2D
