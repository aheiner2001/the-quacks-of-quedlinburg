extends SceneTree

func _init() -> void:
	var failures := 0
	failures += TestChip.run()
	failures += TestBag.run()
	failures += TestPot.run()
	failures += TestPotions.run()
	failures += TestMarket.run()
	failures += TestGameState.run()
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
