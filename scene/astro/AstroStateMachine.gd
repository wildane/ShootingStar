extends Node
class_name AstroStateMachine

@export var state_awal: Node
var state_sekarang: Node

# ==========================================================
# KAWALAN SENTUH MERENTAS STATE
# Pertukaran state berlaku ketika jari masih menekan skrin (masuk/keluar
# asteroid). Data di sini dikekalkan supaya state baru boleh menyambung
# semula joystick dan sasaran click-to-move tanpa pemain angkat jari.
# ==========================================================
var jari_tertekan: Dictionary = {}  # index -> posisi skrin semasa
var pusat_jari: Dictionary = {}     # index -> posisi mula tekan
var jari_joystick: int = -1

var sasaran_lama_ada: bool = false
var sasaran_lama_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	await get_parent().ready
	
	# Berikan rujukan Astro2 kepada semua state anak
	for child in get_children():
		if child is AstroAntaramuka:
			child.astro = get_parent()
	
	# Paksa aktifkan state awal
	if state_awal:
		tukar_state(state_awal)
	else:
		# Jika terlepas pandang di Inspector, kita paksa ambil anak pertama (BaseState)
		if get_child_count() > 0:
			tukar_state(get_child(0))

# Guna _unhandled_input supaya sentuhan/klik pada UI (CanvasLayer/Control) tidak
# mencetuskan gerakan pemain (input UI diproses dahulu oleh fasa GUI).
func _unhandled_input(event: InputEvent) -> void:
	if not state_sekarang:
		return

	# Tap pada pintu/perabot ialah interaksi objek, bukan arahan bergerak.
	# Tanpa semakan ini, tap pada pintu turut menetapkan sasaran click-to-move
	# ke pintu, jadi pemain terbang semula ke pintu selepas teleport.
	if event is InputEventScreenTouch and event.pressed:
		if _titik_kena_objek_interaktif(event.position):
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _titik_kena_objek_interaktif(event.position):
			return

	var input_state := _input_sentuhan(event)
	_rekod_sentuhan(input_state)
	state_sekarang.kendalikan_input(input_state)
	if input_state != event:
		get_viewport().set_input_as_handled()

# Klik kiri + herek mouse ditukar jadi sentuhan maya (jari 0), jadi joystick
# sentuh sedia ada terus berfungsi tanpa ubah state lain.
func _input_sentuhan(event: InputEvent) -> InputEvent:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var sentuhan := InputEventScreenTouch.new()
		sentuhan.index = 0
		sentuhan.position = event.position
		sentuhan.pressed = event.pressed
		return sentuhan

	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var heret := InputEventScreenDrag.new()
		heret.index = 0
		heret.position = event.position
		heret.relative = event.relative
		return heret

	return event

# Simpan jari yang masih menekan skrin untuk state seterusnya.
func _rekod_sentuhan(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if jari_joystick == -1:
				jari_joystick = event.index
			jari_tertekan[event.index] = event.position
			pusat_jari[event.index] = event.position
		else:
			jari_tertekan.erase(event.index)
			pusat_jari.erase(event.index)
			if event.index == jari_joystick:
				jari_joystick = -1
	elif event is InputEventScreenDrag:
		jari_tertekan[event.index] = event.position

# Adakah titik skrin ini terkena pintu atau perabot interaktif? Semakan guna
# physics point query kerana physics picking mungkin belum berjalan.
func _titik_kena_objek_interaktif(pos_skrin: Vector2) -> bool:
	var dunia: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * pos_skrin
	var params := PhysicsPointQueryParameters2D.new()
	params.position = dunia
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for hasil in get_viewport().get_world_2d().direct_space_state.intersect_point(params, 16):
		var kolider := hasil.get("collider") as Node
		if kolider != null and _objek_interaktif(kolider):
			return true
	return false

func _objek_interaktif(nod: Node) -> bool:
	var semasa: Node = nod
	for _i in range(3):
		if semasa == null:
			return false
		if semasa.is_in_group("Pintu") or semasa.is_in_group("Furniture"):
			return true
		semasa = semasa.get_parent()
	return false

func _mouse_di_atas_ui() -> bool:
	# Jangan rampas klik yang sepatutnya pergi ke butang/panel UI
	var kawalan: Control = get_viewport().gui_get_hovered_control()
	return kawalan != null and kawalan.mouse_filter != Control.MOUSE_FILTER_IGNORE

func _physics_process(delta: float) -> void:
	if state_sekarang:
		state_sekarang.kemas_kini_fizik(delta)
	else:
		print("AMARAN: Tiada state yang sedang aktif dalam State Machine!")

func tukar_state(state_baru: Node) -> void:
	if state_baru == null:
		return
		
	if state_sekarang:
		# Sasaran click-to-move state lama dibawa ke state baru, supaya player
		# yang sedang terbang ke satu titik terus bergerak selepas bertukar.
		sasaran_lama_ada = "ada_target" in state_sekarang and bool(state_sekarang.ada_target)
		sasaran_lama_pos = state_sekarang.pos_target if sasaran_lama_ada else Vector2.ZERO
		state_sekarang.keluar_state()
	
	state_sekarang = state_baru
	print("STATE BERJAYA DITUKAR KEPADA: ", state_baru.name)
	state_sekarang.masuk_state()
