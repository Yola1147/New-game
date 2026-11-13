extends "res://tests/station.gd"

func snapshot(view: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/issue9-%s.png" % view)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var player = world.player
	var enemy = world.enemy
	var puzzle = world.puzzle
	player.input_enabled = false
	enemy.set_physics_process(false)
	await frames(90)
	player.position = Vector3(-2, 0, -2.5)
	player.visual.rotation.y = 0
	await frames(2)
	check(not puzzle.opened and not puzzle.gate.get_child(0).disabled, "Door starts closed with collision")
	await snapshot("closed")
	player.switch_character()
	check(player.use_ability() and not puzzle.opened, "Finisher first must leave mechanism retryable")
	player.switch_character()
	check(player.use_ability() and puzzle.mark_time > 0, "Existing mark ability must reach mechanism")
	check(not player.use_ability(), "Repeated E must respect ability cooldown")
	await snapshot("marked")
	var mark_before: float = puzzle.mark_time
	world.dialogue.begin()
	for code in [KEY_Q, KEY_E, KEY_T, KEY_R]:
		key(code)
	for i in range(30):
		await process_frame
	check(puzzle.mark_time == mark_before and not puzzle.opened, "Dialogue pauses puzzle timer and blocks gameplay input")
	world.dialogue.finish()
	await frames(370)
	check(puzzle.mark_time == 0, "Mechanism mark must expire naturally")
	player.switch_character()
	check(player.use_ability() and not puzzle.opened, "Expired mark must not open door")
	await frames(370)
	player.switch_character()
	# Both abilities obey the same facing, height, range and occlusion as combat.
	player.visual.rotation.y = PI
	player.use_ability()
	check(puzzle.mark_time == 0, "Mechanism behind hero must not activate")
	world.restart_battle()
	player.position = Vector3(-2, 0, 3)
	player.visual.rotation.y = 0
	player.use_ability()
	check(puzzle.mark_time == 0, "Mark outside 6m must miss")
	world.restart_battle()
	player.position = Vector3(-2, 0, -8)
	player.visual.rotation.y = PI
	player.use_ability()
	check(puzzle.mark_time == 0, "Sealed door must block ability from rear room")
	world.restart_battle()
	player.position = Vector3(-2, 3, -2.5)
	player.visual.rotation.y = 0
	player.use_ability()
	check(puzzle.mark_time == 0, "Height limit applies to mechanism")
	world.restart_battle()
	player.position = Vector3(-2, 0, -2.5)
	player.visual.rotation.y = 0
	player.take_damage(100)
	check(not player.use_ability() and puzzle.mark_time == 0, "Dead hero cannot activate mechanism")
	world.restart_battle()
	player.position = Vector3(-2, 0, -2.5)
	player.visual.rotation.y = 0
	await frames(2)
	if DisplayServer.get_name() != "headless":
		player.input_enabled = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		key(KEY_E)
		key(KEY_Q)
		key(KEY_E)
	else:
		player.use_ability()
		player.switch_character()
		player.use_ability()
	check(puzzle.opened, "Mark then switched hero finisher (real E/Q/E with graphics) must open door")
	await frames(2)
	check(not puzzle.gate.visible and puzzle.gate.get_child(0).disabled, "Open door must remove both mesh and collision")
	await snapshot("opened")
	player.input_enabled = true
	player.pivot.rotation.y = 0
	await walk(player, Vector3(-2, 0, -9))
	await walk(player, Vector3(-2, 0, -2.5))
	puzzle.activate(0)
	puzzle.activate(1)
	check(puzzle.opened, "Repeated activation must keep door open")
	# The guard must also use the newly opened central route.
	player.input_enabled = false
	player.position = Vector3(0, 0, -9)
	enemy.position = Vector3(0, 0, -3)
	enemy.set_physics_process(true)
	await frames(130)
	check(enemy.position.z < -6, "Guard must rebuild navigation and cross opened doorway")
	world.restart_battle()
	await frames(2)
	check(puzzle.opened and puzzle.gate.get_child(0).disabled, "R preserves opened passage")
	world.restart_quest()
	await frames(2)
	check(not puzzle.opened and puzzle.mark_time == 0 and not puzzle.gate.get_child(0).disabled, "T resets door and mark without leaving hero trapped")
	check(player.position.z > 7, "Full reset returns hero to entrance")
	player.position = Vector3(-2, 0, -2.5)
	player.visual.rotation.y = 0
	player.use_ability()
	player.switch_character()
	player.use_ability()
	check(puzzle.opened, "Puzzle must be solvable again after full reset")
	print("PUZZLE RESULT: ", failures, " failures (order, expiry, retry, restrictions, collision, walk, navigation, resets)")
	quit(1 if failures else 0)
