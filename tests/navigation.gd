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

func run() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	arena.player.input_enabled = false
	await frames(90)
	# Approach both sides of each column, keeping the target inside detection range.
	for center in [Vector3(8, 0, -8), Vector3(8, 0, 3), Vector3(-10, 0, 5)]:
		for axis in [Vector3.RIGHT, Vector3.FORWARD]:
			for side in [-1, 1]:
				arena.restart_battle()
				arena.player.position = center + axis * 4 * side
				arena.enemy.position = center - axis * 4 * side
				if center.z == -8 and axis == Vector3.RIGHT:
					arena.player.position.x = 1.0 if side == -1 else 11.5
					arena.enemy.position.x = 11.5 if side == -1 else 1.0
				await frames(420)
				check(arena.enemy.position.distance_to(arena.player.position) < 2.1, "Enemy must navigate around column from each side")
	# Regression: hero and enemy pressed against opposite faces of a column.
	for axis in [Vector3.RIGHT, Vector3.FORWARD]:
		for side in [-1, 1]:
			arena.restart_battle()
			var center := Vector3(8, 0, 3)
			arena.player.position = center + axis * 1.51 * side
			arena.enemy.position = center - axis * 1.51 * side
			await frames(300)
			check(arena.enemy.position.distance_to(arena.player.position) < 2.1, "Enemy must pursue a hero touching a column")
			check(arena.player.health < 100, "Enemy must reach the same side and attack, not stop across the column")
	arena.restart_battle()
	arena.player.position = Vector3(0, 0, 8)
	arena.enemy.position = Vector3(0, 0, 0)
	arena.block(Vector3(0, 1, 4), Vector3(4, 2, 0.3), Color.WHITE)
	var wall = arena.get_child(arena.get_child_count() - 1)
	await frames(2)
	arena.enemy.navigation_ready = false
	await frames(420)
	check(arena.enemy.position.distance_to(arena.player.position) < 2.1, "Enemy must detour around a wall")
	wall.queue_free()
	await frames(2)
	# An enclosed target must leave the enemy still rather than oscillating.
	arena.restart_battle()
	arena.player.position = Vector3(0, 0, 5)
	arena.enemy.position = Vector3(0, 0, -1)
	for at in [Vector3(-1.5, 1, 5), Vector3(1.5, 1, 5)]:
		arena.block(at, Vector3(0.3, 2, 3.3), Color.WHITE)
	for at in [Vector3(0, 1, 3.5), Vector3(0, 1, 6.5)]:
		arena.block(at, Vector3(3.3, 2, 0.3), Color.WHITE)
	await frames(2)
	arena.enemy.navigation_ready = false
	arena.enemy.clear_pursuit()
	await frames(60)
	var stopped: Vector3 = arena.enemy.position
	await frames(120)
	check(arena.enemy.position.distance_to(stopped) < 0.05, "Unreachable target must not cause jitter")
	arena.player.position = Vector3(5, 0, -1)
	await frames(150)
	check(arena.enemy.position.distance_to(arena.player.position) < 2.1, "Enemy must resume pursuit when target becomes reachable")
	arena.enemy.take_damage(100)
	check(arena.enemy.route.is_empty(), "Death must clear pursuit")
	arena.restart_battle()
	check(arena.enemy.route.is_empty() and arena.enemy.repath_time == 0, "Restart must clear pursuit")
	print("NAVIGATION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
