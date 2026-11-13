extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func capture(view: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/issue8-%s.png" % view)

# Move the actual player with normal actions, collisions and gravity, no jumps.
func walk(player: CharacterBody3D, point: Vector3) -> void:
	for i in range(360):
		var offset := point - player.position
		if Vector2(offset.x, offset.z).length() < 0.22:
			break
		for action in ["move_left", "move_right", "move_forward", "move_back"]:
			Input.action_release(action)
		# Release early near a waypoint so acceleration does not carry us past it.
		if Vector2(offset.x, offset.z).length() < 0.8 and Vector2(player.velocity.x, player.velocity.z).length() > 2:
			await physics_frame
			continue
		if absf(offset.x) > 0.14:
			Input.action_press("move_right" if offset.x > 0 else "move_left")
		if absf(offset.z) > 0.14:
			Input.action_press("move_back" if offset.z > 0 else "move_forward")
		await physics_frame
		check(player.position.y > -0.1, "Route must keep hero above the solid floor")
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)
	await frames(10)
	check(Vector2(player.position.x - point.x, player.position.z - point.z).length() < 0.55, "Route waypoint must be reachable: %s; actual %s; HP %d" % [point, player.position, player.health])
	check(player.is_on_floor(), "Hero must stand on floor at route waypoints")

func run() -> void:
	var station = load("res://scenes/main.tscn").instantiate()
	root.add_child(station)
	var player = station.player
	var enemy = station.enemy
	player.input_enabled = false
	await frames(90)
	check(get_nodes_in_group("enemies").size() == 1, "Station must have one ordinary enemy")
	check(player.health == 100 and enemy.position.distance_to(enemy.home) < 1.1, "Entrance must be outside enemy detection")
	await capture("entrance")
	# Pursuit must use the east opening rather than walking through the sealed door.
	player.position = Vector3(0, 0, -9)
	enemy.position = Vector3(0, 0, -3)
	await frames(600)
	check(enemy.position.distance_to(player.position) < 2.1, "Guard must reach hero around the sealed passage")
	check(player.health < 100, "Guard must attack after detouring into the rear room")
	station.restart_quest()
	enemy.set_physics_process(false)
	player.input_enabled = true
	player.pivot.rotation.y = 0
	station.quest.accept()
	await frames(90)
	await walk(player, Vector3(0, 0, 1))
	player.input_enabled = false
	enemy.set_physics_process(true)
	await frames(100)
	player.visual.rotation.y = 0
	for i in range(4):
		check(player.start_attack(), "Hall fight must allow a basic strike")
		await frames(35)
	check(enemy.health == 0 and player.health > 0, "Hall fight must be winnable with basic attacks")
	player.input_enabled = true
	await walk(player, Vector3(0, 0, -3))
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	await frames(10)
	check(player.position.z > -5.3 and player.position.z < -4.9, "Closed passage must physically block forward movement")
	await capture("gate")
	await walk(player, Vector3(0, 0, -3))
	for point in [Vector3(4.75, 0, -3), Vector3(4.75, 0, -10), station.STATION_POINT]:
		await walk(player, point)
	await capture("find")
	var inspect := InputEventKey.new()
	inspect.physical_keycode = KEY_G
	inspect.pressed = true
	Input.parse_input_event(inspect)
	Input.flush_buffered_events()
	check(station.quest.rewards == 0, "Bypass cannot skip mechanism and reinforced guard")
	# A return trip also catches one-way collision traps.
	for point in [Vector3(4.75, 0, -10), Vector3(4.75, 0, -3), Vector3(0, 0, -3), Vector3(0, 0, 8), Vector3(0, 0, 13), Vector3(0, 0, 8)]:
		await walk(player, point)
	station.restart_battle()
	await frames(90)
	check(player.position.distance_to(Vector3(0, 0, 8)) < 0.2, "Reset must restore the station entrance")
	check(enemy.position.distance_to(Vector3(0, 0, -4)) < 0.2, "Reset must restore guard in the combat hall")
	print("STATION RESULT: ", failures, " failures (walked route, return, gate collision, pursuit, fight, quest, reset)")
	quit(1 if failures else 0)
