extends SceneTree

var failures := 0
var assignments := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(5)
	var player = arena.player
	var enemy = arena.enemy
	var dialogue = arena.dialogue
	dialogue.assignment_received.connect(func() -> void: assignments += 1)
	player.position = Vector3(0, 0, 5)
	enemy.position = Vector3(0, 0, 3.3)
	player.start_attack()
	enemy.windup = 0.3
	player.ability_cooldowns[0] = 3.0
	var attack_before: float = player.attack_time
	var position_before: Vector3 = player.position
	key(KEY_F)
	check(dialogue.active and paused and dialogue.line_index == 0, "F must start paused dialogue at first line")
	check(dialogue.line.text.contains(dialogue.LINES[0]), "First line must be displayed")
	key(KEY_ENTER, true)
	check(dialogue.line_index == 0, "Key repeat must not skip lines")
	for code in [KEY_W, KEY_SPACE, KEY_Q, KEY_E, KEY_R, KEY_F]:
		key(code)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(5, 5)
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(150, 100)
	var camera_before: float = player.pivot.rotation.y
	Input.parse_input_event(motion)
	await frames(45)
	check(player.position == position_before and player.pivot.rotation.y == camera_before, "Dialogue must block movement, jump and camera")
	check(player.attack_time == attack_before and enemy.windup == 0.3, "Pending attacks must pause")
	check(player.ability_cooldowns[0] == 3.0 and player.active_character == 0, "Dialogue must block E/Q and freeze cooldowns")
	check(player.health == 100 and enemy.health == 100, "Dialogue must prevent combat damage and R")
	key(KEY_ENTER)
	check(dialogue.line_index == 1 and not dialogue.assignment_accepted, "Enter must advance exactly one line without early assignment")
	key(KEY_ESCAPE)
	check(not dialogue.active and not paused and assignments == 0, "Esc must cancel without giving assignment")
	# Resume existing combat state, without any reset or immediate extra input.
	check(player.attack_time == attack_before and player.active_character == 0, "Closing must preserve combat state")
	key(KEY_F)
	check(dialogue.line_index == 0, "Cancelled conversation must restart in order")
	key(KEY_ENTER)
	key(KEY_ENTER)
	check(dialogue.line_index == 2 and dialogue.line.text.contains(dialogue.LINES[2]), "Last line must be visible before acceptance")
	check(assignments == 0, "Reading final line alone must not issue assignment")
	key(KEY_ENTER)
	check(not paused and not dialogue.active and assignments == 1, "Final confirmation must issue assignment once and resume")
	check(arena.assignment_status.text.contains("Поручение получено"), "HUD must confirm assignment")
	key(KEY_F)
	key(KEY_ENTER)
	key(KEY_ENTER)
	key(KEY_ENTER)
	check(assignments == 1, "Replay must not issue assignment twice")
	key(KEY_R)
	check(dialogue.assignment_accepted and assignments == 1 and enemy.windup == 0, "Battle reset must preserve assignment and clear attacks")
	# Cursor restoration matters only on a graphical display server.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	key(KEY_F)
	key(KEY_ESCAPE)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc must restore a previously free cursor")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		key(KEY_F)
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Dialogue must release captured cursor")
		key(KEY_ENTER)
		key(KEY_ENTER)
		# Exercise final acceptance through GUI click, not a direct signal call.
		await frames(2)
		click.position = dialogue.next_button.get_global_rect().get_center()
		click.pressed = true
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		click = click.duplicate()
		click.pressed = false
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		check(not dialogue.active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "GUI completion must restore captured cursor")
		check(player.attack_time == 0, "Closing button click must not trigger an attack")
	else:
		print("Cursor capture and GUI final click: run dialogue.gd with graphics")
	print("DIALOGUE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
