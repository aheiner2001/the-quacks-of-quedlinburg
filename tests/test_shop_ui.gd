class_name TestShopUI
extends RefCounted

static func run() -> int:
	var failures := 0
	var packed := load("res://node_2d.tscn") as PackedScene
	failures += AssertUtil.truthy(packed != null, "shop scene loads")
	if packed == null:
		return failures

	var shop := packed.instantiate()
	failures += AssertUtil.truthy(shop.get_script() != null, "shop script compiles")
	var expected_nodes := {
		"EvaluationPanel/TakeVPButton": Button,
		"EvaluationPanel/GoShopButton": Button,
		"EvaluationPanel/ConvertCoinsButton": Button,
		"EvaluationPanel/ConvertRubiesButton": Button,
		"EvaluationPanel/DoneButton": Button,
		"EvaluationPanel/StatusLabel": Label,
		"EvaluationPanel/WhiteShop": ItemList,
		"FlaskConfirmDialog": AcceptDialog,
	}
	for node_path: String in expected_nodes:
		var node := shop.get_node_or_null(node_path)
		failures += AssertUtil.truthy(node != null, "shop has %s" % node_path)
		if node:
			failures += AssertUtil.truthy(
				is_instance_of(node, expected_nodes[node_path]),
				"%s has expected type" % node_path
			)

	var root: Window = Engine.get_main_loop().root
	var session: Node = root.get_node("GameSession")
	session.call("start_local", 1)
	var controller := session.get("controller") as PhaseController
	controller.stop_active()
	root.add_child(shop)
	failures += AssertUtil.truthy(
		shop.get_node("EvaluationPanel").visible,
		"evaluation panel visible during evaluation"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel/WhiteShop").item_count,
		16,
		"shop list provides explicit purchase controls for every chip"
	)
	failures += AssertUtil.truthy(
		controller.state.players[0].chose_vp,
		"non-exploded evaluation cannot skip automatic vp"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel/DoneButton").disabled,
		false,
		"done is available after mandatory vp is granted"
	)
	controller.state.players[0].coins = 30
	controller.go_shop_active()
	shop.call("_refresh_evaluation")
	shop.get_node("PumpkinShelf").pressed.emit()
	failures += AssertUtil.eq(
		controller.state.players[0].purchases.size(),
		0,
		"browsing a shelf does not purchase"
	)
	var pumpkin_skus: Array[String] = []
	var pumpkin_buy_row := shop.get_node_or_null("Pumpkin/BuyRow")
	failures += AssertUtil.truthy(pumpkin_buy_row != null, "pumpkin panel has buy row")
	if pumpkin_buy_row:
		for button: Button in pumpkin_buy_row.get_children():
			pumpkin_skus.append(str(button.get_meta("sku")))
	failures += AssertUtil.truthy(
		"pumpkin_1" in pumpkin_skus,
		"pumpkin panel offers pumpkin 1"
	)
	failures += AssertUtil.truthy(
		"pumpkin_6" in pumpkin_skus,
		"pumpkin panel offers pumpkin 6"
	)
	var pumpkin_index := -1
	var mandrake_index := -1
	var poots_index := -1
	for index in shop.get_node("EvaluationPanel/WhiteShop").item_count:
		var sku: String = shop.get_node("EvaluationPanel/WhiteShop").get_item_metadata(index)
		if sku == "pumpkin_1":
			pumpkin_index = index
		elif sku == "mandrake_1":
			mandrake_index = index
		elif sku == "poots_1":
			poots_index = index
	failures += AssertUtil.truthy(pumpkin_index >= 0, "pumpkin has explicit buy entry")
	if pumpkin_index >= 0:
		failures += AssertUtil.eq(
			shop.get_node("EvaluationPanel/WhiteShop").is_item_disabled(pumpkin_index),
			false,
			"round 1 pumpkin buy entry enabled"
		)
		shop.call("_on_white_shop_item_clicked", pumpkin_index, Vector2.ZERO, MOUSE_BUTTON_LEFT)
		failures += AssertUtil.eq(
			controller.state.players[0].purchases,
			["pumpkin_1"],
			"explicit list click purchases pumpkin"
		)
	failures += AssertUtil.truthy(mandrake_index >= 0, "mandrake has explicit buy entry")
	if mandrake_index >= 0:
		failures += AssertUtil.truthy(
			shop.get_node("EvaluationPanel/WhiteShop").is_item_disabled(mandrake_index),
			"round 2 buy entry locked"
		)
	failures += AssertUtil.truthy(poots_index >= 0, "poots has explicit buy entry")
	if poots_index >= 0:
		failures += AssertUtil.truthy(
			shop.get_node("EvaluationPanel/WhiteShop").is_item_disabled(poots_index),
			"round 3 buy entry locked"
		)
	var player: PlayerState = controller.state.players[0]
	player.flask_full = false
	player.rubies = 2
	var purchases_before_flask := player.purchases.duplicate()
	shop.call("_refresh_evaluation")
	shop.get_node("TextureButton").pressed.emit()
	var flask_dialog := shop.get_node_or_null("FlaskConfirmDialog")
	failures += AssertUtil.truthy(flask_dialog != null, "shop has flask confirmation")
	failures += AssertUtil.truthy(
		flask_dialog != null and flask_dialog.visible,
		"flask opens ruby confirmation"
	)
	failures += AssertUtil.eq(
		player.purchases,
		purchases_before_flask,
		"flask does not use a coin market purchase"
	)
	if flask_dialog:
		flask_dialog.confirmed.emit()
		failures += AssertUtil.truthy(player.flask_full, "flask confirmation refills flask")
		failures += AssertUtil.eq(player.rubies, 0, "flask confirmation spends two rubies")

	player.coins = 3
	shop.call("_on_done_pressed")
	failures += AssertUtil.truthy(
		"unspent coins" in shop.get_node("EvaluationPanel/StatusLabel").text.to_lower(),
		"done warns about unspent coins"
	)

	controller.state.round = 9
	controller.state.begin_evaluation()
	shop.call("_refresh_evaluation")
	failures += AssertUtil.eq(shop.get_node("PumpkinShelf").visible, false, "shop hidden round 9")
	failures += AssertUtil.truthy(
		shop.get_node("EvaluationPanel/ConvertCoinsButton").visible,
		"coin conversion shown round 9"
	)
	root.remove_child(shop)
	shop.free()
	return failures
