extends QuickTimeEvent

func start(ally: AllyBattler) -> void:
	super.start(ally)
	ally.guard()
	finished.emit()
