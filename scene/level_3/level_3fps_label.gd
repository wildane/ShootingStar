extends Label

@export_range(6, 72, 1) var font_size: int = 16:
	set(value):
		font_size = value
		add_theme_font_size_override("font_size", font_size)

var _masa_kemas_kini: float = 0.0
const SELA_KEMAS_KINI: float = 0.25

func _ready():
	add_theme_font_size_override("font_size", font_size)

func _process(delta):
	_masa_kemas_kini += delta
	if _masa_kemas_kini < SELA_KEMAS_KINI:
		return
	_masa_kemas_kini = 0.0

	var fps := int(Performance.get_monitor(Performance.TIME_FPS))
	var cpu_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var mem_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	var mem_puncak_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)) / 1048576.0

	text = "FPS: %d\nCPU: %.2f ms\nMem: %.1f / %.1f MB" % [fps, cpu_ms, mem_mb, mem_puncak_mb]
