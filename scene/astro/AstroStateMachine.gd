extends Node
class_name AstroStateMachine

@export var state_awal: Node
var state_sekarang: Node

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

	# --- SOKONGAN MOUSE ---
	# Klik kiri + heret mouse ditukar jadi sentuhan maya (jari 0),
	# jadi joystick sentuh sedia ada terus berfungsi tanpa ubah state lain.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var sentuhan := InputEventScreenTouch.new()
		sentuhan.index = 0
		sentuhan.position = event.position
		sentuhan.pressed = event.pressed
		state_sekarang.kendalikan_input(sentuhan)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var heret := InputEventScreenDrag.new()
		heret.index = 0
		heret.position = event.position
		heret.relative = event.relative
		state_sekarang.kendalikan_input(heret)
		get_viewport().set_input_as_handled()
		return

	state_sekarang.kendalikan_input(event)

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
		state_sekarang.keluar_state()
	
	state_sekarang = state_baru
	print("STATE BERJAYA DITUKAR KEPADA: ", state_baru.name)
	state_sekarang.masuk_state()
