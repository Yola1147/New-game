extends CharacterBody3D

signal health_changed
const MAX_HEALTH := 100
var health := MAX_HEALTH
var target: CharacterBody3D
var windup := 0.0
var cooldown := 0.0
var attack_direction := Vector3.FORWARD
var material: StandardMaterial3D
var home := Vector3(0, 1, -10)
var navigation := AStarGrid2D.new()
var navigation_ready := false
var route := PackedVector3Array()
var repath_time := 0.0

# Prototype: ground-level navigation for the current static arena only.
func build_navigation() -> void:
	navigation.region = Rect2i(-30, -30, 61, 61)
	navigation.cell_size = Vector2(0.5, 0.5)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.6, 1.2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	for x in range(-30, 31):
		for z in range(-30, 31):
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x * 0.5, 0.9, z * 0.5))
			navigation.set_point_solid(Vector2i(x, z), not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty())
	navigation_ready = true

func navigation_cell(at: Vector3) -> Vector2i:
	var cell := Vector2i(roundi(at.x * 2), roundi(at.z * 2))
	if navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell):
		return cell
	# A capsule can stand closer to a column than the conservative grid permits.
	# Project only locally, with line of sight, so enclosed targets stay unreachable.
	var best := Vector2i(10000, 10000)
	var distance := 0.9
	for x in range(cell.x - 2, cell.x + 3):
		for z in range(cell.y - 2, cell.y + 3):
			var candidate := Vector2i(x, z)
			if not navigation.is_in_boundsv(candidate) or navigation.is_point_solid(candidate):
				continue
			var point := Vector3(x * 0.5, at.y, z * 0.5)
			var separation := at.distance_to(point)
			if separation >= distance:
				continue
			var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, point + Vector3.UP * 0.8, 1)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				best = candidate
				distance = separation
	return best

func pursuit_direction(delta: float) -> Vector3:
	if not navigation_ready:
		build_navigation()
	repath_time -= delta
	if repath_time <= 0:
		repath_time = 0.4
		route.clear()
		var start := navigation_cell(global_position)
		var goal := navigation_cell(target.global_position)
		if absf(target.global_position.y) < 0.7 and navigation.is_in_boundsv(start) and navigation.is_in_boundsv(goal):
			if not navigation.is_point_solid(start) and not navigation.is_point_solid(goal):
				for point in navigation.get_point_path(start, goal):
					route.append(Vector3(point.x, 0, point.y))
				if not route.is_empty() and Vector2(global_position.x, global_position.z).distance_to(Vector2(start) * 0.5) < 0.36:
					route.remove_at(0)
	while not route.is_empty():
		var offset := route[0] - Vector3(global_position.x, 0, global_position.z)
		if offset.length() > 0.15:
			return offset.normalized()
		route.remove_at(0)
	return Vector3.ZERO

func clear_pursuit() -> void:
	route.clear()
	repath_time = 0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 1.6
	collider.shape = shape
	collider.position.y = 0.8
	add_child(collider)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.5
	capsule.height = 1.6
	mesh.mesh = capsule
	mesh.position.y = 0.8
	material = StandardMaterial3D.new()
	material.albedo_color = Color("ca6478")
	mesh.material_override = material
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	cooldown = maxf(0, cooldown - delta)
	velocity.x = 0
	velocity.z = 0
	if not is_on_floor():
		velocity.y -= 20 * delta
	if is_instance_valid(target) and target.health > 0:
		var offset := target.global_position - global_position
		if windup > 0:
			windup = maxf(0, windup - delta)
			if windup == 0:
				if offset.length() < 2.1 and attack_direction.dot(offset.normalized()) > 0.5:
					var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, target.global_position + Vector3.UP, 1)
					if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
						target.take_damage(20)
				cooldown = 1.0
		elif offset.length() < 1.8 and cooldown == 0:
			windup = 0.65
			attack_direction = offset.normalized()
		elif offset.length() < 11 and offset.length() > 1.5:
			var direction := pursuit_direction(delta)
			velocity.x = direction.x * 2.8
			velocity.z = direction.z * 2.8
		else:
			clear_pursuit()
	else:
		clear_pursuit()
	material.albedo_color = Color("ffbe62") if windup > 0 else Color("ca6478")
	move_and_slide()
	if position.y < -12:
		position = home

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	if health == 0:
		clear_pursuit()
		windup = 0
		velocity = Vector3.ZERO
		visible = false
	health_changed.emit()

func reset_combat() -> void:
	clear_pursuit()
	health = MAX_HEALTH
	windup = 0
	cooldown = 0
	velocity = Vector3.ZERO
	position = home
	visible = true
	health_changed.emit()
