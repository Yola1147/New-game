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
	var player = arena.player
	var enemy = arena.enemy
	player.input_enabled = false
	enemy.set_physics_process(false)
	await frames(90)
	player.position = Vector3(0, 0, 5)
	enemy.position = Vector3(0, 0, 3.3)
	player.visual.rotation.y = 0
	player.pivot.rotation.y = PI / 2
	check(player.start_attack(), "First attack must start")
	check(is_zero_approx(player.visual.rotation.y), "Side camera must not turn hero when attacking")
	check(is_equal_approx(player.pivot.rotation.y, PI / 2), "Attack must not turn camera")
	player.pivot.rotation.y = PI
	check(not player.start_attack(), "Attack cooldown must block spam")
	await frames(20)
	check(enemy.health == 75, "Swing must hit in hero facing direction even when camera turns")
	await frames(20)
	check(enemy.health == 75, "Swing must not damage repeatedly")
	player.pivot.rotation.y = 0
	enemy.position = Vector3(0, 0, 7)
	player.start_attack()
	await frames(35)
	check(enemy.health == 75, "Attack must not hit behind player")
	enemy.position = Vector3(0, 0, -5)
	player.start_attack()
	await frames(35)
	check(enemy.health == 75, "Attack must not hit out of range")
	arena.block(Vector3(0, 1, 4), Vector3(2, 2, 0.2), Color.WHITE)
	enemy.position = Vector3(0, 0, 3.3)
	await frames(2)
	player.start_attack()
	await frames(35)
	check(enemy.health == 75, "Wall must block melee hit")
	player.position = Vector3(5, 0, 5)
	enemy.position = Vector3(5, 0, 3.4)
	for i in range(3):
		player.start_attack()
		await frames(35)
	check(enemy.health == 0 and not enemy.visible, "Enemy must die after four total hits")
	var hp: int = player.health
	enemy.set_physics_process(true)
	await frames(120)
	check(player.health == hp, "Dead enemy must never damage player")
	arena.restart_battle()
	check(player.health == 100 and enemy.health == 100 and enemy.visible, "Restart must restore combat state")
	player.position = Vector3(5, 0, 5)
	enemy.position = Vector3(5, 0, -1)
	await frames(45)
	check(enemy.position.z > -0.5, "Enemy must chase detected player")
	enemy.position = Vector3(5, 0, 3.4)
	enemy.cooldown = 0
	await frames(2)
	check(enemy.windup > 0 and player.health == 100, "Enemy must telegraph before dealing damage")
	player.position = Vector3(10, 0, 5)
	await frames(42)
	check(player.health == 100, "Leaving attack range must evade windup")
	enemy.position = Vector3(10, 0, 3.4)
	enemy.cooldown = 0
	await frames(45)
	check(player.health == 80, "Enemy attack must deal 20 damage")
	player.take_damage(20)
	check(player.health == 80, "Invulnerability must prevent instant repeat damage")
	player.invulnerability = 0
	player.take_damage(100)
	check(player.health == 0 and not player.start_attack(), "Dead hero cannot attack")
	var at: Vector3 = player.position
	await frames(90)
	check(player.position.is_equal_approx(at), "Dead hero must stop moving")
	arena.restart_battle()
	check(player.health == 100 and enemy.windup == 0 and player.attack_time == 0, "Restart must clear pending attacks")
	print("COMBAT RESULT: ", failures, " failures")
	quit(1 if failures else 0)
