extends Node3D

const Player = preload("res://scripts/player.gd")
var player: CharacterBody3D

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
	var hud := CanvasLayer.new()
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	hud.add_child(panel)
	var label := Label.new()
	label.text = "NEW GAME · Испытательная арена\nWASD — движение • Мышь — камера • Пробел — прыжок\nEsc — курсор • R — вернуться на старт\nПроверьте платформы и обход колонн. Боевая система — следующий этап."
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)

func configure_input() -> void:
	var bindings := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE, "release_mouse": KEY_ESCAPE, "reset": KEY_R}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)

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
