extends Label

@export_range(6, 72, 1) var font_size: int = 16:
	set(value):
		font_size = value
		add_theme_font_size_override("font_size", font_size)

func _ready():
	add_theme_font_size_override("font_size", font_size)

func _process(_delta):
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	text = "FPS: %d" % fps
