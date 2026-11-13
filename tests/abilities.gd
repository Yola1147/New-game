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
	player.visual.rotation.y = 0
	enemy.position = Vector3(0, 0, 0)
	check(player.use_ability(), "Setup ability must be available")
	check(enemy.mark_time == 5 and enemy.health == 100 and enemy.mark_visual.visible, "Setup must mark without damage at range")
	check(not player.use_ability(), "Cooldown must block repeated setup")
	enemy._physics_process(0.01)
	check(is_equal_approx(Vector2(enemy.velocity.x, enemy.velocity.z).length(), 1.4), "Marked enemy must pursue at half speed")
	player.switch_character()
	check(player.use_ability() and enemy.health == 100 and enemy.mark_time > 0, "Finisher must miss outside melee range without consuming mark")
	player.ability_cooldowns[1] = 0
	enemy.position = Vector3(0, 0, 3.3)
	check(player.use_ability(), "Second hero must have independent ability")
	check(enemy.health == 40 and enemy.mark_time == 0 and enemy.combo_time > 0, "Both abilities must produce 60 damage and consume mark")
	arena.update_status()
	check(arena.status.text.contains("Взаимодействие!") and arena.status.text.contains("6.0 с"), "HUD must report combo and cooldown")
	player.ability_cooldowns[1] = 0
	player.use_ability()
	check(enemy.health == 5, "Unmarked finisher must deal only 35 damage")
	player.switch_character()
	check(not player.use_ability(), "Switch must preserve setup cooldown")
	await frames(20)
	check(player.ability_cooldowns[0] < 6 and player.ability_cooldowns[1] < 6, "Both ability cooldowns must elapse in reserve")
	arena.restart_battle()
	check(player.ability_cooldowns == [0.0, 0.0] and enemy.mark_time == 0 and enemy.combo_time == 0, "R must clear abilities and enemy effects")
	player.position = Vector3(0, 0, 5)
	enemy.position = Vector3(0, 0, 3.3)
	player.start_attack()
	check(not player.use_ability(), "Ability must wait until basic attack recovery")
	await frames(35)
	player.use_ability()
	enemy._physics_process(5.1)
	check(enemy.mark_time == 0 and not enemy.mark_visual.visible, "Mark must expire")
	player.switch_character()
	player.use_ability()
	check(enemy.health == 40 and enemy.combo_time == 0, "Expired mark must not enable combo")
	player.take_damage(100)
	player.ability_cooldowns[1] = 0
	check(not player.use_ability(), "Dead hero must not use abilities")
	arena.restart_battle()
	player.position = Vector3(0, 0, 5)
	enemy.position = Vector3(0, 0, 7)
	player.use_ability()
	check(enemy.mark_time == 0, "Ability must not target behind hero")
	player.ability_cooldowns[0] = 0
	enemy.position = Vector3(0, 0, 3.3)
	arena.block(Vector3(0, 1, 4), Vector3(2, 2, 0.2), Color.WHITE)
	await frames(2)
	player.use_ability()
	check(enemy.mark_time == 0, "Wall must block setup")
	player.switch_character()
	player.use_ability()
	check(enemy.health == 100, "Wall must block finisher")
	# Test real E input and echo handling even on headless (no mouse capture).
	player.input_enabled = true
	player.reset_combat()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.parse_input_event(key)
	await frames(2)
	check(player.ability_cooldowns[0] == 0, "Free cursor must block E")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.parse_input_event(key)
		await frames(2)
		check(player.ability_cooldowns[0] > 0, "Captured E must use ability")
		player.ability_cooldowns[0] = 0
		key.echo = true
		Input.parse_input_event(key)
		await frames(2)
		check(player.ability_cooldowns[0] == 0, "E repeat must be rejected")
	key.pressed = false
	key.echo = false
	Input.parse_input_event(key)
	print("ABILITIES RESULT: ", failures, " failures")
	quit(1 if failures else 0)
