extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

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

func accept_dialogue() -> void:
	key(KEY_F)
	for i in range(3):
		key(KEY_ENTER)

func run() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	for i in range(5):
		await process_frame
	var quest = arena.quest
	var player = arena.player
	var enemy = arena.enemy
	player.position = arena.STATION_POINT
	key(KEY_G)
	enemy.take_damage(100)
	await process_frame
	check(quest.stage == quest.Stage.NOT_STARTED and quest.rewards == 0, "Pre-quest kill/inspection cannot complete quest")
	key(KEY_F)
	key(KEY_ESCAPE)
	check(quest.stage == quest.Stage.NOT_STARTED, "Cancelled dialogue cannot accept quest")
	# An early kill remains valid after acceptance; do not strand the player.
	accept_dialogue()
	check(quest.stage == quest.Stage.DEFEAT_GUARD, "Only accepted dialogue starts first objective")
	await process_frame
	check(quest.stage == quest.Stage.INSPECT_STATION, "Defeated guard advances accepted objective")
	key(KEY_R)
	check(quest.stage == quest.Stage.INSPECT_STATION and arena.dialogue.assignment_accepted, "R preserves quest")
	player.position = arena.STATION_POINT
	key(KEY_G)
	check(quest.rewards == 0, "Respawned live guard blocks inspection")
	enemy.take_damage(100)
	player.position = Vector3(0, 0, 8)
	key(KEY_G)
	check(quest.rewards == 0, "Distant inspection must fail")
	player.position = arena.STATION_POINT + Vector3.UP * 5
	key(KEY_G)
	check(quest.rewards == 0, "Inspection requires proximity in height too")
	player.position = arena.STATION_POINT
	player.take_damage(100)
	key(KEY_G)
	check(quest.rewards == 0, "Dead active hero cannot inspect")
	key(KEY_Q)
	key(KEY_F)
	key(KEY_G)
	key(KEY_T)
	check(quest.stage == quest.Stage.INSPECT_STATION and quest.rewards == 0, "Dialogue blocks inspection and full reset")
	key(KEY_ESCAPE)
	key(KEY_G, true)
	check(quest.rewards == 0, "Key repeat cannot inspect")
	key(KEY_G)
	check(quest.stage == quest.Stage.COMPLETED and quest.rewards == 1, "Living nearby hero completes quest and receives one reward")
	check(arena.assignment_status.text.contains("Поручение выполнено"), "Journal displays completion")
	for i in range(3):
		key(KEY_G)
		accept_dialogue()
	key(KEY_R)
	check(quest.rewards == 1 and quest.stage == quest.Stage.COMPLETED, "Repeated inspection/dialogue/combat reset cannot duplicate reward")
	key(KEY_T)
	check(quest.stage == quest.Stage.NOT_STARTED and quest.rewards == 0 and not arena.dialogue.assignment_accepted, "T resets quest, reward and dialogue acceptance")
	check(enemy.health == 100 and player.health == 100 and player.active_character == 0, "T resets full battle")
	accept_dialogue()
	key(KEY_G)
	check(quest.stage == quest.Stage.DEFEAT_GUARD and quest.rewards == 0, "New run cannot skip live guard")
	enemy.take_damage(100)
	await process_frame
	player.position = arena.STATION_POINT
	key(KEY_G)
	check(quest.rewards == 1, "Second run can complete exactly once after reset")
	key(KEY_T)
	# Leave a representative in-progress journal visible during graphical runs.
	accept_dialogue()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in range(3):
		await process_frame
	print("QUEST RESULT: ", failures, " failures")
	quit(1 if failures else 0)
