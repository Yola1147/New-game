extends "res://tests/puzzle.gd"

# Integrated automated route. No teleporting, forced damage or disabled AI.
# This does not replace a user's manual playthrough.
const ROUTE_SLOT := "user://regression-issue15-route.json"

func finale_snapshot(view: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/issue12-%s.png" % view)

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	world.save_path = ROUTE_SLOT
	check(world.SaveGame.clear_slot(ROUTE_SLOT), "Clear isolated route slot")
	root.add_child(world)
	var player = world.player
	await frames(90)
	player.pivot.rotation.y = 0
	key(KEY_F)
	key(KEY_ENTER)
	key(KEY_ESCAPE)
	check(world.quest.rewards == 0 and not world.dialogue.assignment_accepted, "Cancelled assignment leaves no progress")
	key(KEY_F)
	for i in range(3):
		key(KEY_ENTER)
	check(world.dialogue.assignment_accepted, "Dialogue accepts assignment before route")
	key(KEY_G)
	check(not world.memory_echo.active, "Early G cannot discover echo")
	await walk(player, Vector3(0, 0, 1))
	await frames(100)
	for i in range(4):
		check(player.start_attack(), "Hall fight accepts basic attack")
		await frames(35)
	check(world.enemy.health == 0 and player.health > 0, "Live AI fight ends in victory")
	check(world.quest.stage == world.quest.Stage.OPEN_PASSAGE, "Victory advances accepted assignment")
	await walk(player, Vector3(0, 0, -3))
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	check(player.position.z > -5.3, "Closed door blocks route")
	await walk(player, Vector3(0, 0, -2.5))
	await walk(player, Vector3(-2, 0, -2.5))
	# Walking forward also gives both abilities their normal facing.
	await walk(player, Vector3(-2, 0, -3))
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		key(KEY_E)
		key(KEY_Q)
		key(KEY_E)
	else:
		player.use_ability()
		player.switch_character()
		player.use_ability()
	await frames(2)
	check(world.puzzle.opened, "Two abilities open passage after battle")
	await walk(player, Vector3(-2, 0, -9))
	await frames(100)
	await finale_snapshot("reinforced")
	for i in range(7):
		if player.health <= 30 and player.reserve_health > 0:
			player.switch_character()
		player.visual.look_at(Vector3(world.final_enemy.position.x, player.visual.global_position.y, world.final_enemy.position.z))
		check(player.start_attack(), "Final fight accepts basic attack")
		await frames(35)
	check(world.final_enemy.health == 0 and player.health > 0, "Reinforced guard is beatable with live AI")
	await walk(player, world.STATION_POINT)
	key(KEY_G)
	await finale_snapshot("completed")
	check(world.memory_echo.active and world.quest.rewards == 1, "Walked route discovers recording once")
	check(player.blade_owned and player.blade_equipped and player.attack_damage() == 30, "Walked quest grants equipped blade")
	key(KEY_I)
	check(player.blade_owned and not player.blade_equipped and player.attack_damage() == 25, "I removes only the equipment bonus")
	key(KEY_G)
	await walk(player, Vector3(4.75, 0, -10))
	await frames(740)
	check(not world.memory_echo.active, "Recording finishes with movement available")
	key(KEY_G)
	check(world.memory_echo.active and world.quest.rewards == 1, "Replay has no second reward")
	key(KEY_F)
	check(not world.memory_echo.active and paused, "Repeated dialogue stops playback")
	for i in range(3):
		key(KEY_ENTER)
	check(world.quest.rewards == 1, "Repeated assignment preserves single reward")
	# Return through the original bypass to catch one-way traps.
	for point in [Vector3(4.75, 0, -3), Vector3(0, 0, -3), Vector3(0, 0, 8)]:
		await walk(player, point)
	# Save the state earned by real combat and walking, rather than a fixture.
	var completed: Dictionary = world.checkpoint_data()
	key(KEY_F5)
	var saved: Dictionary = world.SaveGame.read_slot(ROUTE_SLOT)
	for field in completed:
		# JSON numbers decode as floats; compare values without Dictionary type equality.
		check(saved.get(field) == completed[field], "F5 persists earned field: " + field)
	key(KEY_I)
	key(KEY_Q)
	key(KEY_R)
	key(KEY_F9)
	check(world.checkpoint_data() == completed, "F9 restores earned state after equipment, hero and battle changes")
	world.queue_free()
	await process_frame
	world = load("res://scenes/main.tscn").instantiate()
	world.save_path = ROUTE_SLOT
	world.persistence_enabled = true
	root.add_child(world)
	player = world.player
	await frames(90)
	check(world.save_status.text.begins_with("Загружено") and world.checkpoint_data() == completed, "Fresh scene automatically restores earned checkpoint")
	check(player.position.distance_to(Vector3(0, 0, 8)) < 0.2 and not world.memory_echo.active, "Load returns to entrance without playing recording")
	await finale_snapshot("loaded")
	for point in [Vector3(0, 0, -3), Vector3(0, 0, -9), world.STATION_POINT]:
		await walk(player, point)
	key(KEY_G)
	check(world.memory_echo.active and world.quest.rewards == 1 and not player.blade_equipped, "Loaded completion replays echo without reward or re-equipping")
	key(KEY_R)
	await frames(2)
	check(world.puzzle.opened and world.quest.rewards == 1 and not world.memory_echo.active, "R preserves door and finding")
	key(KEY_T)
	await frames(2)
	check(not world.puzzle.opened and not world.puzzle.gate.get_child(0).disabled, "T restores closed door collision")
	check(world.quest.stage == world.quest.Stage.NOT_STARTED and world.quest.rewards == 0, "T clears quest and reward")
	check(not world.dialogue.assignment_accepted and player.position.z > 7, "T restores entrance and assignment")
	check(not FileAccess.file_exists(ROUTE_SLOT), "T deletes isolated route checkpoint")
	print("STATION PLAYTHROUGH RESULT: ", failures, " failures (assignment, fights, puzzle, echo, equipment, F5/F9, scene reload, return, R/T)")
	quit(1 if failures else 0)
