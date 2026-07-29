class_name TestBoardUI
extends RefCounted

static func run() -> int:
	var failures := 0
	var packed := load("res://board.tscn") as PackedScene
	failures += AssertUtil.truthy(packed != null, "board scene loads")
	if packed == null:
		return failures

	var board := packed.instantiate()
	failures += AssertUtil.truthy(board.get_script() != null, "board script compiles")
	var expected_nodes := {
		"ActivePlayerLabel": Label,
		"WhiteSumLabel": Label,
		"FlaskLabel": Label,
		"DrawButton": Button,
		"StopButton": Button,
		"FlaskButton": Button,
		"HandoffLabel": Label,
		"PlacementsList": ItemList,
		"DrawStage": Node2D,
		"DrawStage/BagPlaceholder": TextureRect,
		"DrawStage/CauldronPlaceholder": TextureRect,
		"DrawStage/ChipFlight": TextureRect,
		"ExplosionRiskBar": ProgressBar,
		"RewardsBar": RichTextLabel,
		"ProgressTrack": Control,
		"TokenHistory": Control,
		"BonusDieModal": Control,
		"BonusDieModal/PlayerLabel": Label,
		"BonusDieModal/FaceTexture": TextureRect,
		"BonusDieModal/RewardLabel": Label,
		"BonusDieModal/RollButton": Button,
		"BonusDieModal/NextButton": Button,
		"CrowSkullModal": Control,
		"CrowSkullModal/ChipChoices": HBoxContainer,
		"CrowSkullModal/KeepNoneButton": Button,
		"MandrakeModal": Control,
		"MandrakeModal/ReturnWhiteButton": Button,
		"MandrakeModal/KeepWhiteButton": Button,
	}
	for node_name: String in expected_nodes:
		var node := board.get_node_or_null(node_name)
		failures += AssertUtil.truthy(node != null, "board has %s" % node_name)
		if node:
			failures += AssertUtil.truthy(
				is_instance_of(node, expected_nodes[node_name]),
				"%s has expected type" % node_name
			)

	var bonus_modal := board.get_node_or_null("BonusDieModal")
	if bonus_modal:
		failures += AssertUtil.eq(bonus_modal.visible, false, "bonus die modal starts hidden")
	var crow_modal := board.get_node_or_null("CrowSkullModal")
	if crow_modal:
		failures += AssertUtil.eq(crow_modal.visible, false, "crow modal starts hidden")
	var mandrake_modal := board.get_node_or_null("MandrakeModal")
	if mandrake_modal:
		failures += AssertUtil.eq(mandrake_modal.visible, false, "mandrake modal starts hidden")

	var gameboard := board.get_node_or_null("Gameboard")
	if gameboard:
		failures += AssertUtil.eq(gameboard.visible, false, "spiral board hidden")
	for child in board.get_children():
		if str(child.name).begins_with("stone"):
			failures += AssertUtil.eq(child.visible, false, "stone hidden")

	if failures == 0:
		failures += AssertUtil.truthy(
			board.get_node("DrawButton").pressed.is_connected(
				Callable(board, "_on_draw_pressed")
			),
			"draw button wired"
		)
		failures += AssertUtil.truthy(
			board.get_node("StopButton").pressed.is_connected(
				Callable(board, "_on_stop_pressed")
			),
			"stop button wired"
		)
		failures += AssertUtil.truthy(
			board.get_node("FlaskButton").pressed.is_connected(
				Callable(board, "_on_flask_pressed")
			),
			"flask button wired"
		)

	failures += AssertUtil.truthy(
		board.has_method("_update_explosion_risk"),
		"board exposes explosion risk update helper"
	)
	var cauldron := board.get_node_or_null("DrawStage/CauldronPlaceholder") as TextureRect
	if cauldron:
		failures += AssertUtil.truthy(
			cauldron.texture != null,
			"cauldron uses rune texture"
		)
	failures += AssertUtil.truthy(
		board.has_method("_texture_for_chip"),
		"board resolves chip textures for draw flight"
	)
	if board.has_method("_texture_for_chip"):
		var white_tex: Texture2D = board.call(
			"_texture_for_chip",
			Chip.make(Chip.ChipColor.WHITE, 1)
		)
		failures += AssertUtil.truthy(white_tex != null, "white 1 chip has texture")
	if board.has_method("_update_explosion_risk"):
		board.call("_update_explosion_risk", 12, true)
		var risk_bar := board.get_node("ExplosionRiskBar") as ProgressBar
		failures += AssertUtil.eq(risk_bar.value, 8.0, "risk bar clamps white sum to eight")
		failures += AssertUtil.eq(
			risk_bar.modulate,
			Color.RED,
			"exploded risk bar turns red"
		)

	var root: Window = Engine.get_main_loop().root
	var session: Node = root.get_node("GameSession")
	session.call("start_local", 2)
	var controller := session.get("controller") as PhaseController
	controller.state.players[0].bag = Bag.new()
	controller.state.players[0].bag.add(Chip.make(Chip.ChipColor.WHITE, 1))
	controller.state.players[0].bag.add(Chip.make(Chip.ChipColor.WHITE, 1))
	root.add_child(board)
	board.get_node("PlacementsList").add_item("stale placement")
	controller.draw_active()
	failures += AssertUtil.eq(
		board.get_node("TokenHistory").token_count(),
		controller.state.players[0].pot.placements.size(),
		"token history refreshes on draw"
	)
	failures += AssertUtil.eq(
		board.get_node("ProgressTrack").preview_space(),
		controller.state.players[0].pot.scoring_space(),
		"progress track refreshes on draw"
	)
	controller.use_flask_active()
	failures += AssertUtil.eq(
		board.get_node("PlacementsList").item_count,
		0,
		"flask use clears stale placement list entry"
	)
	failures += AssertUtil.eq(
		board.get_node("TokenHistory").token_count(),
		controller.state.players[0].pot.placements.size(),
		"token history refreshes on flask use"
	)

	var track := board.get_node("ProgressTrack")
	var history := board.get_node("TokenHistory")
	track.scroll_offset = 33.0
	failures += AssertUtil.eq(
		history.scroll_offset, 33.0, "scrolling track syncs history"
	)
	history.scroll_offset = 47.0
	failures += AssertUtil.eq(
		track.scroll_offset, 47.0, "scrolling history syncs track"
	)
	board.call("_on_exploded", 0)
	board.call("_on_active", 1)
	failures += AssertUtil.eq(
		board.get_node("HandoffLabel").text,
		"Player 1 exploded — now Player 2",
		"explosion survives handoff update"
	)
	root.remove_child(board)
	board.free()
	failures += _test_bonus_die_phase_shows_modal()
	failures += _test_bonus_die_modal_rolls_and_finishes()
	failures += _test_evaluation_shows_shop_overlay()
	failures += _test_potion_choice_modals_pause_actions()
	failures += _test_nested_crow_choice_stays_open()
	return failures

static func _test_bonus_die_phase_shows_modal() -> int:
	var failures := 0
	var packed := load("res://board.tscn") as PackedScene
	var board := packed.instantiate()
	var root: Window = Engine.get_main_loop().root
	var session: Node = root.get_node("GameSession")
	session.call("start_local", 2)
	var controller := session.get("controller") as PhaseController
	root.add_child(board)
	controller.state.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 4))
	controller.state.players[1].pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	controller.stop_active()
	controller.stop_active()
	failures += AssertUtil.eq(
		controller.state.phase, "bonus_die", "phase enters bonus die after both stop"
	)
	var modal := board.get_node_or_null("BonusDieModal")
	failures += AssertUtil.truthy(modal != null, "board has bonus die modal node")
	if modal:
		failures += AssertUtil.truthy(
			modal.visible, "board shows bonus die modal during bonus_die phase"
		)
		failures += AssertUtil.eq(
			modal.get_node("RollButton").disabled,
			false,
			"roll button enabled for eligible leader"
		)
	root.remove_child(board)
	board.free()
	return failures

static func _test_bonus_die_modal_rolls_and_finishes() -> int:
	var failures := 0
	var packed := load("res://ui/bonus_die_modal.tscn") as PackedScene
	failures += AssertUtil.truthy(packed != null, "bonus die modal scene loads")
	if packed == null:
		return failures
	var modal := packed.instantiate()
	var root: Window = Engine.get_main_loop().root
	var session: Node = root.get_node("GameSession")
	session.call("start_local", 2)
	var controller := session.get("controller") as PhaseController
	controller.state.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 4))
	controller.state.players[1].pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	controller.stop_active()
	controller.stop_active()
	root.add_child(modal)
	modal.open()
	failures += AssertUtil.truthy(modal.visible, "modal open() shows itself")
	failures += AssertUtil.eq(
		modal.get_node("FaceTexture").visible, false, "face hidden before rolling"
	)
	failures += AssertUtil.eq(
		modal.get_node("RewardLabel").visible, false, "reward hidden before rolling"
	)
	modal.get_node("RollButton").pressed.emit()
	failures += AssertUtil.eq(
		controller.state.bonus_die_index, 1, "rolling advances bonus die queue index"
	)
	failures += AssertUtil.truthy(
		modal.get_node("FaceTexture").visible, "face shown after rolling"
	)
	failures += AssertUtil.truthy(
		modal.get_node("FaceTexture").texture != null, "face texture resolves a die image"
	)
	var reward_label: Label = modal.get_node("RewardLabel")
	failures += AssertUtil.truthy(reward_label.visible, "reward shown after rolling")
	failures += AssertUtil.truthy(reward_label.text != "", "reward label has face text after rolling")
	modal.get_node("NextButton").pressed.emit()
	failures += AssertUtil.eq(
		controller.state.phase,
		"evaluation",
		"finishing the queue advances the controller to evaluation"
	)
	failures += AssertUtil.eq(modal.visible, false, "modal hides once bonus die phase finishes")
	root.remove_child(modal)
	modal.free()
	return failures

static func _test_evaluation_shows_shop_overlay() -> int:
	var failures := 0
	var packed := load("res://board.tscn") as PackedScene
	var board := packed.instantiate()
	var root: Window = Engine.get_main_loop().root
	var session: Node = root.get_node("GameSession")
	session.call("start_local", 2)
	var controller := session.get("controller") as PhaseController
	root.add_child(board)
	controller.state.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 4))
	controller.state.players[1].pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	controller.stop_active()
	controller.stop_active()
	failures += AssertUtil.eq(
		controller.state.phase, "bonus_die", "overlay test starts in bonus die"
	)
	controller.finish_bonus_die_phase()
	failures += AssertUtil.eq(
		controller.state.phase, "evaluation", "bonus die finish enters evaluation"
	)
	failures += AssertUtil.truthy(
		is_instance_valid(board) and board.is_inside_tree(),
		"board stays in tree on evaluation (no scene swap)"
	)
	var overlay := board.get_node_or_null("ShopOverlay")
	failures += AssertUtil.truthy(overlay != null, "board has ShopOverlay after evaluation")
	if overlay:
		failures += AssertUtil.truthy(
			overlay is CanvasLayer,
			"ShopOverlay is a CanvasLayer"
		)
		failures += AssertUtil.truthy(
			overlay.visible,
			"ShopOverlay visible during evaluation"
		)
		failures += AssertUtil.truthy(
			overlay.get_child_count() > 0,
			"ShopOverlay instances shop UI"
		)
	controller.end_turn_and_continue()
	failures += AssertUtil.eq(
		controller.state.phase, "potions", "continue returns to potions"
	)
	if overlay and is_instance_valid(overlay):
		failures += AssertUtil.eq(
			overlay.visible,
			false,
			"ShopOverlay hides when returning to potions"
		)
	failures += AssertUtil.truthy(
		is_instance_valid(board) and board.is_inside_tree(),
		"board remains after end_turn_and_continue"
	)
	if is_instance_valid(board) and board.is_inside_tree():
		root.remove_child(board)
		board.free()
	elif is_instance_valid(board):
		board.free()
	return failures

static func _test_potion_choice_modals_pause_actions() -> int:
	var failures := 0
	var packed := load("res://board.tscn") as PackedScene
	var board := packed.instantiate()
	var root: Window = Engine.get_main_loop().root
	var session: Node = root.get_node("GameSession")
	session.call("start_local", 1)
	var controller := session.get("controller") as PhaseController
	var player := controller.state.players[0]
	player.pending_crow_draws = [Chip.make(Chip.ChipColor.ORANGE, 1)]
	player.awaiting_crow_choice = true
	root.add_child(board)
	board.call("_refresh")
	failures += AssertUtil.truthy(
		board.get_node("CrowSkullModal").visible, "crow choice opens crow modal"
	)
	failures += AssertUtil.eq(board.get_node("DrawButton").disabled, true, "crow choice pauses draw")
	failures += AssertUtil.eq(board.get_node("StopButton").disabled, true, "crow choice pauses stop")
	failures += AssertUtil.eq(board.get_node("FlaskButton").disabled, true, "crow choice pauses flask")
	board.get_node("CrowSkullModal/KeepNoneButton").pressed.emit()

	player.awaiting_mandrake = true
	board.call("_refresh")
	failures += AssertUtil.truthy(
		board.get_node("MandrakeModal").visible, "mandrake choice opens mandrake modal"
	)
	board.get_node("MandrakeModal/KeepWhiteButton").pressed.emit()
	root.remove_child(board)
	board.free()
	return failures

static func _test_nested_crow_choice_stays_open() -> int:
	var failures := 0
	var packed := load("res://board.tscn") as PackedScene
	var board := packed.instantiate()
	var root: Window = Engine.get_main_loop().root
	var session: Node = root.get_node("GameSession")
	session.call("start_local", 1)
	var controller := session.get("controller") as PhaseController
	var player := controller.state.players[0]
	player.bag = Bag.new()
	player.bag.add(Chip.make(Chip.ChipColor.ORANGE, 1))
	player.pending_crow_draws = [Chip.make(Chip.ChipColor.BLUE, 1)]
	player.awaiting_crow_choice = true
	root.add_child(board)
	board.call("_refresh")
	var choices := board.get_node("CrowSkullModal/ChipChoices")
	choices.get_child(0).pressed.emit()
	failures += AssertUtil.truthy(
		board.get_node("CrowSkullModal").visible,
		"nested crow choice remains open after keeping blue"
	)
	root.remove_child(board)
	board.free()
	return failures
