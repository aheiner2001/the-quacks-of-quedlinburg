class_name TestPhaseController
extends RefCounted

static func run() -> int:
	var failures := 0
	var controller := PhaseController.new()
	controller.setup(1, 99)
	controller.begin_round()
	failures += AssertUtil.eq(controller.state.phase, "potions", "phase potions")
	controller.stop_active()
	failures += AssertUtil.eq(
		controller.state.phase,
		"evaluation",
		"auto eval after only player stops"
	)
	controller.free()
	return failures
