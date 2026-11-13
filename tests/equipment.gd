extends "res://tests/quest.gd"

func capture(view: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/issue13-%s.png" % view)

func strike(world: Node3D, expected: int) -> void:
	var player = world.player
	var enemy = world.enemy
	enemy.reset_combat()
	enemy.set_physics_process(false)
	enemy.position = Vector3(0, 0, 4)
	player.position = Vector3(0, 0, 6)
	player.visual.rotation.y = 0
	await physics_frame
	check(player.start_attack(), "Basic attack starts")
	for i in range(35):
		await physics_frame
	check(enemy.health == 100 - expected, "Actual hit applies exactly %d damage" % expected)

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player = world.player
	player.input_enabled = false
	key(KEY_I)
	check(not player.blade_owned and player.attack_damage() == 25, "Locked item cannot be equipped")
	await strike(world, 25)
	world.quest.accept()
	world.enemy.take_damage(100)
	clear_final_guard(world)
	player.position = world.STATION_POINT
	key(KEY_G)
	check(world.quest.rewards == 1 and player.blade_owned and player.blade_equipped, "Finding grants and equips one blade")
	check(world.equipment_status.text.contains("30 = 25 + 5"), "HUD shows resulting damage and bonus")
	await capture("reward")
	for i in range(5):
		key(KEY_G)
		world.update_journal()
		key(KEY_I)
		check(player.attack_damage() == 25, "Unequip returns to base damage")
		world.update_journal()
		check(not player.blade_equipped, "Journal refresh does not force reequip")
		key(KEY_I)
		check(player.attack_damage() == 30, "Repeated equip cannot stack bonus")
	check(world.quest.rewards == 1, "Repeated finding grants no second reward")
	key(KEY_I, true)
	check(player.blade_equipped, "Key repeat is ignored")
	world.dialogue.begin()
	key(KEY_I)
	check(player.blade_equipped, "Dialogue blocks equipment input")
	world.dialogue.finish()
	world.memory_echo.stop()
	await strike(world, 30)
	player.switch_character()
	await strike(world, 30)
	# Equipment never changes the existing ability damage.
	world.enemy.apply_mark()
	player.use_ability()
	check(world.enemy.health == 10, "Equipped combo still deals 60")
	world.enemy.reset_combat()
	world.enemy.position = Vector3(0, 0, 4)
	await physics_frame
	player.ability_cooldowns[1] = 0
	player.use_ability()
	check(world.enemy.health == 65, "Equipped finisher without mark still deals 35")
	key(KEY_I)
	await strike(world, 25)
	key(KEY_R)
	check(player.blade_owned and not player.blade_equipped and player.attack_damage() == 25, "R preserves unequipped item")
	key(KEY_I)
	key(KEY_R)
	check(player.blade_equipped and player.attack_damage() == 30, "R preserves equipped bonus without stacking")
	player.take_damage(100)
	key(KEY_I)
	check(player.blade_equipped, "Dead active hero cannot change equipment")
	player.switch_character()
	key(KEY_I)
	check(not player.blade_equipped, "Living reserve can change team equipment")
	await capture("unequipped")
	key(KEY_T)
	check(world.quest.rewards == 0 and not player.blade_owned and not player.blade_equipped and player.attack_damage() == 25, "T removes item and bonus")
	world.enemy.take_damage(100)
	clear_final_guard(world)
	world.quest.accept()
	player.position = world.STATION_POINT
	key(KEY_G)
	check(world.quest.rewards == 1 and player.attack_damage() == 30, "New attempt can earn exactly one reward again")
	world.queue_free()
	await process_frame
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	check(not fresh.player.blade_owned and fresh.player.attack_damage() == 25, "Fresh scene starts without progression")
	await capture("fresh")
	print("EQUIPMENT RESULT: ", failures, " failures")
	quit(1 if failures else 0)
