# Reproducible local/CI run:
# /opt/homebrew/bin/godot --headless --path . --import
# /opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd
extends SceneTree

const TestBoardUI = preload("res://tests/test_board_ui.gd")
const TestShopUI = preload("res://tests/test_shop_ui.gd")
const TestProgressTrackUI = preload("res://tests/test_progress_track_ui.gd")
const TestFullLoop = preload("res://tests/test_full_loop.gd")
const TestSupplyScaler = preload("res://tests/test_supply_scaler.gd")
const TestMainMenu = preload("res://tests/test_main_menu.gd")
const TestBonusDie = preload("res://tests/test_bonus_die.gd")
const TestChipEffects = preload("res://tests/test_chip_effects.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	failures += TestChip.run()
	failures += TestBag.run()
	failures += TestPot.run()
	failures += TestChipEffects.run()
	failures += TestPotions.run()
	failures += TestMarket.run()
	failures += TestSupplyScaler.run()
	failures += TestMainMenu.run()
	failures += TestBonusDie.run()
	failures += TestGameState.run()
	failures += TestPhaseController.run()
	failures += TestBoardUI.run()
	failures += TestShopUI.run()
	failures += TestProgressTrackUI.run()
	failures += TestFullLoop.run()
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
