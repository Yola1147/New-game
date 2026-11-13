extends "res://tests/quest.gd"

const Store = preload("res://scripts/save_game.gd")
const SLOT := "user://regression-issue14.json"

func fresh() -> Node3D:
	var world = load("res://scenes/main.tscn").instantiate()
	world.save_path = SLOT
	world.persistence_enabled = "--read" in OS.get_cmdline_user_args()
	root.add_child(world)
	world.player.input_enabled = false
	return world

func run() -> void:
	var mode := OS.get_cmdline_user_args()
	var world := fresh()
	if "--read" in mode:
		check(world.save_status.text.begins_with("Загружено"), "Separate process automatically loads checkpoint at startup")
		check(world.player.health == 63 and world.player.reserve_health == 0 and world.player.active_character == 1, "HP, dead reserve and active hero survive process restart")
		check(world.quest.rewards == 1 and not world.player.blade_equipped and world.route_cleared(), "Progress and unequipped reward survive process restart")
		world.persistence_enabled = true
		key(KEY_T)
		check(not FileAccess.file_exists(SLOT), "New game deletes disk slot")
		print("SAVE RESTART RESULT: ", failures, " failures")
		quit(1 if failures else 0)
		return
	Store.clear_slot(SLOT)
	check(not world.load_checkpoint(), "Missing save is harmless")
	for content in ["broken json", "[]", "{}", "null", '{"version":99}']:
		var file := FileAccess.open(SLOT, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		check(not world.load_checkpoint() and world.player.health == 100, "Malformed save leaves live state unchanged")
	world.quest.accept()
	world.player.health = 72
	world.player.reserve_health = 41
	key(KEY_F5)
	check(not Store.read_slot(SLOT).is_empty(), "F5 saves at entrance")
	world.player.position = world.STATION_POINT
	check(not world.save_checkpoint(), "Cannot save outside checkpoint")
	check(Store.read_slot(SLOT).hp == 72, "Rejected save preserves previous slot")
	key(KEY_F9)
	check(world.player.health == 72 and world.player.reserve_health == 41, "F9 restores independent HP")
	world.enemy.position = world.player.position + Vector3(0, 0, -3)
	check(not world.save_checkpoint(), "Cannot save while enemy approaches entrance")
	world.enemy.reset_combat()
	world.dialogue.begin()
	check(not world.save_checkpoint() and not world.load_checkpoint(), "Dialogue blocks disk operations")
	world.dialogue.finish()
	# Check every reachable route boundary, including early door/kill before acceptance.
	for scenario in range(5):
		world.restart_quest()
		if scenario > 0:
			world.quest.accept()
		if scenario in [0, 2, 3, 4]:
			world.puzzle.activate(0)
			world.puzzle.activate(1)
		if scenario >= 2:
			world.enemy.take_damage(100)
			world.advance_prologue()
		if scenario >= 3:
			world.final_enemy.take_damage(175)
			world.advance_prologue()
		if scenario == 4:
			world.player.position = world.STATION_POINT
			world.inspect_memory()
		world.player.respawn()
		var expected: Dictionary = world.checkpoint_data()
		check(world.save_checkpoint(), "Save route boundary %d" % scenario)
		world.queue_free()
		await process_frame
		world = fresh()
		check(world.load_checkpoint(), "Load route boundary %d" % scenario)
		check(world.checkpoint_data() == expected, "Restore route, quest, reward and item %d" % scenario)
		world.quest.accept()
		world.enemy.take_damage(100)
		clear_final_guard(world)
		world.player.position = world.STATION_POINT
		for i in range(3):
			world.inspect_memory()
		check(world.quest.rewards == 1 and world.player.attack_damage() == 30, "Loaded route completes once without deadlock %d" % scenario)
	world.player.health = 0
	world.player.reserve_health = 63
	world.player.switch_character()
	world.player.blade_equipped = false
	world.player.respawn()
	check(world.save_checkpoint(), "Save living hero with dead reserve")
	check(world.save_checkpoint(), "Replacing existing slot succeeds")
	var good: Dictionary = world.checkpoint_data()
	for field in good:
		var bad := good.duplicate()
		bad.erase(field)
		check(not Store.valid(bad), "Missing required field rejected: " + field)
	for change in [{"hp": -1}, {"hp": 101}, {"active": 2}, {"stage": 1.5}, {"rewards": 7}, {"owned": false}, {"door": false}, {"hp": 0, "reserve_hp": 0}]:
		var bad := good.duplicate()
		bad.merge(change, true)
		check(not Store.valid(bad), "Invalid or inconsistent data rejected")
		var file := FileAccess.open(SLOT, FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		check(not world.load_checkpoint() and world.checkpoint_data() == good, "Invalid disk state never partially applies")
	check(world.save_checkpoint(), "Restore valid slot after corruption cases")
	world.player.health = 0
	check(not world.save_checkpoint(), "Dead active hero cannot save")
	world.player.health = 63
	if "--write" not in mode:
		world.persistence_enabled = true
		key(KEY_T)
		check(not FileAccess.file_exists(SLOT) and world.quest.rewards == 0 and not world.player.blade_owned, "T clears progress and disk")
		check(not world.load_checkpoint(), "Deleted save cannot restore previous progress")
	if "--capture" in mode and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/issue14-checkpoint.png")
	print("SAVE LOAD RESULT: ", failures, " failures")
	quit(1 if failures else 0)
