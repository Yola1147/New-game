extends RefCounted

# Prototype: one completion reward unlocks the team's training blade; no currency.
signal changed
enum Stage { NOT_STARTED, DEFEAT_GUARD, OPEN_PASSAGE, DEFEAT_REINFORCED, INSPECT_STATION, COMPLETED }
var stage := Stage.NOT_STARTED
var rewards := 0

func accept() -> void:
	if stage != Stage.NOT_STARTED:
		return
	stage = Stage.DEFEAT_GUARD
	changed.emit()

func observe_route(guard_defeated: bool, passage_open: bool, reinforced_defeated: bool) -> void:
	if stage == Stage.NOT_STARTED or stage == Stage.COMPLETED:
		return
	var next := Stage.DEFEAT_GUARD
	if guard_defeated:
		next = Stage.OPEN_PASSAGE
		if passage_open:
			next = Stage.INSPECT_STATION if reinforced_defeated else Stage.DEFEAT_REINFORCED
	if stage != next:
		stage = next
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
		"Цель: открыть проход · E героя 1 → Q → E героя 2 у механизма",
		"Цель: победить усиленного стража в дальней комнате",
		"Цель: найти Эхо памяти · G у бирюзовой площадки",
		"Поручение выполнено · Пролог завершён · G рядом — повтор записи",
	]
	return "Журнал · Исследовать станцию (прототип)\n%s\nТестовых наград: %d · R — новый бой · T — сброс боя и квеста" % [objectives[stage], rewards]
