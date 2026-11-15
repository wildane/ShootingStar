extends Area2D

@onready var health_component = get_parent().get_node("HealthComponent")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node2D) -> void:
	_semak_dan_serang(body)

func _on_area_entered(area: Area2D) -> void:
	_semak_dan_serang(area)

func _semak_dan_serang(target: Node2D) -> void:
	if target.name == "Player" or target.is_in_group("Player") or target.name == "SpaceShip":
		# Kod lama health_component.take_damage(1.0) dibuang.
		pass
