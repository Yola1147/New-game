extends Node3D

const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Dialogue = preload("res://scripts/dialogue.gd")
const Quest = preload("res://scripts/quest.gd")
const STATION_POINT := Vector3(4, 0, -10)
var puzzle: Node3D
var quest := Quest.new()
var dialogue: CanvasLayer
var memory_echo: CanvasLayer
var puzzle_panel: PanelContainer
var puzzle_status: Label
var assignment_status: Label
var player: CharacterBody3D
var enemy: CharacterBody3D
var status: Label

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
	route_hint.text = "Маршрут: вход → зал боя → механизм у прохода → находка (или обход справа) · временные ассеты"
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

func configure_input() -> void:
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
	update_status()

func inspect_memory() -> void:
	if player.health <= 0 or player.global_position.distance_to(STATION_POINT) > 2.5 or enemy.health > 0:
		return
	quest.inspect(true, true, true)
	if quest.stage == Quest.Stage.COMPLETED:
		memory_echo.play()

func _process(_delta: float) -> void:
	quest.observe_guard(enemy.health <= 0)
	update_status()

func update_journal() -> void:
	assignment_status.text = quest.journal_text()

func restart_quest() -> void:
	if dialogue.active:
		return
	dialogue.assignment_accepted = false
	quest.reset()
	restart_battle()
	puzzle.reset_puzzle()

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
	puzzle_panel.visible = player.global_position.distance_to(puzzle.global_position) < 8
	puzzle_status.text = puzzle.hint_text()
	status.text = "Герой %d: %d / 100    Резерв: %d / 100    Страж: %d / 100" % [player.active_character + 1, player.health, player.reserve_health, enemy.health]
	status.text += "\n1 · Метка: %s    2 · Сильный удар: %s" % [ability_status(0), ability_status(1)]
	if enemy.mark_time > 0:
		status.text += "\nСтраж замедлен · Метка: %.1f с — E героя 2 для взаимодействия" % enemy.mark_time
	if enemy.combo_time > 0:
		status.text += "\nВзаимодействие! Метка израсходована · 60 урона"
	if player.party_defeated():
		status.text += "\nПоражение. R — повторить бой"
	elif player.health <= 0:
		status.text += "\nГерой погиб. Q — выбрать живого героя; R — новый бой"
	elif enemy.health <= 0:
		status.text += "\nПобеда! R — повторить бой"

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
