extends "res://tests/quest.gd"

func capture(view: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/issue10-%s.png" % view)

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	for i in range(5):
		await physics_frame
	var player = world.player
	var echo = world.memory_echo
	player.position = world.STATION_POINT
	key(KEY_G)
	check(not echo.active, "No recording before assignment and battle")
	accept_dialogue()
	key(KEY_G)
	check(not echo.active, "Live guard blocks finding")
	world.enemy.take_damage(100)
	clear_final_guard(world)
	await process_frame
	await process_frame
	player.position = Vector3(0, 0, 8)
	key(KEY_G)
	check(not echo.active, "Remote interaction cannot play recording")
	player.position = world.STATION_POINT + Vector3.UP * 5
	key(KEY_G)
	check(not echo.active, "Height limits interaction")
	player.position = world.STATION_POINT
	player.take_damage(100)
	key(KEY_G)
	check(not echo.active, "Dead hero cannot discover recording")
	key(KEY_Q)
	key(KEY_G, true)
	check(not echo.active, "Keyboard repeat cannot trigger recording")
	var mouse_before := Input.mouse_mode
	key(KEY_G)
	check(echo.active and echo.panel.visible and echo.line_index == 0, "G discovers device and starts first line")
	check(world.quest.rewards == 1 and world.quest.stage == world.quest.Stage.COMPLETED, "Finding updates quest exactly once")
	check(not paused and Input.mouse_mode == mouse_before, "Playback preserves pause and cursor state")
	await capture("playback")
	# G spam must neither restart the current line nor duplicate rewards.
	echo.remaining = 2.0
	key(KEY_G)
	check(echo.remaining == 2.0 and world.quest.rewards == 1, "Repeated G cannot restart active recording or reward")
	Input.action_press("move_left")
	var start: Vector3 = player.position
	for i in range(30):
		await physics_frame
	Input.action_release("move_left")
	check(player.position.distance_to(start) > 1.0 and echo.active, "Movement continues during playback")
	if DisplayServer.get_name() != "headless":
		# Revive the reserve killed by the earlier negative interaction scenario.
		player.reserve_health = 100
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		key(KEY_Q)
		check(player.active_character == 0, "Real Q input works during playback")
		key(KEY_E)
		check(player.ability_cooldowns[0] > 0, "Real E input works during playback")
	# Observe the final line, then let playback finish using the frame loop.
	await create_timer(6.0).timeout
	check(echo.active and echo.line_index == 2, "Playback reaches the final line in order")
	await capture("last-line")
	await create_timer(4.5).timeout
	check(not echo.active and not echo.panel.visible and not paused, "Recording automatically ends without locking gameplay")
	await capture("finished")
	player.position = world.STATION_POINT
	key(KEY_G)
	check(echo.active and echo.line_index == 0 and world.quest.rewards == 1, "Completed recording can replay without another reward")
	key(KEY_F)
	check(world.dialogue.active and not echo.active, "Assignment conversation stops recording to prevent overlapping text")
	key(KEY_G)
	check(not echo.active, "Modal conversation blocks playback")
	key(KEY_ESCAPE)
	key(KEY_G)
	key(KEY_R)
	check(not echo.active and world.quest.rewards == 1, "R stops playback and preserves finding")
	world.enemy.take_damage(100)
	clear_final_guard(world)
	player.position = world.STATION_POINT
	key(KEY_G)
	key(KEY_T)
	check(not echo.active and world.quest.rewards == 0 and world.quest.stage == world.quest.Stage.NOT_STARTED, "T clears playback and quest")
	# Repeat after full reset and verify the finding can be awarded once again.
	accept_dialogue()
	world.enemy.take_damage(100)
	clear_final_guard(world)
	await process_frame
	await process_frame
	player.position = world.STATION_POINT
	key(KEY_G)
	check(echo.active and world.quest.rewards == 1, "New attempt can discover recording again")
	print("MEMORY ECHO RESULT: ", failures, " failures (guards, playback, input, completion, replay, quest, R/T)")
	quit(1 if failures else 0)
