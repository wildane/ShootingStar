# ==========================================================
# FAIL: inventory_manager.gd (Versi Paksa Integer / Anti-Float + Auto-Save)
# ==========================================================
extends Node

signal inventory_dikemaskini

var senarai_barang : Array = []

# Kira berapa banyak satu item ada dalam beg (0 jika tiada)
func bilangan_item(id_barang: String) -> int:
	for barang in senarai_barang:
		if barang.get("id") == id_barang:
			return int(barang.get("kuantiti", 0))
	return 0

func tambah_item(data_barang: Dictionary, senyap: bool = false) -> bool:
	# 1. SEMAK JIKA BARANG SUDAH WUJUD
	for barang in senarai_barang:
		if barang.get("id") == data_barang.get("id"):
			# 🔥 DIPERBAIKI: Paksa guna int() supaya nilai dikunci sebagai nombor bulat
			var kuantiti_semasa = int(barang.get("kuantiti", 1))
			barang["kuantiti"] = kuantiti_semasa + 1
			
			# senyap = true: UI dan fail simpanan dikemas kini sekali sahaja di
			# hujung (lihat kemas_kini_selepas_batch), bukan setiap item.
			if not senyap:
				inventory_dikemaskini.emit()
				print("Sistem Stacking: Kuantiti ", barang.get("nama"), " bertambah menjadi ", barang["kuantiti"])
			return true
            
	# 2. JIKA BARANG BARU (BELUM ADA DALAM SLOT)
	# 🔥 DIPERBAIKI: Jika data yang dihantar ada float, kita paksa tukar jadi int dulu
	if data_barang.has("kuantiti"):
		data_barang["kuantiti"] = int(data_barang["kuantiti"])
	else:
		data_barang["kuantiti"] = 1
		
	senarai_barang.append(data_barang)
	if not senyap:
		inventory_dikemaskini.emit()
		print("Sistem: Barang baru dimasukkan ke slot kosong: ", data_barang.get("nama"))
	return true


# Kemas kini UI sekali sahaja selepas banyak tambah_item(senyap = true).
# Tanpa ini, menambah puluhan item serentak membina semula grid berpuluh kali
# (punca fps drop). Simpanan dibuat oleh autosave/manual save sahaja.
func kemas_kini_selepas_batch() -> void:
	inventory_dikemaskini.emit()

func tolak_item(id_barang: String, kuantiti_ditolak: int) -> bool:
	# 1. GUNAKAN GELUNG KE BELAKANG (REVERSE LOOP) UNTUK PEMADAMAN SELAMAT
	for i in range(senarai_barang.size() - 1, -1, -1):
		var barang = senarai_barang[i]
		if barang.get("id") == id_barang:
			# 🔥 DIPERBAIKI: Paksa guna int() untuk operasi penolakan
			var kuantiti_semasa = int(barang.get("kuantiti", 0))
			
			if kuantiti_semasa >= kuantiti_ditolak:
				barang["kuantiti"] = kuantiti_semasa - int(kuantiti_ditolak)
				print("InventoryManager: ", barang.get("nama"), " ditolak ", kuantiti_ditolak, ". Baki: ", barang["kuantiti"])
				
				# 2. JIKA BARANG HABIS (0), BUANG SLOT TERSEBUT DARI ARRAY
				if barang["kuantiti"] <= 0:
					print("InventoryManager: Slot ", barang.get("nama"), " dikosongkan.")
					senarai_barang.remove_at(i)
				
				inventory_dikemaskini.emit()
				return true
			else:
				print("InventoryManager: Kuantiti tidak cukup untuk ditolak!")
				return false
				
	print("InventoryManager: Ralat! ID ", id_barang, " tiada dalam inventori.")
	return false
