class_name TestFlaskDrag
extends RefCounted

static func run() -> int:
	return _test_cauldron_path_resolves_from_board() + _test_drop_over_cauldron_emits()

static func _test_cauldron_path_resolves_from_board() -> int:
	var failures := 0
	var packed := load("res://board.tscn") as PackedScene
	failures += AssertUtil.truthy(packed != null, "board scene loads for flask drag")
	if packed == null:
		return failures

	var board := packed.instantiate()
	var flask := board.get_node("FlaskDrag") as FlaskDrag
	failures += AssertUtil.truthy(flask != null, "board has FlaskDrag")
	if flask == null:
		board.free()
		return failures

	var cauldron := flask.get_parent().get_node_or_null(flask.cauldron_path) as Control
	failures += AssertUtil.truthy(cauldron != null, "cauldron path resolves from board parent")
	if cauldron:
		failures += AssertUtil.eq(
			cauldron.name, "CauldronPlaceholder", "cauldron path targets placeholder"
		)
	board.free()
	return failures

static func _test_drop_over_cauldron_emits() -> int:
	var failures := 0
	var packed := load("res://board.tscn") as PackedScene
	if packed == null:
		return failures + 1

	var board := packed.instantiate()
	var root: Window = Engine.get_main_loop().root
	root.add_child(board)

	var flask := board.get_node("FlaskDrag") as FlaskDrag
	var cauldron := flask.get_parent().get_node_or_null(flask.cauldron_path) as Control
	failures += AssertUtil.truthy(cauldron != null, "cauldron found for drop test")
	if cauldron == null:
		root.remove_child(board)
		board.free()
		return failures

	var fired := [false]
	flask.dropped_on_cauldron.connect(func(): fired[0] = true)
	flask.set_enabled(true)

	var center := cauldron.get_global_rect().get_center()
	flask.call("_finish_drag", center)

	failures += AssertUtil.truthy(fired[0], "dropped_on_cauldron fires when pointer over cauldron")

	root.remove_child(board)
	board.free()
	return failures
