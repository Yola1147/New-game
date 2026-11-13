extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(90)
	var player = arena.player
	check(player.is_on_floor(), "Player must land on arena floor")
	var initial: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	check(player.position.z < initial.z - 3.0, "Forward movement must travel at least 3 metres")
	await frames(20)
	var base_y: float = player.position.y
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(12)
	check(player.position.y > base_y + 0.5, "Jump must rise above floor")
	await frames(90)
	check(player.is_on_floor(), "Jump must finish on ground")
	player.position = Vector3(0, 0.1, 13)
	player.velocity = Vector3.ZERO
	Input.action_press("move_back")
	await frames(90)
	Input.action_release("move_back")
	check(player.position.z < 15.3, "Wall must block movement")
	player.position.y = -20
	await frames(3)
	check(player.position.y > 0, "Falling out must respawn")
	check(player.spring.collision_mask == 1, "Camera must collide with environment only")
	print("SMOKE RESULT: ", failures, " failures (landing, movement, jump, walls, respawn, camera mask)")
	quit(1 if failures else 0)
