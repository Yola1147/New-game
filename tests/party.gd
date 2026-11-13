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
	player.take_damage(20)
	player.start_attack()
	var at: Vector3 = player.position
	var facing: float = player.visual.rotation.y
	var camera: float = player.pivot.rotation.y
	check(player.switch_character(), "Living reserve must be selectable")
	check(player.health == 100 and player.reserve_health == 80, "Health must be independent")
	check(player.position == at and player.visual.rotation.y == facing and player.pivot.rotation.y == camera, "Switch must preserve body and camera")
	check(player.start_attack(), "Second hero has an independent cooldown")
	check(player.switch_character(), "Switch back must succeed")
	check(player.health == 80 and not player.start_attack(), "Switch must not heal or reset cooldown")
	check(player.invulnerability > 0, "Own invulnerability must be preserved")
	await frames(40)
	check(enemy.health == 100, "Cancelled delayed hits must never resolve")
	check(player.reserve_cooldown == 0 and player.attack_time == 0, "Both cooldowns must elapse")
	check(player.start_attack(), "Attack must recover after switching")
	await frames(20)
	check(enemy.health == 75, "Recovered hero must hit exactly once")
	player.switch_character()
	player.switch_character()
	await frames(20)
	check(enemy.health == 75, "Switch after a hit must not duplicate damage")
	player.invulnerability = 0
	player.take_damage(100)
	check(not player.party_defeated() and not player.start_attack(), "One death must leave reserve available")
	check(player.switch_character() and player.health == 100, "Dead hero can be replaced by living reserve")
	check(not player.switch_character(), "Dead reserve cannot be selected")
	player.take_damage(100)
	check(player.party_defeated() and not player.switch_character(), "Both deaths must defeat party")
	check(arena.status.text.contains("Поражение"), "HUD must show party defeat")
	arena.restart_battle()
	check(player.active_character == 0 and player.health == 100 and player.reserve_health == 100, "R must restore both heroes and first selection")
	check(player.attack_time == 0 and player.reserve_cooldown == 0 and player.invulnerability == 0 and player.reserve_invulnerability == 0, "R must clear all combat timers")
	check(enemy.health == 100 and enemy.target == player, "R must restore enemy and shared target")
	player.position = Vector3(0, 0, 5)
	enemy.position = Vector3(0, 0, 3.3)
	enemy.windup = 0.05
	enemy.attack_direction = Vector3.BACK
	player.switch_character()
	enemy._physics_process(0.1)
	check(player.health == 80 and player.reserve_health == 100, "Pending enemy swing must damage only the incoming active hero")
	player.start_attack()
	player.switch_character()
	player.start_attack()
	arena.restart_battle()
	player.position = Vector3(0, 0, 5)
	enemy.position = Vector3(0, 0, 3.3)
	await frames(40)
	check(enemy.health == 100 and player.attack_time == 0 and player.reserve_cooldown == 0, "R during both recoveries must prevent ghost hits")
	# Exercise the actual Q binding, including echo rejection and disabled input.
	player.input_enabled = true
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	Input.parse_input_event(key)
	await frames(2)
	check(player.active_character == 1, "Q must switch through input")
	key.echo = true
	Input.parse_input_event(key)
	await frames(2)
	check(player.active_character == 1, "Key repeat must not cycle heroes")
	key.pressed = false
	key.echo = false
	Input.parse_input_event(key)
	print("PARTY RESULT: ", failures, " failures")
	quit(1 if failures else 0)
