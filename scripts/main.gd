extends Node3D

const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
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
	block(Vector3(0, -0.5, 0), Vector3(32, 1, 32), Color("526c68"))
	for x in [-16.0, 16.0]:
		block(Vector3(x, 1.5, 0), Vector3(1, 4, 33), Color("58647c"))
	for z in [-16.0, 16.0]:
		block(Vector3(0, 1.5, z), Vector3(32, 4, 1), Color("58647c"))
	for i in range(4):
		block(Vector3(-8 + i * 2.8, 0.3 + i * 0.3, -4), Vector3(2.4, 0.6 + i * 0.6, 3), Color("8997a8"))
	for point in [Vector3(8, 1.5, -8), Vector3(8, 1.5, 3), Vector3(-10, 1.5, 5)]:
		block(point, Vector3(2, 3, 2), Color("b3a5bd"))
	block(Vector3(4, 0.1, -10), Vector3(4, 0.2, 4), Color("65cfc4"))
	player = Player.new()
	player.name = "Player"
	player.position = Vector3(0, 2, 8)
	add_child(player)
	enemy = Enemy.new()
	enemy.position = Vector3(0, 1, -10)
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
	var label := Label.new()
	label.text = "NEW GAME · Боевая арена (прототип)\nWASD — движение • Мышь — камера • Пробел — прыжок\nЛКМ — удар • Q — смена героя • E — способность • Esc — курсор • R — новый бой\nГерой 1: метка с 6 м и замедление на 5 с → Q → Герой 2: удар с 2.4 м\nМетка + удар: 60 вместо 35 урона. Оранжевый страж готовит атаку."
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	status = Label.new()
	status.position = Vector2(18, 165)
	status.add_theme_font_size_override("font_size", 24)
	hud.add_child(status)
	update_status()

func configure_input() -> void:
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", click)
	var bindings := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE, "release_mouse": KEY_ESCAPE, "reset": KEY_R, "switch_character": KEY_Q, "ability": KEY_E}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		restart_battle()

func restart_battle() -> void:
	player.reset_combat()
	enemy.reset_combat()
	update_status()

func _process(_delta: float) -> void:
	update_status()

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

func block(at: Vector3, size: Vector3, color: Color) -> void:
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
