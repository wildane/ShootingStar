extends SceneTree

# Ujian: threat + pemasa serangan balas disimpan dalam fail slot dan dipulihkan
# semasa load, bukan bergantung pada user://threat.json yang terus berubah.

var lulus: bool = true


func _init() -> void:
	call_deferred("_jalan")


func _semak(syarat: bool, mesej: String) -> void:
	print(("LULUS  " if syarat else "GAGAL  ") + mesej)
	if not syarat:
		lulus = false


func _jalan() -> void:
	var akar := Node2D.new()
	akar.name = "LevelUjian"
	root.add_child(akar)
	current_scene = akar
	var bekas := Node2D.new()
	bekas.name = "Y_Sort_Container"
	akar.add_child(bekas)

	var save_manager: Node = load("res://SaveManager.gd").new()
	akar.add_child(save_manager)

	# 1. Keadaan pada masa simpan: threat 35%, baki 120 saat.
	StorThreat.reset()
	StorThreat.bunuh = 35
	StorThreat.masa_serang = 120.0
	var snapshot: Dictionary = StorThreat.data_simpanan()
	_semak(int(snapshot.get("bunuh", -1)) == 35, "snapshot simpan threat 35%")
	_semak(is_equal_approx(float(snapshot.get("masa", -1.0)), 120.0), "snapshot simpan baki 120 saat")

	# 2. Snapshot masuk ke data simpanan slot.
	var data_simpan: Dictionary = save_manager.call("_kumpul_data_state")
	_semak(data_simpan.has("threat"), "data simpanan ada kunci 'threat'")
	var data_threat: Dictionary = data_simpan.get("threat", {})
	_semak(int(data_threat.get("bunuh", -1)) == 35, "data simpanan simpan threat 35%")
	_semak(is_equal_approx(float(data_threat.get("masa", -1.0)), 120.0), "data simpanan simpan baki 120 saat")

	# 3. Selepas gelombang selesai + bunuhan baru, cakera sudah berubah.
	StorThreat.selesai_gelombang()
	_semak(StorThreat.masa_serang < 0.0, "gelombang selesai: pemasa cakera jadi -1")

	# 4. Load slot lama mesti pulihkan tepat nilai dalam slot.
	StorThreat.pakai_data_simpanan(data_threat)
	_semak(StorThreat.bunuh == 35, "load pulihkan threat 35%")
	_semak(is_equal_approx(StorThreat.masa_serang, 120.0), "load pulihkan baki 120 saat")

	# 5. Nilai dipulihkan juga ditulis ke cakera (sesi seterusnya konsisten).
	var fail := FileAccess.open(StorThreat.LALUAN_SIMPAN, FileAccess.READ)
	_semak(fail != null, "fail threat.json boleh dibaca")
	if fail != null:
		var isi: Variant = JSON.parse_string(fail.get_as_text())
		fail = null
		var d: Dictionary = isi if typeof(isi) == TYPE_DICTIONARY else {}
		_semak(is_equal_approx(float(d.get("masa", -2.0)), 120.0), "cakera ikut nilai slot (120 saat)")
		_semak(int(d.get("bunuh", -1)) == 35, "cakera ikut threat slot (35%)")

	# 6. Simpanan lama tanpa kunci 'threat' tidak memadam nilai semasa.
	StorThreat.pakai_data_simpanan({})
	_semak(is_equal_approx(StorThreat.masa_serang, 120.0), "data kosong tidak ubah pemasa")

	StorThreat.reset()
	print("LULUS=", lulus)
	quit(0 if lulus else 1)
