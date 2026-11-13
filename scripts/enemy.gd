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
			var direction := Vector3(offset.x, 0, offset.z).normalized()
			velocity.x = direction.x * 2.8
			velocity.z = direction.z * 2.8
	material.albedo_color = Color("ffbe62") if windup > 0 else Color("ca6478")
	move_and_slide()
	if position.y < -12:
		position = home

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	if health == 0:
		windup = 0
		velocity = Vector3.ZERO
		visible = false
	health_changed.emit()

func reset_combat() -> void:
	health = MAX_HEALTH
	windup = 0
	cooldown = 0
	velocity = Vector3.ZERO
	position = home
	visible = true
	health_changed.emit()
