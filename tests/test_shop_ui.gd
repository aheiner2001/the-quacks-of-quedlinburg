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
		"Button": Button,
		"EvalEntryScreen": EvalEntryScreen,
		"EvalEntryScreen/TakeVPButton": Button,
		"EvalEntryScreen/GoShopButton": Button,
		"EvalEntryScreen/ContinueButton": Button,
		"EvaluationPanel/DoneButton": Button,
		"EvaluationPanel/StatusLabel": Label,
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
	controller.finish_bonus_die_phase()
	root.add_child(shop)
	failures += AssertUtil.eq(controller.state.phase, "evaluation", "post-brew phase is evaluation")
	failures += AssertUtil.truthy(
		shop.get_node("EvalEntryScreen").visible,
		"eval entry screen visible during evaluation"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel").visible,
		false,
		"shop panel hidden until continue into shop"
	)
	var pumpkin_shelf := shop.get_node("PumpkinShelf") as BaseButton
	failures += AssertUtil.eq(
		pumpkin_shelf.visible,
		false,
		"pumpkin shelf is hidden before entering the shop"
	)
	failures += AssertUtil.eq(
		pumpkin_shelf.disabled,
		true,
		"pumpkin shelf is disabled before entering the shop"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel/WhiteShop").visible,
		false,
		"white shop stays hidden (no white token sales)"
	)
	failures += AssertUtil.truthy(
		controller.state.players[0].chose_vp,
		"non-exploded evaluation cannot skip automatic vp"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvalEntryScreen/ContinueButton").disabled,
		true,
		"eval continue stays gated until go-shop is chosen"
	)
	var player: PlayerState = controller.state.players[0]
	failures += AssertUtil.eq(
		shop.get_node("TextureButton").visible,
		false,
		"flask control hidden on eval-entry screen"
	)
	failures += AssertUtil.eq(
		shop.get_node("backgorund").visible,
		false,
		"shop background hidden on eval-entry screen"
	)

	controller.go_shop_active()
	shop.call("_refresh_evaluation")
	failures += AssertUtil.eq(controller.state.phase, "evaluation", "go shop stays on eval entry")
	failures += AssertUtil.eq(
		pumpkin_shelf.visible,
		false,
		"shelves stay hidden until continue"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvalEntryScreen/ContinueButton").disabled,
		false,
		"eval continue enabled after choosing shop"
	)
	controller.continue_to_shop_active()
	shop.call("_refresh_evaluation")
	failures += AssertUtil.eq(controller.state.phase, "shop", "continue enters shop phase")
	failures += AssertUtil.eq(
		shop.get_node("EvalEntryScreen").visible,
		false,
		"eval entry hides in shop phase"
	)
	failures += AssertUtil.eq(
		shop.get_node("backgorund").visible,
		true,
		"shop background appears after continue"
	)
	player.flask_full = false
	player.rubies = 2
	shop.call("_refresh_evaluation")
	failures += AssertUtil.eq(
		shop.get_node("TextureButton").disabled,
		false,
		"flask refill is enabled in shop phase"
	)
	shop.get_node("TextureButton").pressed.emit()
	var flask_dialog := shop.get_node_or_null("FlaskConfirmDialog")
	failures += AssertUtil.truthy(
		flask_dialog != null and flask_dialog.visible,
		"shop flask refill opens ruby confirmation"
	)
	if flask_dialog:
		flask_dialog.confirmed.emit()
	failures += AssertUtil.truthy(player.flask_full, "shop refill fills flask")
	failures += AssertUtil.eq(player.rubies, 0, "shop refill spends two rubies")
	failures += AssertUtil.eq(
		pumpkin_shelf.visible,
		true,
		"pumpkin shelf is visible after entering the shop"
	)
	failures += AssertUtil.eq(
		pumpkin_shelf.disabled,
		false,
		"pumpkin shelf is enabled after entering the shop"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel/DoneButton").visible,
		true,
		"done is visible after choosing shop"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel/WhiteShop").visible,
		false,
		"white shop never opens in the shop"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel/DoneButton").disabled,
		false,
		"done is enabled when no shop purchase is affordable"
	)
	failures += AssertUtil.eq(
		shop.get_node("Button").disabled,
		false,
		"continue matches done when no purchase is affordable"
	)
	failures += AssertUtil.eq(
		controller.state.players[0].evaluation_done,
		false,
		"shop does not auto-finish when no purchase is affordable"
	)
	var original_market: Dictionary = controller.state.market.duplicate(true)
	for sku: String in controller.state.market:
		var entry: Dictionary = controller.state.market[sku]
		entry["cost"] = 1 if sku == "pumpkin_1" else 99
		controller.state.market[sku] = entry
	player.coins = 1
	shop.call("_refresh_evaluation")
	failures += AssertUtil.eq(
		controller.state.can_buy(0, "white_1"),
		false,
		"white tokens cannot be bought"
	)
	failures += AssertUtil.eq(
		controller.state.can_buy(0, "pumpkin_1"),
		true,
		"shelf-only affordable purchase remains reachable"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel/DoneButton").disabled,
		true,
		"done remains gated while a shelf purchase is affordable"
	)
	failures += AssertUtil.eq(
		shop.get_node("Button").disabled,
		true,
		"continue remains gated while a shelf purchase is affordable"
	)
	shop.get_node("PumpkinShelf").pressed.emit()
	var afford_row := shop.get_node_or_null("Pumpkin/BuyRow") as ShopBuyRow
	var pumpkin_option := afford_row.find_option("pumpkin_1") if afford_row else null
	failures += AssertUtil.truthy(pumpkin_option != null, "pumpkin shelf offers pumpkin 1")
	if pumpkin_option:
		pumpkin_option.pressed.emit()
		failures += AssertUtil.eq(
			player.purchases,
			["pumpkin_1"],
			"shelf buy purchases an affordable chip"
		)
	controller.state.market = original_market
	player.purchases.clear()
	controller.state.players[0].coins = 30
	shop.call("_refresh_evaluation")
	shop.get_node("PumpkinShelf").pressed.emit()
	failures += AssertUtil.eq(
		controller.state.players[0].purchases.size(),
		0,
		"browsing a shelf does not purchase"
	)
	var pumpkin_skus: Array[String] = []
	var pumpkin_buy_row := shop.get_node_or_null("Pumpkin/BuyRow") as ShopBuyRow
	failures += AssertUtil.truthy(pumpkin_buy_row != null, "pumpkin panel has buy row")
	if pumpkin_buy_row:
		pumpkin_skus = pumpkin_buy_row.skus()
	failures += AssertUtil.truthy(
		"pumpkin_1" in pumpkin_skus,
		"pumpkin panel offers pumpkin 1"
	)
	failures += AssertUtil.truthy(
		"pumpkin_6" in pumpkin_skus,
		"pumpkin panel offers pumpkin 6"
	)
	if pumpkin_buy_row:
		var pumpkin_button := pumpkin_buy_row.option_at(0)
		pumpkin_button.pressed.emit()
		failures += AssertUtil.eq(
			player.purchases,
			["pumpkin_1"],
			"pumpkin buy row press purchases chip"
		)
		failures += AssertUtil.eq(
			shop.get_node("EvaluationPanel/DoneButton").disabled,
			true,
			"done stays disabled after one purchase with an affordable buy remaining"
		)
		failures += AssertUtil.eq(
			shop.get_node("Button").disabled,
			true,
			"continue stays disabled after one purchase with an affordable buy remaining"
		)
		failures += AssertUtil.eq(
			pumpkin_buy_row.option_count(),
			2,
			"pumpkin buy row keeps fixed slots after purchase"
		)
	shop.get_node("GaryInfo").pressed.emit()
	var gary_buy_row := shop.get_node_or_null("Gary/BuyRow") as ShopBuyRow
	failures += AssertUtil.truthy(gary_buy_row != null, "gary panel has buy row")
	if gary_buy_row:
		var gary_button := gary_buy_row.option_at(0)
		gary_button.pressed.emit()
		failures += AssertUtil.eq(
			controller.state.players[0].purchases,
			["pumpkin_1", "gary_1"],
			"gary buy row purchases second distinct chip"
		)
		failures += AssertUtil.eq(
			shop.get_node("EvaluationPanel/DoneButton").disabled,
			false,
			"done is enabled after two purchases"
		)
		failures += AssertUtil.eq(
			shop.get_node("Button").disabled,
			false,
			"continue is enabled after two purchases"
		)
	player.flask_full = false
	player.rubies = 2
	var purchases_before_flask := player.purchases.duplicate()
	shop.call("_refresh_evaluation")
	shop.get_node("TextureButton").pressed.emit()
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
	shop.call("_on_done_pressed")
	controller.state.begin_evaluation()
	controller.go_shop_active()
	controller.continue_to_shop_active()
	shop.call("_refresh_evaluation")
	player.coins = 3
	shop.call("_on_done_pressed")
	failures += AssertUtil.truthy(
		"buy another chip" in shop.get_node("EvaluationPanel/StatusLabel").text.to_lower(),
		"done handler cannot bypass purchase gating on second shop visit"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel/DoneButton").disabled,
		true,
		"done is disabled while a second purchase is affordable"
	)
	failures += AssertUtil.eq(
		shop.get_node("Button").disabled,
		true,
		"continue is disabled while a second purchase is affordable"
	)

	controller.state.round = 9
	controller.state.begin_evaluation()
	shop.call("_refresh_evaluation")
	failures += AssertUtil.eq(shop.get_node("PumpkinShelf").visible, false, "shop hidden round 9")
	failures += AssertUtil.truthy(
		shop.get_node("EvalEntryScreen").visible,
		"eval entry shown round 9"
	)
	failures += AssertUtil.truthy(
		shop.get_node("EvalEntryScreen/ConvertCoinsButton").visible,
		"coin conversion shown round 9 on eval entry"
	)
	root.remove_child(shop)
	shop.free()
	failures += _test_shop_overlay_done_stays_on_board()
	return failures

static func _test_shop_overlay_done_stays_on_board() -> int:
	var failures := 0
	var packed := load("res://board.tscn") as PackedScene
	var board := packed.instantiate()
	var root: Window = Engine.get_main_loop().root
	var session: Node = root.get_node("GameSession")
	session.call("start_local", 1)
	var controller := session.get("controller") as PhaseController
	root.add_child(board)
	controller.stop_active()
	controller.finish_bonus_die_phase()
	failures += AssertUtil.eq(
		controller.state.phase, "evaluation", "overlay shop test enters evaluation"
	)
	var overlay := board.get_node_or_null("ShopOverlay")
	failures += AssertUtil.truthy(overlay != null and overlay.visible, "shop overlay shown")
	if overlay == null or overlay.get_child_count() == 0:
		root.remove_child(board)
		board.free()
		return failures
	var shop: Node = overlay.get_child(0)
	failures += AssertUtil.truthy(
		shop.get_node("EvalEntryScreen").visible,
		"eval entry shown on overlay during evaluation"
	)
	controller.go_shop_active()
	controller.continue_to_shop_active()
	shop.call("_refresh_evaluation")
	controller.state.players[0].coins = 0
	shop.call("_on_done_pressed")
	failures += AssertUtil.eq(
		controller.state.phase, "potions", "done continues into next potions round"
	)
	failures += AssertUtil.truthy(
		is_instance_valid(board) and board.is_inside_tree(),
		"done from overlay does not leave board"
	)
	failures += AssertUtil.eq(
		overlay.visible, false, "done hides shop overlay for potions"
	)
	failures += AssertUtil.truthy(
		get_tree_current_is_not_shop(shop),
		"done does not promote shop to current scene"
	)
	root.remove_child(board)
	board.free()
	return failures

static func get_tree_current_is_not_shop(shop: Node) -> bool:
	var tree := shop.get_tree()
	if tree == null:
		return true
	return tree.current_scene != shop
