extends AstroAntaramuka
class_name AstroAngkasaState

# ==========================================================
# EXPORTS (BOLEH LARAS DI INSPECTOR ANGKASASTATE)
# ==========================================================
@export_group("Fizik Angkasa")
@export var max_speed: float = 50.0          
@export var acceleration: float = 12.0       
@export var rotation_speed: float = 8.0      
@export var sprite_direction_offset: float = 90.0 
@export var reverse_speed_multiplier: float = 0.5 # Potong kelajuan undur (0.5 = 50%)

@export_group("Tetapan Joystick")
@export var joystick_range: float = 60.0     
@export var deadzone: float = 0.1            

@export_group("Klik Untuk Gerak (Click To Move)")
@export var click_to_move: bool = true
@export var jarak_berhenti: float = 12.0
@export var jarak_perlahan: float = 80.0 # mula perlahan bila jarak kurang dari ini

# ==========================================================
# INTERNAL VARIABLES
# ==========================================================
var joystick_active: bool = false
var joystick_id: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var joystick_dir: Vector2 = Vector2.ZERO
var velocity_target: Vector2 = Vector2.ZERO

# Klik/tap = terbang ke titik itu (dibatalkan bila joystick digerakkan)
var ada_target: bool = false
var pos_target: Vector2 = Vector2.ZERO

var touches: Dictionary = {}

var lock_on_comp: LockOnComponent = null

func masuk_state() -> void:
	print("-> Mengaktifkan Visual AngkasaState (Guna Sentuhan Tepat Komponen)")
	
	var sprite_angkasa = astro.get_node_or_null("SpriteAngkasa")
	if sprite_angkasa:
		sprite_angkasa.show()
		
	var sprite_base = astro.get_node_or_null("SpriteBase")
	if sprite_base:
		sprite_base.hide()
	
	joystick_active = false
	joystick_id = -1
	joystick_dir = Vector2.ZERO
	touches.clear()
	ada_target = false
	
	if astro:
		lock_on_comp = astro.get_node_or_null("LockOnComponent")
		if lock_on_comp:
			lock_on_comp.setup(astro)

func keluar_state() -> void:
	var sprite_angkasa = astro.get_node_or_null("SpriteAngkasa")
	if sprite_angkasa:
		sprite_angkasa.hide()
		
	var jet = astro.get_node_or_null("SpriteAngkasa/JetThruster")
	if jet:
		jet.emitting = false
		
	if lock_on_comp:
		lock_on_comp.buka_lock()

func kendalikan_input(event: InputEvent) -> void:
	if not astro or not astro.get_meta("local", false):
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			
			if lock_on_comp:
				lock_on_comp.periksa_sentuhan(event.position)
			
			if joystick_id == -1:
				joystick_id = event.index
				joystick_active = true
				joystick_center = event.position
				joystick_dir = Vector2.ZERO
				
				# CLICK TO MOVE: tekan = terbang ke titik yang ditekan
				# (dimatikan semasa mod bina supaya klik digunakan untuk letak bangunan)
				if click_to_move and not mod_bina_aktif():
					pos_target = _skrin_ke_dunia(event.position)
					ada_target = true
		else:
			touches.erase(event.index)
			if event.index == joystick_id:
				joystick_id = -1
				joystick_active = false
				joystick_dir = Vector2.ZERO

	if event is InputEventScreenDrag:
		touches[event.index] = event.position

		if event.index == joystick_id:
			var delta: Vector2 = event.position - joystick_center
			if delta.length() > joystick_range:
				delta = delta.limit_length(joystick_range)
			var normalized: Vector2 = delta / joystick_range
			if normalized.length() < deadzone:
				joystick_dir = Vector2.ZERO
			else:
				joystick_dir = normalized
				ada_target = false # joystick ambil alih kawalan

func mod_bina_aktif() -> bool:
	return (is_instance_valid(BuildManager) and BuildManager.mod_pembinaan) or BuildGrid.mod_aktif

func _skrin_ke_dunia(pos_skrin: Vector2) -> Vector2:
	# Tukar posisi skrin (klik) kepada posisi dunia (ikut kamera)
	return astro.get_viewport().get_canvas_transform().affine_inverse() * pos_skrin

func kemas_kini_fizik(delta: float) -> void:
	if not astro or not astro.get_meta("local", false):
		if astro:
			astro.global_position = astro.global_position.lerp(astro.target_pos, 15.0 * delta)
		return

	# Mod bina sedang aktif: player berhenti sepenuhnya (tak gerak / tak pusing)
	if mod_bina_aktif():
		ada_target = false
		joystick_dir = Vector2.ZERO
		astro.velocity = Vector2.ZERO
		var jet_bina = astro.get_node_or_null("SpriteAngkasa/JetThruster")
		if jet_bina:
			jet_bina.emitting = false
		return

	var sprite_angkasa = astro.get_node_or_null("SpriteAngkasa")
	var current_max_speed = max_speed

	# WASD papan kekunci + joystick sentuh (sentuhan diutamakan)
	var arah: Vector2 = arah_gabungan(joystick_dir)
	if arah != joystick_dir:
		ada_target = false # WASD batalkan click-to-move

	# CLICK TO MOVE: jika joystick tak disentuh, terbang ke titik yang diklik
	if arah.length() == 0.0 and ada_target:
		var ke_target: Vector2 = pos_target - astro.global_position
		var jarak: float = ke_target.length()
		if jarak <= jarak_berhenti:
			ada_target = false # dah sampai
		else:
			arah = ke_target / jarak
			# Perlahan sedikit bila hampir sampai supaya tak terlebih laju (inersia)
			current_max_speed *= clampf(jarak / maxf(jarak_perlahan, 1.0), 0.25, 1.0)

	# 1. HADKAN PANJANG VEKTOR JOYSTICK (Maksimum 1.0 supaya penjuru tidak melimpah laju)
	var input_terhad = arah.limit_length(1.0)

	# TENAGA: bergerak memakai tenaga, habis tenaga = tak boleh bergerak
	var komponen_tenaga = astro.get_node_or_null("EnergyComponent")
	if komponen_tenaga:
		if input_terhad.length() > 0.0:
			if komponen_tenaga.ada_tenaga():
				komponen_tenaga.guna_gerak(delta)
			else:
				input_terhad = Vector2.ZERO

	# 2. LOGIK KELAJUAN UNDUR (REVERSE SPEED)
	if input_terhad.length() > 0:
		if lock_on_comp and lock_on_comp.is_locked and is_instance_valid(lock_on_comp.target_mob):
			# JIKA LOCK-ON AKTIF: Undur dikira menjauhi sasaran musuh
			var arah_ke_musuh = (lock_on_comp.target_mob.global_position - astro.global_position).normalized()
			
			# Dot product < -0.2 bermaksud joystick ditarik berlawanan arah dengan musuh (undur)
			if input_terhad.dot(arah_ke_musuh) < -0.2:
				current_max_speed = max_speed * reverse_speed_multiplier
		else:
			# JIKA TIADA LOCK-ON: Undur dikira berdasarkan arah muncung sprite semasa
			if sprite_angkasa:
				var rad_offset = deg_to_rad(sprite_direction_offset)
				var arah_depan = Vector2.UP.rotated(sprite_angkasa.rotation - rad_offset)
				if input_terhad.dot(arah_depan) < -0.2:
					current_max_speed = max_speed * reverse_speed_multiplier

	# 3. KIRA DAN JALANKAN PERGERAKAN FIZIK
	velocity_target = input_terhad * current_max_speed
	astro.velocity = astro.velocity.lerp(velocity_target, acceleration * delta)
	astro.move_and_slide()

	# --- LOGIK VISUAL & ROTASI ---
	var jet_thruster = astro.get_node_or_null("SpriteAngkasa/JetThruster")
	var collision = astro.get_node_or_null("CollisionShape2D")

	if input_terhad.length() > 0:
		if jet_thruster and not jet_thruster.emitting:
			jet_thruster.emitting = true
	else:
		if jet_thruster and jet_thruster.emitting:
			jet_thruster.emitting = false

	if sprite_angkasa and lock_on_comp:
		var data_lock = lock_on_comp.dapatkan_sudut_pandangan(input_terhad)
		
		if data_lock.has_target:
			var final_target_angle: float = data_lock.angle + deg_to_rad(sprite_direction_offset)
			sprite_angkasa.rotation = lerp_angle(sprite_angkasa.rotation, final_target_angle, rotation_speed * delta)
			if collision:
				collision.rotation = sprite_angkasa.rotation
