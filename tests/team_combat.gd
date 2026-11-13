extends SceneTree

# Integration regression: real Q/R events, uninterrupted recovery, no timer cheats.
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

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func run() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	var player = arena.player
	var enemy = arena.enemy
	enemy.set_physics_process(false)
	await frames(90)
	player.position = Vector3(0, 0, 5)
	player.visual.rotation.y = 0
	enemy.position = Vector3(0, 0, 3.3)
	player.take_damage(20)
	check(player.use_ability(), "First hero must apply setup")
	check(player.start_attack(), "Basic attack must work after setup")
	key(KEY_Q)
	await frames(1)
	check(player.active_character == 1, "Q must select damage hero during outgoing swing")
	check(player.use_ability() and enemy.health == 40, "Incoming hero must consume setup for 60 damage")
	check(player.start_attack(), "Damage hero must have own basic recovery")
	# Repeated switching during both windups must not heal, refresh abilities,
	# resolve cancelled hits, or transfer the outgoing hero's protection.
	for i in range(8):
		key(KEY_Q)
		await frames(1)
		check(not player.start_attack(), "Q spam must not bypass basic recovery")
		check(not player.use_ability(), "Q spam must not bypass ability recovery")
		var expected_hp := 80 if player.active_character == 0 else 100
		check(player.health == expected_hp, "Q spam must preserve individual HP")
	check(player.invulnerability == 0, "Incoming hero must not inherit reserve protection")
	player.take_damage(20)
	check(player.health == 80 and player.reserve_health == 80, "Only active hero may receive damage")
	await frames(40)
	check(enemy.health == 40, "Neither cancelled swing may land after recovery")
	check(player.attack_time == 0 and player.reserve_cooldown == 0, "Both basic recoveries must finish in real physics frames")
	check(player.ability_cooldowns[0] > 4 and player.ability_cooldowns[1] > 4, "Basic recovery must not finish either six-second ability timer")
	check(player.invulnerability == 0 and player.reserve_invulnerability == 0, "Both protection timers must expire in reserve")
	check(not player.use_ability(), "Recovered basic attack must not unlock ability early")
	await frames(330)
	check(player.ability_cooldowns == [0.0, 0.0], "Both abilities must recover naturally, including reserve")
	check(player.use_ability() and enemy.health == 5, "Recovered unmarked finisher must deal only 35")
	key(KEY_Q)
	await frames(1)
	check(player.use_ability() and enemy.mark_time > 0, "Reserve setup must recover without selecting it")
	check(player.start_attack(), "Recovered basic hit must be available")
	await frames(20)
	check(enemy.health == 0 and enemy.mark_time == 0 and enemy.windup == 0, "Victory must clear enemy effects and pending attack")
	arena.update_status()
	check(arena.status.text.contains("Победа"), "Integrated fight must report victory")
	key(KEY_Q)
	await frames(20)
	check(enemy.health == 0, "Switch after victory must not revive enemy")
	key(KEY_R)
	await frames(2)
	check(player.active_character == 0 and player.health == 100 and player.reserve_health == 100 and enemy.health == 100, "R after victory must restore entire fight")
	player.position = Vector3(0, 0, 5)
	enemy.position = Vector3(0, 0, 3.3)
	player.use_ability()
	key(KEY_Q)
	await frames(1)
	player.use_ability()
	player.start_attack()
	enemy.windup = 0.3
	key(KEY_R)
	await frames(2)
	check(player.ability_cooldowns == [0.0, 0.0] and player.attack_time == 0 and player.reserve_cooldown == 0, "R mid-combo must clear both ability and basic recoveries")
	check(enemy.mark_time == 0 and enemy.combo_time == 0 and enemy.windup == 0 and not enemy.mark_visual.visible, "R must clear mark, feedback and enemy swing")
	player.position = Vector3(0, 0, 5)
	enemy.position = Vector3(0, 0, 3.3)
	await frames(40)
	check(enemy.health == 100 and player.health == 100, "Reset must leave no delayed damage")
	player.start_attack()
	player.take_damage(100)
	check(not player.use_ability() and not player.start_attack(), "Dead active hero must not act")
	key(KEY_Q)
	await frames(1)
	check(player.active_character == 1 and player.health == 100, "Q must rescue fight using living reserve")
	player.start_attack()
	player.take_damage(100)
	key(KEY_Q)
	await frames(40)
	check(player.party_defeated() and enemy.health == 100, "Party defeat must cancel both delayed hits")
	arena.update_status()
	check(arena.status.text.contains("Поражение"), "Integrated fight must report defeat")
	key(KEY_R)
	await frames(2)
	check(not player.party_defeated() and player.active_character == 0 and player.health == 100 and player.reserve_health == 100, "R after defeat must restore both heroes")
	print("TEAM COMBAT RESULT: ", failures, " failures")
	quit(1 if failures else 0)
