extends Button

# Pautkan nod UI Inventory anda dari Inspector
@export var inventory_ui : Control

func _ready() -> void:
	# 1. Sambung isyarat pressed Butang Utama ke fungsi tempatan jika belum bersambung
	if not self.pressed.is_connected(_on_self_pressed):
		self.pressed.connect(_on_self_pressed)
	
	# 2. Hubungkan butang tutup (CloseButton) yang berada di dalam inventory secara automatik
	call_deferred("_sambung_butang_tutup_inventory")

func _sambung_butang_tutup_inventory() -> void:
	if inventory_ui != null:
		# Cari nod CloseButton di bawah inventory_ui secara dinamik
		var close_button = inventory_ui.find_child("CloseButton", true, false) as Button
		if close_button != null:
			if not close_button.pressed.is_connected(_on_close_button_pressed):
				close_button.pressed.connect(_on_close_button_pressed)
				print("Sistem Butang Utama: Berjaya mengawal CloseButton dari luar!")
	else:
		print("Amaran: 'inventory_ui' belum dipautkan. Gagal menyambung CloseButton.")

# AKSI APABILA BUTANG UTAMA DITEKAN (SUIS ON/OFF)
func _on_self_pressed() -> void:
	if inventory_ui == null:
		print("Ralat: 'inventory_ui' belum dipautkan di Inspector!")
		return
		
	# Jika inventory sedang terbuka, tutup ia guna fungsi perkongsian
	if inventory_ui.visible:
		_on_close_button_pressed()
	# Jika inventory sedang tertutup, tamatkan mod bina dan buka ia
	else:
		# Tutup panel bina / pilihan dron dulu supaya tak bertindih
		_tutup_menu_lain()
		var pengurus_bina = get_tree().current_scene
		if pengurus_bina and pengurus_bina.has_method("tamatkan_mod_pembinaan"):
			pengurus_bina.tamatkan_mod_pembinaan()
		
		if inventory_ui.has_method("show_inventory"):
			inventory_ui.show_inventory()
		else:
			inventory_ui.visible = true

# Dipanggil oleh menu cepat lain (bina / dron) bila ia dibuka
func tutup_menu_cepat() -> void:
	if inventory_ui != null and inventory_ui.visible:
		_on_close_button_pressed()

func _tutup_menu_lain() -> void:
	var induk := get_parent()
	if induk == null:
		return
	for nod in induk.get_children():
		if nod == self:
			continue
		if nod.has_method("tutup_menu_cepat"):
			nod.tutup_menu_cepat()
		elif nod.has_method("tutup_menu"):
			nod.tutup_menu()

# AKSI APABILA BUTANG TUTUP (CLOSE BUTTON) DIKLIK ATAU DIARAH TUTUP
func _on_close_button_pressed() -> void:
	if inventory_ui != null:
		inventory_ui.visible = false
		
		# Jalankan fungsi kosongkan info yang ada di dalam skrip inventory
		if inventory_ui.has_method("_kosongkan_info"):
			inventory_ui._kosongkan_info()
		
		print("Sistem Butang Utama: Inventori telah ditutup & info dikosongkan.")
