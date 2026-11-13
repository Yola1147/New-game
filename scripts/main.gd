extends Node3D

const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Dialogue = preload("res://scripts/dialogue.gd")
const Quest = preload("res://scripts/quest.gd")
const SaveGame = preload("res://scripts/save_game.gd")
# Script-driven regressions opt in explicitly and use their own slot.
var persistence_enabled := not "--script" in OS.get_cmdline_args()
var save_path := SaveGame.PATH
var save_status: Label
const STATION_POINT := Vector3(4, 0, -10)
var puzzle: Node3D
var quest := Quest.new()
var dialogue: CanvasLayer
var memory_echo: CanvasLayer
var puzzle_panel: PanelContainer
var puzzle_status: Label
var assignment_status: Label
var player: CharacterBody3D
var final_enemy: CharacterBody3D
var enemy: CharacterBody3D
var status: Label
var equipment_status: Label

func _ready() -> void:
	configure_input()
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("263b53")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b4c8e2")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	preload("res://scripts/station.gd").build(self)
	player = Player.new()
	player.name = "Player"
	player.position = Vector3(0, 2, 8)
	add_child(player)
	enemy = Enemy.new()
	enemy.home = Vector3(0, 1, -4)
	enemy.position = enemy.home
	enemy.target = player
	add_child(enemy)
	player.health_changed.connect(update_status)
	player.defeated.connect(update_status)
	enemy.health_changed.connect(update_status)
	var hud := CanvasLayer.new()
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	hud.add_child(panel)
	var route_hint := Label.new()
	route_hint.position = Vector2(18, 660)
	route_hint.text = "Маршрут: вход → зал боя → механизм → усиленный страж → Эхо памяти · временные ассеты"
	route_hint.add_theme_font_size_override("font_size", 18)
	hud.add_child(route_hint)
	var label := Label.new()
	label.text = "NEW GAME · Руины станции (прототип)\nWASD — движение • Мышь — камера • Пробел — прыжок\nЛКМ — удар • Q — смена героя • E — способность • Esc — курсор • R — новый бой\nГерой 1: метка с 6 м и замедление на 5 с → Q → Герой 2: удар с 2.4 м\nМетка + удар: 60 вместо 35 урона. Оранжевый страж готовит атаку."
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	status = Label.new()
	status.position = Vector2(18, 165)
	status.add_theme_font_size_override("font_size", 24)
	hud.add_child(status)
	equipment_status = Label.new()
	var equipment_panel := PanelContainer.new()
	equipment_panel.position = Vector2(18, 457)
	hud.add_child(equipment_panel)
	equipment_status.add_theme_font_size_override("font_size", 18)
	equipment_panel.add_child(equipment_status)
	puzzle_panel = PanelContainer.new()
	puzzle_panel.position = Vector2(18, 365)
	hud.add_child(puzzle_panel)
	puzzle_status = Label.new()
	puzzle_status.add_theme_font_size_override("font_size", 20)
	puzzle_panel.add_child(puzzle_status)
	assignment_status = Label.new()
	var journal_panel := PanelContainer.new()
	journal_panel.position = Vector2(18, 545)
	hud.add_child(journal_panel)
	assignment_status.add_theme_font_size_override("font_size", 20)
	assignment_status.text = quest.journal_text()
	journal_panel.add_child(assignment_status)
	dialogue = Dialogue.new()
	add_child(dialogue)
	dialogue.assignment_received.connect(quest.accept)
	memory_echo = preload("res://scripts/memory_echo.gd").new()
	add_child(memory_echo)
	quest.changed.connect(update_journal)
	update_status()
	save_status = Label.new()
	save_status.position = Vector2(18, 690)
	save_status.add_theme_font_size_override("font_size", 16)
	hud.add_child(save_status)
	save_status.text = "F5 — сохранить у входа · F9 — загрузить · T — новая игра (удалить слот)"
	if persistence_enabled:
		load_checkpoint()

func configure_input() -> void:
	if not InputMap.has_action("toggle_equipment"):
		InputMap.add_action("toggle_equipment")
		var equip_key := InputEventKey.new()
		equip_key.physical_keycode = KEY_I
		InputMap.action_add_event("toggle_equipment", equip_key)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", click)
	var bindings := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE, "release_mouse": KEY_ESCAPE, "reset": KEY_R, "switch_character": KEY_Q, "ability": KEY_E, "talk": KEY_F, "dialogue_next": KEY_ENTER, "inspect_station": KEY_G, "reset_quest": KEY_T}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)

func _input(event: InputEvent) -> void:
	if dialogue.active:
		return
	if event.is_echo():
		return
	if event is InputEventKey and event.pressed and event.physical_keycode in [KEY_F5, KEY_F9]:
		if event.physical_keycode == KEY_F5:
			save_checkpoint()
		else:
			load_checkpoint()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_equipment"):
		player.toggle_equipment()
		update_status()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("reset_quest"):
		restart_quest()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inspect_station"):
		inspect_memory()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("talk") and not event.is_echo() and player.health > 0:
		memory_echo.stop()
		dialogue.begin()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("reset"):
		restart_battle()

func restart_battle() -> void:
	memory_echo.stop()
	player.reset_combat()
	enemy.reset_combat()
	if is_instance_valid(final_enemy):
		remove_child(final_enemy)
		final_enemy.queue_free()
		final_enemy = null
	advance_prologue()
	update_status()

func inspect_memory() -> void:
	advance_prologue()
	if player.health <= 0 or player.global_position.distance_to(STATION_POINT) > 2.5 or not route_cleared():
		return
	quest.inspect(true, true, true)
	if quest.stage == Quest.Stage.COMPLETED:
		memory_echo.play()

func route_cleared() -> bool:
	return enemy.health <= 0 and puzzle.opened and is_instance_valid(final_enemy) and final_enemy.health <= 0

func advance_prologue() -> void:
	if enemy.health <= 0 and puzzle.opened and not is_instance_valid(final_enemy):
		final_enemy = Enemy.new()
		final_enemy.name = "ReinforcedGuard"
		final_enemy.reinforced = true
		final_enemy.home = Vector3(0, 1, -11)
		final_enemy.position = final_enemy.home
		final_enemy.target = player
		add_child(final_enemy)
		final_enemy.health_changed.connect(update_status)
	quest.observe_route(enemy.health <= 0, puzzle.opened, route_cleared())

func _process(_delta: float) -> void:
	advance_prologue()
	update_status()

func update_journal() -> void:
	# Completion grants one item; repeated journal updates preserve the chosen state.
	if quest.rewards > 0 and not player.blade_owned:
		player.blade_owned = true
		player.blade_equipped = true
	elif quest.rewards == 0:
		player.blade_owned = false
		player.blade_equipped = false
	assignment_status.text = quest.journal_text()
	update_status()

func restart_quest() -> void:
	if dialogue.active:
		return
	if persistence_enabled and not SaveGame.clear_slot(save_path):
		save_status.text = "Не удалось удалить сохранение. Новая игра отменена."
		return
	dialogue.assignment_accepted = false
	quest.reset()
	puzzle.reset_puzzle()
	restart_battle()
	if is_instance_valid(save_status):
		save_status.text = "Новая игра · слот очищен · F5 — сохранить у входа · F9 — загрузить"

func checkpoint_data() -> Dictionary:
	advance_prologue()
	return {"version": SaveGame.VERSION, "active": player.active_character,
		"hp": player.health, "reserve_hp": player.reserve_health,
		"stage": quest.stage, "rewards": quest.rewards,
		"guard": enemy.health <= 0, "door": puzzle.opened,
		"final_guard": route_cleared(), "owned": player.blade_owned,
		"equipped": player.blade_equipped}

func save_checkpoint() -> bool:
	if dialogue.active or player.health <= 0 or player.attack_time > 0 or player.global_position.distance_to(Vector3(0, 0, 8)) > 3:
		save_status.text = "Сохранение: вернитесь живым героем ко входу (0, 8), вне атаки."
		return false
	# A pursuing guard must not turn the entrance into a combat save point.
	for guard in get_tree().get_nodes_in_group("enemies"):
		if guard.health > 0 and guard.global_position.distance_to(player.global_position) < 11.5:
			save_status.text = "Сохранение недоступно: рядом страж. R возвращает бой к началу."
			return false
	var saved := SaveGame.write_slot(checkpoint_data(), save_path)
	save_status.text = "Сохранено · F9 — загрузить · T — новая игра" if saved else "Ошибка записи: прежний слот сохранён."
	return saved

func load_checkpoint() -> bool:
	if dialogue.active:
		return false
	var data := SaveGame.read_slot(save_path)
	if data.is_empty():
		save_status.text = "Нет корректного слота · F5 — сохранить у входа · F9 — загрузить · T — новая игра"
		return false
	# Validate everything before changing the live scene. Never replay reward signals.
	memory_echo.stop()
	quest.stage = Quest.Stage.NOT_STARTED
	quest.rewards = 0
	puzzle.reset_puzzle()
	restart_battle()
	puzzle.opened = data.door
	puzzle.set_gate_open(puzzle.opened)
	puzzle.update_hint()
	if data.guard:
		enemy.take_damage(enemy.max_health)
	advance_prologue()
	if data.final_guard:
		final_enemy.take_damage(final_enemy.max_health)
	player.active_character = int(data.active)
	player.health = int(data.hp)
	player.reserve_health = int(data.reserve_hp)
	player.body_material.albedo_color = Color("67d9cf") if player.active_character == 0 else Color("b99aea")
	player.blade_owned = data.owned
	player.blade_equipped = data.equipped
	quest.stage = int(data.stage)
	quest.rewards = int(data.rewards)
	dialogue.assignment_accepted = quest.stage != Quest.Stage.NOT_STARTED
	advance_prologue()
	update_journal()
	save_status.text = "Загружено у входа · F5 — сохранить · T — новая игра"
	return true

func ability_status(index: int) -> String:
	var hp: int = player.health if index == player.active_character else player.reserve_health
	if hp <= 0:
		return "погиб"
	var remaining: float = player.ability_cooldowns[index]
	if remaining > 0:
		return "%.1f с" % remaining
	if index == player.active_character and player.attack_time > 0:
		return "после удара"
	return "готова"

func update_status() -> void:
	if not is_instance_valid(status):
		return
	var equipment := "награда за поручение"
	if player.blade_owned:
		equipment = "надет" if player.blade_equipped else "снят"
	equipment_status.text = "Экипировка команды (прототип) · Учебный клинок: %s\nОбычный удар обоих героев: %d = 25 + %d · I — надеть / снять\nСпособности: 35 / 60 по метке · бонус только к обычному удару" % [equipment, player.attack_damage(), player.attack_damage() - 25]
	puzzle_panel.visible = player.global_position.distance_to(puzzle.global_position) < 8
	puzzle_status.text = puzzle.hint_text()
	status.text = "Герой %d: %d / 100    Резерв: %d / 100    Страж: %d / 100" % [player.active_character + 1, player.health, player.reserve_health, enemy.health]
	if is_instance_valid(final_enemy):
		status.text += "\nУсиленный страж: %d / %d · урон 30 · замах 0,65 с" % [final_enemy.health, final_enemy.max_health]
	status.text += "\n1 · Метка: %s    2 · Сильный удар: %s" % [ability_status(0), ability_status(1)]
	var combat_enemy = final_enemy if is_instance_valid(final_enemy) else enemy
	if combat_enemy.mark_time > 0:
		status.text += "\nСтраж замедлен · Метка: %.1f с — E героя 2 для взаимодействия" % combat_enemy.mark_time
	if combat_enemy.combo_time > 0:
		status.text += "\nВзаимодействие! Метка израсходована · 60 урона"
	if player.party_defeated():
		status.text += "\nПоражение. R — повторить бой"
	elif player.health <= 0:
		status.text += "\nГерой погиб. Q — выбрать живого героя; R — новый бой"
	elif route_cleared() and quest.stage == Quest.Stage.COMPLETED:
		status.text += "\nПролог завершён · G рядом с Эхом — повтор записи"
	elif route_cleared():
		status.text += "\nПобеда! G у Эха памяти — завершить поручение"
	elif enemy.health <= 0 and not puzzle.opened:
		status.text += "\nПобеда в зале! Откройте проход: E → Q → E у механизма"
	elif is_instance_valid(final_enemy) and final_enemy.health > 0:
		status.text += "\nУсиленный страж в дальней комнате · R — повторить бой"

func block(at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)
	return body
