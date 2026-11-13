extends "res://tests/puzzle.gd"

# Focused state/AI regression complements the full route in station_playthrough.
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await frames(90)
	var player = world.player
	check(not is_instance_valid(world.final_enemy), "No reinforced guard before hall and puzzle")
	world.puzzle.activate(0)
	world.puzzle.activate(1)
	await frames(2)
	check(not is_instance_valid(world.final_enemy), "Opening puzzle early cannot skip ordinary guard")
	world.enemy.take_damage(100)
	await frames(2)
	var guard = world.final_enemy
	check(is_instance_valid(guard) and guard.reinforced and guard.health == 175 and guard.attack_damage == 30, "Existing AI has stronger prototype stats")
	world.advance_prologue()
	check(get_nodes_in_group("enemies").size() == 2, "Repeated progression cannot duplicate guard")
	world.quest.accept()
	world.advance_prologue()
	check(world.quest.stage == world.quest.Stage.DEFEAT_REINFORCED, "Early hall/puzzle progress counts after acceptance")
	player.position = world.STATION_POINT
	world.inspect_memory()
	check(world.quest.rewards == 0 and not world.memory_echo.active, "Live reinforced guard blocks echo via bypass")
	# Let the real AI kill both heroes; Q selects the surviving reserve.
	player.position = Vector3(0, 0, -9.5)
	player.input_enabled = false
	await frames(450)
	check(player.health == 0 and guard.health == 175, "Reinforced AI can defeat first hero")
	player.switch_character()
	await frames(450)
	check(player.party_defeated(), "Reinforced AI can defeat entire party")
	world.inspect_memory()
	check(world.quest.rewards == 0, "Defeat cannot award finding")
	key(KEY_R)
	await frames(3)
	check(not is_instance_valid(world.final_enemy) and world.enemy.health == 100, "R removes final guard and restores hall")
	check(world.puzzle.opened and world.quest.stage == world.quest.Stage.DEFEAT_GUARD, "R preserves mechanism and assignment but updates combat objective")
	check(player.health == 100 and player.reserve_health == 100 and player.position.z > 7, "R restores party at entrance")
	world.enemy.take_damage(100)
	await frames(2)
	guard = world.final_enemy
	check(guard.health == 175 and guard.mark_time == 0 and guard.windup == 0, "Retry creates clean reinforced guard")
	player.position = Vector3(0, 0, -9.5)
	for i in range(60):
		await frames(1)
		if guard.windup > 0:
			break
	check(guard.windup > 0 and guard.material.albedo_color.is_equal_approx(Color("ffbe62")), "Attack windup remains visibly orange")
	var hp: int = player.health
	player.input_enabled = true
	player.pivot.rotation.y = 0
	Input.action_press("move_back")
	await frames(45)
	Input.action_release("move_back")
	check(player.health == hp, "Moving away during telegraph avoids damage")
	guard.apply_mark()
	check(guard.mark_time > 0 and guard.mark_visual.visible, "Existing mark applies to reinforced variant")
	guard.receive_finisher()
	check(guard.health == 115 and guard.mark_time == 0, "Existing combo consumes mark for 60 damage")
	guard.take_damage(115)
	await frames(2)
	check(world.quest.stage == world.quest.Stage.INSPECT_STATION, "Final victory unlocks finding objective")
	player.position = world.STATION_POINT
	world.inspect_memory()
	world.inspect_memory()
	check(world.quest.rewards == 1 and world.memory_echo.active, "Final victory permits exactly one finding")
	key(KEY_T)
	await frames(3)
	check(not world.puzzle.opened and not is_instance_valid(world.final_enemy), "T removes final phase and closes passage")
	check(world.quest.rewards == 0 and world.quest.stage == world.quest.Stage.NOT_STARTED and not world.memory_echo.active, "T clears ending and recording")
	world.enemy.take_damage(100)
	world.advance_prologue()
	check(not is_instance_valid(world.final_enemy), "New attempt requires mechanism again")
	world.puzzle.activate(0)
	world.puzzle.activate(1)
	world.advance_prologue()
	world.final_enemy.take_damage(175)
	player.position = world.STATION_POINT
	world.inspect_memory()
	check(world.quest.rewards == 0, "Clearing route before assignment does not award finding")
	world.quest.accept()
	world.inspect_memory()
	check(world.quest.rewards == 1, "Accepting after both victories still allows completion")
	print("PROLOGUE RESULT: ", failures, " failures (order, variant AI, defeat, retry, evasion, combo, finding, resets)")
	quit(1 if failures else 0)
