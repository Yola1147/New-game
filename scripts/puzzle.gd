extends Node3D

# Technical interaction demo only; no story or canonical magic rules.
var gate: StaticBody3D
var opened := false
var mark_time := 0.0
var label: Label3D
var material: StandardMaterial3D

func _ready() -> void:
	add_to_group("ability_mechanisms")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 1.2, 0.7)
	mesh.mesh = box
	mesh.position.y = 0.6
	material = StandardMaterial3D.new()
	mesh.material_override = material
	add_child(mesh)
	label = Label3D.new()
	label.position = Vector3(-0.6, 2.2, 0.8)
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	update_hint()

func activate(character: int) -> void:
	if opened:
		return
	if character == 0:
		mark_time = 5.0
	elif character == 1 and mark_time > 0:
		opened = true
		mark_time = 0
		set_gate_open(true)
	update_hint()

func _physics_process(delta: float) -> void:
	mark_time = maxf(0, mark_time - delta)
	update_hint()

func set_gate_open(value: bool) -> void:
	gate.visible = not value
	gate.get_child(0).set_deferred("disabled", value)
	# Geometry changed: rebuild the guard's grid on its next pursuit tick.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.navigation_ready = false
		enemy.clear_pursuit()

func reset_puzzle() -> void:
	opened = false
	mark_time = 0
	set_gate_open(false)
	update_hint()

func update_hint() -> void:
	material.albedo_color = Color("65cfc4") if opened else (Color("b99aea") if mark_time > 0 else Color("c9be91"))
	label.text = "МЕХАНИЗМ · ПРОТОТИП\n" + ("Открыто" if opened else ("Метка: %.1f с" % mark_time if mark_time > 0 else "E → Q → E"))

func hint_text() -> String:
	if opened:
		return "Механизм · Прототип: проход открыт\nR сохраняет проход · T сбрасывает всю попытку"
	if mark_time > 0:
		return "Механизм · Метка: %.1f с\nQ → E героя 2 с 2,4 м, лицом к механизму" % mark_time
	return "Механизм · Прототип: открыть центральный проход\nE героя 1 с 6 м → Q → E героя 2 с 2,4 м за 5 с\nСмотрите на механизм. Не успели? Повторите после отката (6 с)."
