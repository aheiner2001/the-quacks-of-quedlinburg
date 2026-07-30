extends Node2D

const INFO_SHELVES := [
	"GaryInfo",
	"PumpkinShelf",
	"ShroomInfo",
	"SpiderShelf",
	"MothShelf",
	"MandrakeShelf",
	"Pootsshelf",
]
const FLASK_BUY_BUTTON := "TextureButton"
const SHELF_POPUPS := {
	"GaryInfo": "Gary",
	"PumpkinShelf": "Pumpkin",
	"ShroomInfo": "shroom",
	"SpiderShelf": "spider",
	"MothShelf": "Moth",
	"MandrakeShelf": "Mandrake",
	"Pootsshelf": "Poots",
}

var _unspent_coin_warning_player := -1

func _ready() -> void:
	for button_path in [
		"TextureButton",
		"GaryInfo",
		"Gary/garyexit",
		"PumpkinShelf",
		"Shopsign",
	]:
		setup_bottle_mask(get_node_or_null(button_path) as TextureButton)
	$Flame.play("flame")
	_wire_shop_buttons()
	_wire_buy_rows()
	_wire_eval_entry()
	var white_shop := get_node_or_null("EvaluationPanel/WhiteShop")
	if white_shop:
		white_shop.visible = false
	var pc := _controller()
	if pc == null or pc.state == null:
		$EvaluationPanel.visible = true
		$EvaluationPanel/StatusLabel.text = "Start a game from the main menu."
		return
	_refresh_evaluation()

func setup_bottle_mask(btn: TextureButton) -> void:
	if btn and btn.texture_normal:
		var img = btn.texture_normal.get_image()
		var bm = BitMap.new()
		bm.create_from_image_alpha(img)
		btn.texture_click_mask = bm

func _wire_shop_buttons() -> void:
	get_node(FLASK_BUY_BUTTON).visible = true

func _wire_eval_entry() -> void:
	var entry := _eval_entry()
	if entry == null:
		return
	if not entry.take_vp_pressed.is_connected(_on_take_vp_pressed):
		entry.take_vp_pressed.connect(_on_take_vp_pressed)
	if not entry.go_shop_pressed.is_connected(_on_go_shop_pressed):
		entry.go_shop_pressed.connect(_on_go_shop_pressed)
	if not entry.convert_coins_pressed.is_connected(_on_convert_coins_pressed):
		entry.convert_coins_pressed.connect(_on_convert_coins_pressed)
	if not entry.convert_rubies_pressed.is_connected(_on_convert_rubies_pressed):
		entry.convert_rubies_pressed.connect(_on_convert_rubies_pressed)
	if not entry.continue_pressed.is_connected(_on_eval_continue_pressed):
		entry.continue_pressed.connect(_on_eval_continue_pressed)

func _eval_entry() -> EvalEntryScreen:
	return get_node_or_null("EvalEntryScreen") as EvalEntryScreen

func _wire_buy_rows() -> void:
	for popup_name: String in SHELF_POPUPS.values():
		var row := get_node_or_null("%s/BuyRow" % popup_name)
		if row and row.has_signal("buy_pressed") and not row.buy_pressed.is_connected(_on_shop_item_pressed):
			row.buy_pressed.connect(_on_shop_item_pressed)

func _refresh_evaluation(message: String = "") -> void:
	var pc := _controller()
	if pc == null or pc.state == null:
		$EvaluationPanel.visible = false
		var entry_missing := _eval_entry()
		if entry_missing:
			entry_missing.visible = false
		_set_shop_chrome_visible(false)
		return
	var state := pc.state
	var entry := _eval_entry()
	if entry:
		entry.refresh(state, message)

	var in_shop := state.phase == "shop"
	var game_over := state.phase == "game_over"
	# Shop art/controls only after Continue leaves the eval-entry screen.
	_set_shop_chrome_visible(in_shop or game_over)
	$EvaluationPanel.visible = in_shop or game_over
	if game_over:
		_show_winners()
		return
	if not in_shop:
		_refresh_shop_controls(state.players[state.eval_player])
		return
	var player: PlayerState = state.players[state.eval_player]
	var status := "Round %d · Player %d · VP %d · Coins %d · Rubies %d" % [
		state.round,
		state.eval_player + 1,
		player.vp,
		player.coins,
		player.rubies,
	]
	if not message.is_empty():
		status += "\n" + message
	$EvaluationPanel/StatusLabel.text = status
	# Choice controls live on EvalEntryScreen — keep duplicates hidden on the shop panel.
	$EvaluationPanel/TakeVPButton.visible = false
	$EvaluationPanel/GoShopButton.visible = false
	$EvaluationPanel/ConvertCoinsButton.visible = false
	$EvaluationPanel/ConvertRubiesButton.visible = false
	if state.round != 9 and player.chose_shop:
		_update_done_buttons(
			player.purchases.size() >= 2
			or not state.has_affordable_buy(state.eval_player)
		)
	else:
		_update_done_buttons(player.chose_vp or player.chose_shop)
	_refresh_shop_controls(player)


## Hides the real shop scene chrome while phase == "evaluation" (eval-entry only).
func _set_shop_chrome_visible(show_shop: bool) -> void:
	for node_name: String in [
		"backgorund",
		"Shopsign",
		"Flame",
		"Button",
		"Settingicon",
		FLASK_BUY_BUTTON,
	]:
		var node := get_node_or_null(node_name)
		if node:
			node.visible = show_shop
	for node_name: String in INFO_SHELVES:
		var shelf := get_node_or_null(node_name)
		if shelf and not show_shop:
			shelf.visible = false

func _update_done_buttons(ready: bool) -> void:
	for button: BaseButton in [$EvaluationPanel/DoneButton, $Button]:
		button.visible = true
		button.disabled = not ready

func _refresh_shop_controls(player: PlayerState) -> void:
	var state := _controller().state
	var shop_open := (
		state.phase == "shop"
		and state.round != 9
		and player.chose_shop
		and not player.evaluation_done
	)
	for node_name: String in INFO_SHELVES:
		var button := get_node(node_name) as BaseButton
		button.visible = shop_open
		button.disabled = not shop_open
		if not shop_open:
			var popup := get_node(SHELF_POPUPS[node_name])
			popup.visible = false
			var buy_row := popup.get_node_or_null("BuyRow") as Control
			if buy_row:
				buy_row.visible = false
	var flask_button := get_node(FLASK_BUY_BUTTON) as BaseButton
	flask_button.visible = shop_open
	flask_button.disabled = (
		not shop_open
		or not _can_refill_flask()
		or player.flask_full
		or player.rubies < 2
	)
	# White boomberries are never sold — shelf ingredients only.
	var white_shop := get_node_or_null("EvaluationPanel/WhiteShop")
	if white_shop:
		white_shop.visible = false

func _on_shop_item_pressed(sku: String) -> void:
	var bought := _controller().buy_active(sku)
	_refresh_evaluation("Purchased %s." % sku if bought else "Purchase unavailable.")
	for shelf_node: String in SHELF_POPUPS:
		var popup := get_node(SHELF_POPUPS[shelf_node])
		if popup.visible:
			_refresh_buy_row(shelf_node, popup)

func _is_shopping() -> bool:
	var pc := _controller()
	if pc == null or pc.state == null:
		return false
	var player: PlayerState = pc.state.players[pc.state.eval_player]
	return (
		pc.state.round != 9
		and pc.state.phase == "shop"
		and player.chose_shop
		and not player.evaluation_done
	)

func _can_buy(sku: String) -> bool:
	var pc := _controller()
	return pc != null and pc.state != null and pc.state.can_buy(pc.state.eval_player, sku)


func _can_refill_flask() -> bool:
	var pc := _controller()
	if pc == null or pc.state == null:
		return false
	var state := pc.state
	# Flask refill belongs to the shop screen, not the eval-entry placeholder.
	if state.phase != "shop":
		return false
	var player: PlayerState = state.players[state.eval_player]
	return not player.evaluation_done and not player.flask_full and player.rubies >= 2

func _open_ingredient(shelf_node: String, popup: Node) -> void:
	if not _is_shopping():
		popup.visible = false
		return
	popup.visible = true
	_refresh_buy_row(shelf_node, popup)

func _refresh_buy_row(shelf_node: String, popup: Node) -> void:
	var row := popup.get_node_or_null("BuyRow") as ShopBuyRow
	if row == null:
		return
	# Keep buy controls above EvaluationPanel so clicks aren't eaten by the HUD.
	if popup is CanvasItem:
		(popup as CanvasItem).z_index = 125
	row.z_index = 130
	row.visible = _is_shopping()
	if not row.visible:
		return
	var market: Dictionary = _controller().state.market
	row.bind_skus(MarketCatalog.skus_for_shelf(shelf_node), market, _can_buy)

func _on_take_vp_pressed() -> void:
	var success := _controller().take_vp_active()
	_refresh_evaluation("Victory points taken." if success else "VP choice unavailable.")

func _on_go_shop_pressed() -> void:
	var success := _controller().go_shop_active()
	if success:
		_unspent_coin_warning_player = -1
	_refresh_evaluation("Shop selected — press Continue." if success else "Shop choice unavailable.")

func _on_eval_continue_pressed() -> void:
	var pc := _controller()
	if pc == null or pc.state == null:
		return
	var player: PlayerState = pc.state.players[pc.state.eval_player]
	if player.chose_shop and pc.state.round != 9:
		if pc.continue_to_shop_active():
			_refresh_evaluation("Shop opened.")
		return
	# VP-only (exploded) or round 9: finish this player / advance.
	if pc.finish_eval_player():
		_unspent_coin_warning_player = -1
		pc.end_turn_and_continue()
		if pc.state.phase == "game_over":
			_show_winners()
		elif get_tree().current_scene == self:
			get_tree().change_scene_to_file("res://board.tscn")
		else:
			_refresh_evaluation()
	else:
		_refresh_evaluation("Pass to Player %d." % (pc.state.eval_player + 1))

func _on_convert_coins_pressed() -> void:
	var success := _controller().convert_coins_active()
	_refresh_evaluation("Converted 5 coins to 1 VP." if success else "Need 5 coins.")

func _on_convert_rubies_pressed() -> void:
	var success := _controller().convert_rubies_active()
	_refresh_evaluation("Converted 2 rubies to 1 VP." if success else "Need 2 rubies.")

func _on_done_pressed() -> void:
	var pc := _controller()
	var previous_player := pc.state.eval_player
	var player: PlayerState = pc.state.players[previous_player]
	if (
		pc.state.round != 9
		and player.chose_shop
		and player.purchases.size() < 2
		and pc.state.has_affordable_buy(previous_player)
	):
		_refresh_evaluation("Buy another chip or spend your remaining coins first.")
		return
	if (
		pc.state.round != 9
		and player.coins > 0
		and player.chose_shop
		and _unspent_coin_warning_player != previous_player
	):
		_unspent_coin_warning_player = previous_player
		_refresh_evaluation("Unspent coins will be lost. Press Done again to continue.")
		return
	if pc.finish_eval_player():
		_unspent_coin_warning_player = -1
		pc.end_turn_and_continue()
		if pc.state.phase == "game_over":
			_show_winners()
		elif get_tree().current_scene == self:
			# Standalone shop scene — return to board. Overlay mode stays on board.
			get_tree().change_scene_to_file("res://board.tscn")
	elif pc.state.eval_player != previous_player:
		_refresh_evaluation("Pass to Player %d." % (pc.state.eval_player + 1))
	else:
		_refresh_evaluation("Choose VP, shop, or a conversion first.")

func _show_winners() -> void:
	var winners := _controller().state.winners()
	var labels: Array[String] = []
	for winner: int in winners:
		labels.append("Player %d" % (winner + 1))
	$EvaluationPanel/StatusLabel.text = "Game over — Winner%s: %s" % [
		"s" if labels.size() != 1 else "",
		", ".join(labels),
	]
	var entry := _eval_entry()
	if entry:
		entry.visible = false
	for child in $EvaluationPanel.get_children():
		if child is BaseButton or child is ItemList or child is ShopBuyRow:
			child.visible = false
	for node_name: String in INFO_SHELVES:
		get_node(node_name).visible = false
	get_node(FLASK_BUY_BUTTON).visible = false

func _controller() -> PhaseController:
	# Prefer tree-root lookup; absolute "/root/..." fails if the node isn't in an active tree.
	var session: Node = null
	var tree := get_tree()
	if tree:
		session = tree.root.get_node_or_null("GameSession")
	if session == null:
		var main := Engine.get_main_loop()
		if main and main.root:
			session = main.root.get_node_or_null("GameSession")
	if session == null:
		return null
	return session.get("controller") as PhaseController

# --- Existing reveal/hide functions ---

func _on_reveal_button_pressed() -> void:
	_open_ingredient("GaryInfo", $Gary)
func _on_garyexit_pressed() -> void:
	$Gary.visible = false
func _on_pumpkin_shelf_pressed() -> void:
	_open_ingredient("PumpkinShelf", $Pumpkin)
func _on_pumpkinexit_pressed() -> void:
	$Pumpkin.visible = false
func _on_shroom_info_pressed() -> void:
	_open_ingredient("ShroomInfo", $shroom)
func _on_shroomexit_pressed() -> void:
	$shroom.visible = false
func _on_spider_shelf_pressed() -> void:
	_open_ingredient("SpiderShelf", $spider)
func _on_spiderexit_pressed() -> void:
	$spider.visible = false
func _on_pootsshelf_pressed() -> void:
	_open_ingredient("Pootsshelf", $Poots)
func _on_pootsexit_pressed() -> void:
	$Poots.visible = false
func _on_moth_shelf_pressed() -> void:
	_open_ingredient("MothShelf", $Moth)
func _on_moth_exit_pressed() -> void:
	$Moth.visible = false
func _on_mandrake_shelf_pressed() -> void:
	_open_ingredient("MandrakeShelf", $Mandrake)
func _on_mandrakexit_pressed() -> void:
	$Mandrake.visible = false

func _on_flask_pressed() -> void:
	if _can_refill_flask():
		$FlaskConfirmDialog.popup_centered()

func _on_flask_confirmed() -> void:
	var refilled := _controller().refill_flask_active()
	_refresh_evaluation("Flask refilled for 2 rubies." if refilled else "Flask refill unavailable.")


func _on_settingicon_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _on_button_pressed() -> void:
	_on_done_pressed()
