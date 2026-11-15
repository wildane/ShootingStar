extends Control

func _ready():
	# Sambungkan isyarat klik butang secara manual tanpa heret nod di editor
	if has_node("LoginButton"):
		$LoginButton.pressed.connect(_on_login_button_pressed)
		print("Sistem UI: Butang sedia digunakan.")
	else:
		print("Ralat: Sila pastikan anda mempunyai nod bernama 'LoginButton'!")

func _on_login_button_pressed():
	print("UI: Butang ditekan! Memulai arahan sambungan...")
	# Terus arahkan NetworkManager untuk membuka talian soket
	NetworkManager.sambung_realtime()
