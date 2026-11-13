extends RefCounted

# Greybox station only: all dimensions, materials and signs are temporary.
# The local mechanism is a technical prototype, not a canonical magic rule.
static func build(world: Node3D) -> void:
	world.block(Vector3(0, -0.5, 0), Vector3(32, 1, 32), Color("526c68"))
	for x in [-16.0, 16.0]:
		world.block(Vector3(x, 1.5, 0), Vector3(1, 4, 33), Color("58647c"))
	for z in [-16.0, 16.0]:
		world.block(Vector3(0, 1.5, z), Vector3(32, 4, 1), Color("58647c"))
	# Entrance portal behind the spawn; the entire route stays on one solid floor.
	for x in [-3.5, 3.5]:
		world.block(Vector3(x, 1.8, 11), Vector3(1, 3.6, 1), Color("8997a8"))
	world.block(Vector3(0, 3.5, 11), Vector3(8, 0.6, 1), Color("8997a8"))
	# Broken supports in the combat hall, with space to circle them.
	for point in [Vector3(8, 1.5, -8), Vector3(8, 1.5, 3), Vector3(-10, 1.5, 5)]:
		world.block(point, Vector3(2, 3, 2), Color("b3a5bd"))
	for point in [Vector3(-14, 0.5, -12), Vector3(13, 0.4, 10), Vector3(-13, 0.6, -2)]:
		world.block(point, Vector3(2, point.y * 2, 2), Color("8997a8"))
	# Rear room divider: a visibly sealed central door and a 3.5 m east bypass.
	world.block(Vector3(-9.25, 2, -6), Vector3(12.5, 4, 0.8), Color("58647c"))
	world.block(Vector3(11, 2, -6), Vector3(9, 4, 0.8), Color("58647c"))
	var gate: StaticBody3D = world.block(Vector3(0, 1.75, -6), Vector3(6, 3.5, 0.8), Color("a77c57"))
	world.block(Vector3(0, 3.75, -6), Vector3(6, 0.5, 0.8), Color("8997a8"))
	world.puzzle = preload("res://scripts/puzzle.gd").new()
	world.puzzle.gate = gate
	world.puzzle.position = Vector3(-2, 0, -4.5)
	world.add_child(world.puzzle)
	# Flat colour strips are wayfinding, not magical effects or puzzle objects.
	for z in [8.0, 5.0, 2.0, -1.0]:
		world.block(Vector3(0, 0.015, z), Vector3(1.4, 0.03, 1), Color("c9be91"))
	for z in [-3.0, -5.0, -7.0, -9.0]:
		world.block(Vector3(4.75, 0.015, z), Vector3(1.4, 0.03, 1), Color("c9be91"))
	world.block(Vector3(4, 0.025, -10), Vector3(3, 0.05, 3), Color("65cfc4"))
	signpost(world, Vector3(0, 3.9, 11), "ВХОД · РУИНЫ СТАНЦИИ\nВременная геометрия")
	signpost(world, Vector3(0, 2.8, -5.4), "ПРОХОД · МЕХАНИЗМ СЛЕВА\nОбход справа →")
	signpost(world, Vector3(4.75, 3, -6), "ОБХОД")
	signpost(world, Vector3(4, 2.5, -10), "МЕСТО НАХОДКИ · ПРОТОТИП\nG — осмотреть после победы")

static func signpost(world: Node3D, at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.position = at
	label.text = text
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world.add_child(label)
