extends CanvasLayer

# Text playback and primitive device are prototypes, not new world rules.
const LINES: Array[String] = [
	"Журнал наблюдений. Работа на станции приостановлена.",
	"Часть записей удалось сохранить. Остальные материалы требуют проверки.",
	"Если кто-нибудь найдёт эту запись, осмотрите уцелевшее оборудование. Конец записи.",
]
const LINE_SECONDS := 4.0
var active := false
var line_index := 0
var remaining := 0.0
var panel: PanelContainer
var text: Label

func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	panel = PanelContainer.new()
	screen.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -550
	panel.offset_right = -24
	panel.offset_top = -120
	panel.offset_bottom = 150
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 21)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(text)
	stop()

func play() -> void:
	if active:
		return
	active = true
	line_index = 0
	remaining = LINE_SECONDS
	show_line()
	panel.show()

func show_line() -> void:
	text.text = "Эхо памяти · прототип\nНеизвестные исследователи · %d / %d\n%s\nЗапись идёт автоматически · управление доступно" % [line_index + 1, LINES.size(), LINES[line_index]]

func _process(delta: float) -> void:
	if not active:
		return
	remaining -= delta
	while active and remaining <= 0:
		line_index += 1
		if line_index >= LINES.size():
			stop()
		else:
			remaining += LINE_SECONDS
			show_line()

func stop() -> void:
	active = false
	remaining = 0
	panel.hide()
