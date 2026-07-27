extends SceneTree

const TestBoardUI = preload("res://tests/test_board_ui.gd")

func _init() -> void:
	var failures := 0
	failures += TestChip.run()
	failures += TestBag.run()
	failures += TestPot.run()
	failures += TestPotions.run()
	failures += TestMarket.run()
	failures += TestGameState.run()
	failures += TestPhaseController.run()
	failures += TestBoardUI.run()
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
