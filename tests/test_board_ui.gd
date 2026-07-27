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
	}
	for node_name: String in expected_nodes:
		var node := board.get_node_or_null(node_name)
		failures += AssertUtil.truthy(node != null, "board has %s" % node_name)
		if node:
			failures += AssertUtil.truthy(
				is_instance_of(node, expected_nodes[node_name]),
				"%s has expected type" % node_name
			)

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
	controller.use_flask_active()
	failures += AssertUtil.eq(
		board.get_node("PlacementsList").item_count,
		0,
		"flask use clears stale placement list entry"
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
	return failures
