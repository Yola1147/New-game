extends RefCounted

# Prototype single checkpoint slot; never deserialize executable objects.
const PATH := "user://prologue.json"
const VERSION := 1

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != VERSION:
		return false
	for field in ["active", "hp", "reserve_hp", "stage", "rewards"]:
		var value: Variant = data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)):
			return false
	if not int(data.active) in [0, 1] or data.hp < 0 or data.hp > 100 or data.reserve_hp < 0 or data.reserve_hp > 100 or data.hp + data.reserve_hp <= 0:
		return false
	if data.stage < 0 or data.stage > 5 or not int(data.rewards) in [0, 1]:
		return false
	for field in ["guard", "door", "final_guard", "owned", "equipped"]:
		if not data.get(field) is bool:
			return false
	if data.final_guard and not (data.guard and data.door):
		return false
	# Completed quests can coexist with replayed battles (R).
	if (data.stage == 5) != (data.rewards == 1) or data.owned != (data.rewards == 1) or (data.equipped and not data.owned):
		return false
	return true

static func read_slot(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 8192:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not valid(json.data):
		return {}
	return json.data

static func write_slot(data: Dictionary, path: String = PATH) -> bool:
	if not valid(data):
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return false
	return DirAccess.rename_absolute(temporary, path) == OK

static func clear_slot(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(path) == OK
