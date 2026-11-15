extends Node

# ==========================================================
# 📊 CENTRAL MANAGEMENT VARIABLES
# ==========================================================
var hologram_aktif: Node2D = null
var laluan_objek_sebenar: String = ""

var mod_pembinaan: bool = false

# Laluan preview yang sedang aktif, untuk kesan "tekan butang bangunan sama".
var laluan_preview_semasa: String = ""

# true = input terakhir dari mouse (desktop) / false = sentuhan (telefon).
# Versi mouse: klik = bina, klik kanan = batal, jadi butang ✓/✗ tak perlu.
var guna_mouse: bool = not DisplayServer.is_touchscreen_available()
var boleh_terima_sentuhan: bool = false
var posisi_jari_terakhir: Vector2 = Vector2.ZERO

# ==========================================================
# 🏗️ CONSTRUCTION INITIALIZATION
# ==========================================================
func mulakan_pembinaan(laluan_preview: String, laluan_actual: String, _nama_group: String = ""):
	# 1. Bersihkan sebarang mod binaan lama yang tersangkut
	tamatkan_pembinaan()
	
	# NOTA: Kita tidak lagi mengambil butang confirm/cancel statik lama dari current_scene
	# kerana skrip fabricator_preview kini sudah mempunyai butang terapungnya sendiri.
	
	laluan_objek_sebenar = laluan_actual
	
	# 2. Muat turun dan spawn hologram preview
	var scene_preview = load(laluan_preview)
	if scene_preview:
		hologram_aktif = scene_preview.instantiate()
		
		# Masukkan fail bangunan sebenar ke dalam variabel export hologram secara dinamik
		if "fail_bangunan_sebenar_tscn" in hologram_aktif:
			hologram_aktif.fail_bangunan_sebenar_tscn = laluan_actual
		
		var y_sort_container = get_tree().current_scene.get_node_or_null("Y_Sort_Container")
		if y_sort_container and is_instance_valid(y_sort_container):
			y_sort_container.add_child(hologram_aktif)
		else:
			get_tree().current_scene.add_child(hologram_aktif)
	else:
		print("BuildManager Error: Gagal memuatkan preview scene -> ", laluan_preview)
		return
		
	# Ingat preview mana yang aktif (butang bangunan guna ini untuk batal/tukar)
	laluan_preview_semasa = laluan_preview

	# 3. Letakkan posisi hologram tepat di tengah-tengah kamera/skrin view
	var pusat_kamera = Vector2.ZERO
	var kamera = get_viewport().get_camera_2d()
	
	if kamera and is_instance_valid(kamera):
		pusat_kamera = kamera.get_screen_center_position()
	else:
		var saiz_viewport = get_viewport().get_visible_rect().size
		pusat_kamera = get_tree().current_scene.get_global_transform().affine_inverse() * (saiz_viewport / 2)
		
	if hologram_aktif:
		# Desktop/mouse: terus letak preview bawah kursor mouse (kalau ada)
		var pos_mouse = get_viewport().get_mouse_position()
		if get_viewport().get_visible_rect().has_point(pos_mouse):
			hologram_aktif.global_position = _skrin_ke_dunia(pos_mouse)
		else:
			hologram_aktif.global_position = pusat_kamera
		
	# Versi mouse: tak perlu butang ✓/✗ (klik = bina, klik kanan = batal)
	sembunyi_butang_hologram()

	posisi_jari_terakhir = get_viewport().get_mouse_position()
	
	mod_pembinaan = true
	
	# Mengelakkan pepijat (bug) klik berganda pada skrin peranti pintar
	boleh_terima_sentuhan = false
	get_tree().create_timer(0.2).timeout.connect(func(): boleh_terima_sentuhan = true)

# ==========================================================
# 🎮 SCREEN INPUT DRAG & TOUCH (Kekal Ikut Logik Asal)
# ==========================================================
func _input(event: InputEvent):
	# Kesan input terakhir: mouse atau sentuhan
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		guna_mouse = true
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		guna_mouse = false

	if not mod_pembinaan or not is_instance_valid(hologram_aktif) or not boleh_terima_sentuhan:
		return

	# --- VERSI MOUSE: preview ikut kursor terus (tak perlu heret) ---
	if event is InputEventMouseMotion:
		ikut_mouse(event.position)
		return

	# --- VERSI MOUSE: klik kiri = BINA, klik kanan = BATAL ---
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			batal_pembinaan()
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			# Klik atas UI (panel build / butang) jangan jadi binaan
			if get_viewport().gui_get_hovered_control() == null:
				ikut_mouse(event.position)
				cuba_bina()
				get_viewport().set_input_as_handled()
			return
		
	if event is InputEventScreenTouch:
		# Jika sentuhan terkena pada mana-mana butang UI, abaikan pergerakan drag hologram
		if event.pressed:
			posisi_jari_terakhir = event.position

	if event is InputEventScreenDrag:
		var jarak_skrin = event.position - posisi_jari_terakhir
		var jarak_dunia = get_tree().current_scene.get_canvas_transform().affine_inverse().basis_xform(jarak_skrin)
		
		hologram_aktif.global_position += jarak_dunia
		posisi_jari_terakhir = event.position

# Sembunyi butang ✓/✗ pada hologram (kekalkan senarai bahan)
func sembunyi_butang_hologram() -> void:
	if not guna_mouse or not is_instance_valid(hologram_aktif):
		return
	if "bekas_butang" in hologram_aktif and is_instance_valid(hologram_aktif.bekas_butang):
		hologram_aktif.bekas_butang.visible = false

# Bina di posisi semasa (klik kiri mouse). Guna logik butang confirm hologram
# supaya bahan dipotong dan bangunan sebenar di-spawn sama macam versi sentuh.
func cuba_bina() -> void:
	if not is_instance_valid(hologram_aktif):
		return

	var boleh: bool = true
	if "boleh_pasang" in hologram_aktif:
		boleh = hologram_aktif.boleh_pasang
	if "ada_cukup_bahan" in hologram_aktif:
		boleh = boleh and hologram_aktif.ada_cukup_bahan

	if not boleh:
		print("Bina: tak boleh di sini (merah) atau bahan tak cukup")
		return

	if hologram_aktif.has_method("_on_butang_confirm_pressed"):
		hologram_aktif._on_butang_confirm_pressed()
	else:
		print("Bina: preview ini tiada fungsi confirm")
		return

	tamatkan_pembinaan()

# Butang bangunan: tekan jenis yang SAMA = batal, jenis LAIN = tukar preview.
func tukar_atau_batal_pembinaan(laluan_preview: String, laluan_actual: String) -> void:
	if mod_pembinaan and laluan_preview_semasa == laluan_preview:
		batal_pembinaan()
		return
	mulakan_pembinaan(laluan_preview, laluan_actual)

# Batal binaan (klik kanan mouse)
func batal_pembinaan() -> void:
	if is_instance_valid(hologram_aktif) and hologram_aktif.has_method("_on_butang_cancel_pressed"):
		hologram_aktif._on_butang_cancel_pressed()
	tamatkan_pembinaan()

# Tukar posisi skrin (mouse) kepada posisi dunia (ikut kamera)
func _skrin_ke_dunia(pos_skrin: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos_skrin

# Preview ikut kursor mouse. Berhenti ikut bila kursor di atas UI
# (butang confirm/cancel terapung) supaya butang tu boleh ditekan.
func ikut_mouse(pos_skrin: Vector2) -> void:
	if not is_instance_valid(hologram_aktif):
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	hologram_aktif.global_position = _skrin_ke_dunia(pos_skrin)

# ==========================================================
# 🔨 CLEANUP & TERMINATION
# ==========================================================
func tamatkan_pembinaan():
	mod_pembinaan = false
	boleh_terima_sentuhan = false
	laluan_preview_semasa = ""
	
	# Padam hologram preview jika ia masih aktif di dalam babak
	if is_instance_valid(hologram_aktif):
		hologram_aktif.queue_free()
	hologram_aktif = null
