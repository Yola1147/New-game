extends RefCounted

# Arena-only prototype: the reward is a test counter, not currency or canon.
signal changed
enum Stage { NOT_STARTED, DEFEAT_GUARD, INSPECT_STATION, COMPLETED }
var stage := Stage.NOT_STARTED
var rewards := 0

func accept() -> void:
	if stage != Stage.NOT_STARTED:
		return
	stage = Stage.DEFEAT_GUARD
	changed.emit()

func observe_guard(defeated: bool) -> void:
	if stage == Stage.DEFEAT_GUARD and defeated:
		stage = Stage.INSPECT_STATION
		changed.emit()

func inspect(alive: bool, nearby: bool, guard_defeated: bool) -> void:
	if stage != Stage.INSPECT_STATION or not alive or not nearby or not guard_defeated:
		return
	stage = Stage.COMPLETED
	rewards += 1
	changed.emit()

func reset() -> void:
	stage = Stage.NOT_STARTED
	rewards = 0
	changed.emit()

func journal_text() -> String:
	var objectives := [
		"F — получить поручение",
		"Поручение получено. Цель: победить стража",
		"Цель: осмотреть бирюзовый маркер станции · G рядом с ним",
		"Поручение выполнено: станция осмотрена",
	]
	return "Журнал · Исследовать станцию (прототип)\n%s\nТестовых наград: %d · R — новый бой · T — сброс боя и квеста" % [objectives[stage], rewards]
