extends Node2D

const INFO_SHELVES := [
	"PumpkinShelf",
	"ShroomInfo",
	"SpiderShelf",
	"MothShelf",
	"MandrakeShelf",
	"Pootsshelf",
]
const FLASK_BUY_BUTTON := "TextureButton"

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
	var pc := _controller()
	if pc == null or pc.state == null:
		$EvaluationPanel.visible = true
		$EvaluationPanel/StatusLabel.text = "Start a game from the main menu."
		return
	_populate_white_shop()
	_refresh_evaluation()

func setup_bottle_mask(btn: TextureButton) -> void:
	if btn and btn.texture_normal:
		var img = btn.texture_normal.get_image()
		var bm = BitMap.new()
		bm.create_from_image_alpha(img)
		btn.texture_click_mask = bm

func _wire_shop_buttons() -> void:
	# Task 4 replaces the removed coin flask SKU with a ruby refill action.
	get_node(FLASK_BUY_BUTTON).visible = false

func _populate_white_shop() -> void:
	$EvaluationPanel/WhiteShop.clear()
	for sku: String in _controller().state.market:
		var entry: Dictionary = _controller().state.market[sku]
		$EvaluationPanel/WhiteShop.add_item(
			"%s — %d coins" % [entry["label"], entry["cost"]]
		)
		var index: int = $EvaluationPanel/WhiteShop.item_count - 1
		$EvaluationPanel/WhiteShop.set_item_metadata(index, sku)

func _refresh_evaluation(message: String = "") -> void:
	var pc := _controller()
	if pc == null or pc.state == null:
		$EvaluationPanel.visible = false
		return
	var state := pc.state
	$EvaluationPanel.visible = state.phase in ["evaluation", "shop", "game_over"]
	if state.phase == "game_over":
		_show_winners()
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
	$EvaluationPanel/TakeVPButton.disabled = (
		player.chose_vp or (player.exploded and player.chose_shop)
	)
	$EvaluationPanel/GoShopButton.visible = state.round != 9
	$EvaluationPanel/GoShopButton.disabled = (
		player.chose_shop or (player.exploded and player.chose_vp)
	)
	$EvaluationPanel/ConvertCoinsButton.visible = state.round == 9
	$EvaluationPanel/ConvertRubiesButton.visible = state.round == 9
	$EvaluationPanel/ConvertCoinsButton.disabled = (
		player.coins < 5 or (player.exploded and player.chose_vp)
	)
	$EvaluationPanel/ConvertRubiesButton.disabled = (
		player.rubies < 2 or (player.exploded and player.chose_vp)
	)
	$EvaluationPanel/DoneButton.disabled = not (player.chose_vp or player.chose_shop)
	_refresh_shop_controls(player)

func _refresh_shop_controls(player: PlayerState) -> void:
	var state := _controller().state
	var shop_available := (
		state.round != 9
		and state.phase == "shop"
		and player.chose_shop
		and not player.evaluation_done
	)
	for node_name: String in INFO_SHELVES:
		var button := get_node(node_name) as BaseButton
		button.visible = state.round != 9
		button.disabled = false
	var flask_button := get_node(FLASK_BUY_BUTTON) as BaseButton
	flask_button.visible = false
	$EvaluationPanel/WhiteShop.visible = state.round != 9
	for index in $EvaluationPanel/WhiteShop.item_count:
		var sku: String = $EvaluationPanel/WhiteShop.get_item_metadata(index)
		var entry: Dictionary = state.market[sku]
		$EvaluationPanel/WhiteShop.set_item_disabled(
			index,
			not shop_available
			or not MarketCatalog.is_unlocked(entry, state.round)
			or int(entry["stock"]) < 1
			or int(entry["cost"]) > player.coins
			or player.purchases.size() >= 2
		)

func _on_shop_item_pressed(sku: String) -> void:
	var bought := _controller().buy_active(sku)
	_refresh_evaluation("Purchased %s." % sku if bought else "Purchase unavailable.")

func _on_white_shop_item_clicked(
	index: int,
	_at_position: Vector2,
	_mouse_button_index: int
) -> void:
	var sku: String = $EvaluationPanel/WhiteShop.get_item_metadata(index)
	_on_shop_item_pressed(sku)

func _on_take_vp_pressed() -> void:
	var success := _controller().take_vp_active()
	_refresh_evaluation("Victory points taken." if success else "VP choice unavailable.")

func _on_go_shop_pressed() -> void:
	var success := _controller().go_shop_active()
	_refresh_evaluation("Shop opened." if success else "Shop choice unavailable.")

func _on_convert_coins_pressed() -> void:
	var success := _controller().convert_coins_active()
	_refresh_evaluation("Converted 5 coins to 1 VP." if success else "Need 5 coins.")

func _on_convert_rubies_pressed() -> void:
	var success := _controller().convert_rubies_active()
	_refresh_evaluation("Converted 2 rubies to 1 VP." if success else "Need 2 rubies.")

func _on_done_pressed() -> void:
	var pc := _controller()
	var previous_player := pc.state.eval_player
	if pc.finish_eval_player():
		pc.end_turn_and_continue()
		if pc.state.phase == "game_over":
			_show_winners()
		else:
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
	for child in $EvaluationPanel.get_children():
		if child is BaseButton or child is ItemList:
			child.visible = false
	for node_name: String in INFO_SHELVES:
		get_node(node_name).visible = false
	get_node(FLASK_BUY_BUTTON).visible = false

func _controller() -> PhaseController:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return null
	return session.get("controller") as PhaseController

# --- Existing reveal/hide functions ---

func _on_reveal_button_pressed() -> void:
	$Gary.visible = true
func _on_garyexit_pressed() -> void:
	$Gary.visible = false
func _on_pumpkin_shelf_pressed() -> void:
	$Pumpkin.visible = true
func _on_pumpkinexit_pressed() -> void:
	$Pumpkin.visible = false
func _on_shroom_info_pressed() -> void:
	$shroom.visible = true
func _on_shroomexit_pressed() -> void:
	$shroom.visible = false
func _on_spider_shelf_pressed() -> void:
	$spider.visible = true
func _on_spiderexit_pressed() -> void:
	$spider.visible = false
func _on_pootsshelf_pressed() -> void:
	$Poots.visible = true
func _on_pootsexit_pressed() -> void:
	$Poots.visible = false
func _on_moth_shelf_pressed() -> void:
	$Moth.visible = true
func _on_moth_exit_pressed() -> void:
	$Moth.visible = false
func _on_mandrake_shelf_pressed() -> void:
	$Mandrake.visible = true
func _on_mandrakexit_pressed() -> void:
	$Mandrake.visible = false


func _on_settingicon_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _on_button_pressed() -> void:
	_on_done_pressed()
