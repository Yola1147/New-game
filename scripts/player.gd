extends CharacterBody3D

const SPEED := 6.0
const JUMP_SPEED := 7.5
const ACCELERATION := 22.0
var pivot: Node3D
var spring: SpringArm3D
var visual: Node3D
var spawn_position := Vector3(0, 2, 8)
var input_enabled := true

func _ready() -> void:
	collision_layer = 2
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	var mesh := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.8
	mesh.mesh = body_mesh
	mesh.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("67d9cf")
	mesh.material_override = material
	visual.add_child(mesh)
	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.2, 0.16, 0.32)
	marker.mesh = marker_mesh
	marker.position = Vector3(0, 1.45, -0.35)
	visual.add_child(marker)
	pivot = Node3D.new()
	pivot.position.y = 1.45
	add_child(pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 5.5
	spring.rotation.x = -0.25
	spring.collision_mask = 1
	spring.margin = 0.2
	pivot.add_child(spring)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 70
	spring.add_child(camera)
	if input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotation.y -= event.relative.x * 0.003
		spring.rotation.x = clampf(spring.rotation.x - event.relative.y * 0.003, -1.15, 0.65)
	if event.is_action_pressed("reset"):
		respawn()

func _physics_process(delta: float) -> void:
	var input_axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_enabled else Vector2.ZERO
	var direction := pivot.global_basis * Vector3(input_axis.x, 0, input_axis.y)
	direction.y = 0
	direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCELERATION * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	elif input_enabled and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_SPEED
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 12.0 * delta)
	move_and_slide()
	if global_position.y < -12:
		respawn()

func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
