extends StaticBody2D

@onready var sprite = get_node_or_null("Sprite2D")
@onready var area_penderia = get_node_or_null("Area2D")

# LALUAN YANG DIBAIKI: Ditambah HBoxContainer mengikut struktur Scene Tree anda
const TemaPerabot := preload("res://scene/ui/TemaPerabot.gd")

@onready var menu_ui = get_node_or_null("CanvasLayer/MenuUI") 
@onready var butang_tutup = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonTutup")
@onready var butang_demolish = get_node_or_null("CanvasLayer/MenuUI/VBoxContainer/HBoxContainer/ButtonDemolish")

# Mengekalkan saiz kegemaran anda (Lebar: 250, Tinggi: 130)
var saiz_menu_kustom: Vector2 = Vector2(250, 130)

var player_dekat: bool = false

# PEMBOLEH UBAH BAHARU: Pemasa untuk menyekat pepijat input berganda pada telefon pintar
var masa_ketikan_terakhir: float = 0.0
const SELA_MASA_MINIMUM: float = 0.2  # Sekat input kedua jika berlaku dalam jarak 0.2 saat

func _ready():
	if area_penderia:
		area_penderia.input_pickable = true
		area_penderia.body_entered.connect(_on_body_entered)
		area_penderia.body_exited.connect(_on_body_exited)
		area_penderia.input_event.connect(_on_area_input_event)
		
	if menu_ui:
		menu_ui.hide()
		TemaPerabot.pasang(menu_ui)
		menu_ui.custom_minimum_size = saiz_menu_kustom
		
	if butang_tutup:
		butang_tutup.pressed.connect(_on_butang_tutup_pressed)
		
	if butang_demolish:
		butang_demolish.pressed.connect(_on_butang_demolish_pressed)

func _on_body_entered(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = true
		if sprite:
			sprite.modulate = Color(0.3, 1.0, 0.3, 1.0) # 🔴 FABRICATOR TUKAR HIJAU

func _on_body_exited(body: Node2D):
	if body is CharacterBody2D:
		player_dekat = false
		if sprite:
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) # WARNA ASAL
		if menu_ui:
			menu_ui.hide() 

# =========================
# Klik mouse pada PC
# =========================
# AstroStateMachine menandakan setiap klik kiri mouse sebagai "handled" dalam
# _unhandled_input, jadi physics picking Area2D dibatalkan dan input_event
# perabot tidak pernah dicetus pada PC. _input berjalan lebih awal, jadi klik
# dihantar ke pengendali sedia ada sebagai sentuhan maya.
func _input(event: InputEvent) -> void:
	var klik := event as InputEventMouseButton
	if klik == null or not klik.pressed or klik.button_index != MOUSE_BUTTON_LEFT:
		return
	if not player_dekat or area_penderia == null:
		return
	# Jangan rampas klik yang sepatutnya milik butang/panel UI.
	var kawalan := get_viewport().gui_get_hovered_control()
	if kawalan != null and kawalan.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return
	if not _klik_dalam_kawasan(klik.position):
		return
	var sentuhan := InputEventScreenTouch.new()
	sentuhan.index = 0
	sentuhan.position = klik.position
	sentuhan.pressed = true
	_on_area_input_event(get_viewport(), sentuhan, 0)
	get_viewport().set_input_as_handled()


# Zon klik perabot ikut CollisionShape2D pada Area2D, dengan sedikit toleransi.
func _klik_dalam_kawasan(pos_skrin: Vector2) -> bool:
	var titik: Vector2 = area_penderia.to_local(get_canvas_transform().affine_inverse() * pos_skrin)
	var ada_bentuk := false
	for anak in area_penderia.get_children():
		if anak is CollisionShape2D and anak.shape is RectangleShape2D:
			ada_bentuk = true
			var jejari: Vector2 = anak.shape.size * 0.5 + Vector2(2.0, 2.0)
			if Rect2(anak.position - jejari, jejari * 2.0).has_point(titik):
				return true
	if ada_bentuk:
		return false
	return titik.length() < 24.0


# =========================
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	# Semak jenis input sentuhan jari atau klik kiri tetikus
	var ada_sentuhan = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	
	if ada_sentuhan and player_dekat:
		# KOD DIKEMAS KINI: Dapatkan masa semasa permainan berjalan (dalam saat)
		var masa_sekarang = Time.get_ticks_msec() / 1000.0
		
		# JIKA JANGKA MASA KETIKAN TERLALU CEPAT, ABAIKAN INPUT KEDUA TERSEBUT
		if masa_sekarang - masa_ketikan_terakhir < SELA_MASA_MINIMUM:
			return
			
		# Kemas kini masa ketikan rasmi yang berjaya diterima
		masa_ketikan_terakhir = masa_sekarang
		
		if menu_ui:
			# Jalankan suis togol buka/tutup
			menu_ui.visible = !menu_ui.visible
			print("Sistem Khas: Fabricator ditekan! Status menu -> ", menu_ui.visible) # 🔴 LOG DIKEMAS KINI
			
			if menu_ui.visible:
				var saiz_skrin = get_viewport_rect().size
				
				# Menghapuskan ralat skala global daripada StaticBody2D
				var skala_fabricator = global_scale # 🔴 PEMBOLEH UBAH DIKEMAS KINI
				menu_ui.scale = Vector2(1.0 / skala_fabricator.x, 1.0 / skala_fabricator.y) if skala_fabricator.x != 0 and skala_fabricator.y != 0 else Vector2(1, 1)
				
				# Kedudukan berpusat di tengah-tengah atas skrin (Y = 50)
				var koordinat_x_tengah = (saiz_skrin.x / 2) - (saiz_menu_kustom.x / 2)
				menu_ui.global_position = Vector2(koordinat_x_tengah, 50)
				
			get_viewport().set_input_as_handled()

func _on_butang_tutup_pressed():
	if menu_ui:
		menu_ui.hide()

# FUNGSI MEMADAM: Memadam objek Fabricator dari peta apabila butang demolish ditekan
# Kos bina ikut KitchenTable_Preview.tscn: 1 Meteorite Ice + 3 Basic Iron Ore.
func kos_bina() -> Array:
	return [
		{"id": "item_0002", "nama": "Meteorite Ice", "ikon": load("res://scene/Item/0002MeteoriteIce/Image_393.png"), "scene_path": "res://scene/Item/0002MeteoriteIce/MeteoriteIce.tscn", "diperlukan": 1},
		{"id": "item_0001", "nama": "Basic Iron Ore", "ikon": load("res://scene/Item/0001BasicIronOre/Image_959.png"), "scene_path": "res://scene/Item/0001BasicIronOre/0001BasicIronOre.tscn", "diperlukan": 3},
	]

func _on_butang_demolish_pressed():
	print("Sistem Khas: Fabricator telah dimusnahkan!") # 🔴 LOG DIKEMAS KINI
	# Pulangkan bahan bina (popup "+N <nama>") sebelum perabot dibuang.
	BahanBinaan.pulangkan(self)
	
	# Set semula status logik sebelum objek dipadamkan dari memori
	player_dekat = false
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		
	# Memadam keseluruhan StaticBody2D (Fabricator dan UI sekali) secara selamat dari memori
	PowerGrid.tanda_kotor_semua("bina_atau_roboh")
	queue_free()
