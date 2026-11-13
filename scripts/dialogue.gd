extends CanvasLayer

# Prototype conversation, available anywhere on the test arena; no NPC or journal yet.
signal assignment_received
const LINES: Array[String] = [
	"Нужно исследовать заброшенную станцию недалеко от поселения.",
	"В руинах остаются монстры. Отправляйтесь туда командой и будьте осторожны.",
	"Осмотрите станцию и выясните, что там сохранилось.",
]
var active := false
var line_index := 0
var assignment_accepted := false
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var panel: PanelContainer
var line: Label
var next_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	panel = PanelContainer.new()
	screen.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 36
	panel.offset_right = -36
	panel.offset_top = -235
	panel.offset_bottom = -30
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Поручение · диалог (прототип)"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	line = Label.new()
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.add_theme_font_size_override("font_size", 22)
	column.add_child(line)
	var hint := Label.new()
	hint.text = "Enter — следующая реплика · Esc — выйти · Бой приостановлен"
	column.add_child(hint)
	next_button = Button.new()
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(advance)
	column.add_child(next_button)
	panel.hide()

func begin() -> void:
	if active or get_tree().paused:
		return
	active = true
	line_index = 0
	previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	panel.show()
	show_line()

func show_line() -> void:
	line.text = "%d / %d · %s" % [line_index + 1, LINES.size(), LINES[line_index]]
	next_button.text = "Далее" if line_index < LINES.size() - 1 else ("Завершить" if assignment_accepted else "Принять поручение")

func advance() -> void:
	if not active:
		return
	if line_index < LINES.size() - 1:
		line_index += 1
		show_line()
		return
	if not assignment_accepted:
		assignment_accepted = true
		assignment_received.emit()
	finish()

func finish() -> void:
	active = false
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = previous_mouse_mode

func _input(event: InputEvent) -> void:
	if not active:
		return
	# Consume every gameplay event, including the event that closes the modal.
	# Mouse clicks reach GUI buttons, but never player._unhandled_input.
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if event.is_echo():
		return
	if event.is_action_pressed("dialogue_next"):
		advance()
	elif event.is_action_pressed("release_mouse"):
		finish()
