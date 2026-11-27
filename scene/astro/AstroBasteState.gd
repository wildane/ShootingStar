extends AstroAntaramuka
class_name AstroBaseState

# ==========================================================
# EXPORTS (BOLEH LARAS DI INSPECTOR BASESTATE)
# ==========================================================
@export_group("Fizik Pangkalan (Base)")
@export var max_speed: float = 120.0          
@export var rotation_speed: float = 12.0      
@export var sprite_direction_offset: float = -90.0 

@export_group("Tetapan Joystick")
@export var joystick_range: float = 60.0     
@export var deadzone: float = 0.1            

@export_group("Klik Untuk Gerak (Click To Move)")
@export var click_to_move: bool = true
@export var jarak_berhenti: float = 6.0

@export_group("Bunyi Langkah")
# Jarak (piksel) yang perlu dilalui sebelum satu bunyi langkah dimainkan.
@export var jarak_langkah: float = 16.0
@export var isipadu_langkah: float = -16.0

# ==========================================================
# INTERNAL VARIABLES
# ==========================================================
var joystick_active: bool = false
var joystick_id: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var joystick_dir: Vector2 = Vector2.ZERO

var touches: Dictionary = {}

# Klik/tap = gerak ke titik itu (dibatalkan bila joystick digerakkan)
var ada_target: bool = false
var pos_target: Vector2 = Vector2.ZERO

var lock_on_comp: LockOnComponent = null

# Jarak terkumpul sejak bunyi langkah terakhir.
var _jarak_langkah: float = 0.0

func masuk_state() -> void:
	print("-> Mengaktifkan Visual BaseState (Guna Sentuhan Tepat Komponen)")
	
	var sprite_base = astro.get_node_or_null("SpriteBase")
	if sprite_base:
		sprite_base.show()

	var sprite_angkasa = astro.get_node_or_null("SpriteAngkasa")
	if sprite_angkasa:
		sprite_angkasa.hide()
	# Matikan jet terus semasa masuk asteroid, supaya tiada api tertinggal
	# di tempat pemain memasuki asteroid.
	set_jet_aktif(false)

	
	joystick_active = false
	joystick_id = -1
	joystick_dir = Vector2.ZERO
	touches.clear()
	ada_target = false

	# Sambung semula jari yang masih menekan skrin dan sasaran click-to-move
	# dari state sebelumnya, supaya player terus berjalan selepas masuk asteroid.
	var warisan := warisi_kawalan_sentuh(joystick_range, deadzone)
	touches = warisan["sentuhan"]
	joystick_active = warisan["ada"]
	joystick_id = warisan["id"]
	joystick_center = warisan["pusat"]
	joystick_dir = warisan["arah"]
	if warisan["sasaran_ada"] and joystick_dir.length() == 0.0 and astro:
		pos_target = warisan["sasaran_pos"]
		ada_target = astro.global_position.distance_to(pos_target) > jarak_berhenti
	
	if astro:
		astro.velocity = Vector2.ZERO
		lock_on_comp = astro.get_node_or_null("LockOnComponent")
		if lock_on_comp:
			lock_on_comp.setup(astro)

func keluar_state() -> void:
	var sprite_base = astro.get_node_or_null("SpriteBase")
	if sprite_base:
		sprite_base.hide()
	touches.clear()
	_jarak_langkah = 0.0
	
	if lock_on_comp:
		lock_on_comp.buka_lock()

func kendalikan_input(event: InputEvent) -> void:
	if not astro or not astro.get_meta("local", false):
		return

	if event is InputEventScreenTouch:
		# Sentuhan yang dibatalkan sistem (touchcancel pelayar) dikira lepas jari.
		if event.pressed and not event.canceled:
			touches[event.index] = event.position
			
			if lock_on_comp:
				lock_on_comp.periksa_sentuhan(event.position)
			
			if joystick_id == -1:
				joystick_id = event.index
				joystick_active = true
				joystick_center = event.position
				joystick_dir = Vector2.ZERO
				
				# CLICK TO MOVE: tekan = jalan ke titik yang ditekan
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
		# Abaikan drag untuk jari yang tiada rekod tekan (jari hantu selepas
		# menu dibuka/ditutup): joystick tidak boleh bergerak sendiri.
		if not touches.has(event.index):
			return
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

# Buang semua state sentuhan: dipanggil bila menu dibuka/ditutup atau bila
# cubitan zoom dua jari bermula, supaya joystick dan click-to-move berhenti.
func kosongkan_kawalan_sentuh() -> void:
	touches.clear()
	joystick_active = false
	joystick_id = -1
	joystick_center = Vector2.ZERO
	joystick_dir = Vector2.ZERO
	ada_target = false
	if astro:
		astro.velocity = Vector2.ZERO

func mod_bina_aktif() -> bool:
	return (is_instance_valid(BuildManager) and BuildManager.mod_pembinaan) or BuildGrid.mod_aktif

# Bunyi langkah diulang setiap `jarak_langkah` piksel yang dilalui. Jenis
# bunyi ikut lantai di bawah pemain: logam untuk lantai yang dibina, batu
# untuk permukaan asteroid.
func _bunyi_langkah(delta: float) -> void:
	var laju: float = astro.velocity.length()
	if laju < 5.0:
		_jarak_langkah = 0.0
		return
	_jarak_langkah += laju * delta
	if _jarak_langkah < jarak_langkah:
		return
	_jarak_langkah = 0.0
	var nama: String = "langkah_batu"
	var grid := get_tree().get_first_node_in_group("BuildGrid") as BuildGrid
	if grid != null and grid.jenis_tile_di(astro.global_position) == BuildGrid.JENIS_LANTAI:
		nama = "langkah_logam"
	Sfx.mainkan(nama, isipadu_langkah)

func _skrin_ke_dunia(pos_skrin: Vector2) -> Vector2:
	# Tukar posisi skrin (klik) kepada posisi dunia (ikut kamera)
	return astro.get_viewport().get_canvas_transform().affine_inverse() * pos_skrin

func kemas_kini_fizik(delta: float) -> void:
	if not astro or not astro.get_meta("local", false):
		return

	# Mod bina sedang aktif: player berhenti sepenuhnya (tak gerak / tak pusing)
	if mod_bina_aktif():
		ada_target = false
		joystick_dir = Vector2.ZERO
		astro.velocity = Vector2.ZERO
		_jarak_langkah = 0.0
		return

	# WASD papan kekunci + joystick sentuh (sentuhan diutamakan)
	var arah: Vector2 = arah_gabungan(joystick_dir)
	if arah != joystick_dir:
		ada_target = false # WASD batalkan click-to-move

	# CLICK TO MOVE: jika joystick tak disentuh, jalan ke titik yang diklik
	if arah.length() == 0.0 and ada_target:
		var ke_target: Vector2 = pos_target - astro.global_position
		if ke_target.length() <= jarak_berhenti:
			ada_target = false # dah sampai
		else:
			arah = ke_target.normalized()

	astro.velocity = arah * max_speed
	astro.move_and_slide()
	_bunyi_langkah(delta)

	var sprite_base = astro.get_node_or_null("SpriteBase")
	var collision = astro.get_node_or_null("CollisionShape2D")

	if sprite_base and lock_on_comp:
		var data_lock = lock_on_comp.dapatkan_sudut_pandangan(arah)
		
		if data_lock.has_target:
			var final_target_angle: float = data_lock.angle + deg_to_rad(sprite_direction_offset)
			sprite_base.rotation = lerp_angle(sprite_base.rotation, final_target_angle, rotation_speed * delta)
			if collision:
				collision.rotation = sprite_base.rotation
