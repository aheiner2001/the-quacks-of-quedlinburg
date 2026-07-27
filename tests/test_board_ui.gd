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

	board.free()
	return failures
