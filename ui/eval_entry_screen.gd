class_name EvalEntryScreen
extends Control

## Intermediate post-brew screen (phase "evaluation").
## Expand this scene with round results / fortune / rats later.
## Take VP / Go Shop live here; Continue enters the real shop (phase "shop").

signal take_vp_pressed
signal go_shop_pressed
signal convert_coins_pressed
signal convert_rubies_pressed
signal continue_pressed


func _ready() -> void:
	$TakeVPButton.pressed.connect(func(): take_vp_pressed.emit())
	$GoShopButton.pressed.connect(func(): go_shop_pressed.emit())
	$ConvertCoinsButton.pressed.connect(func(): convert_coins_pressed.emit())
	$ConvertRubiesButton.pressed.connect(func(): convert_rubies_pressed.emit())
	$ContinueButton.pressed.connect(func(): continue_pressed.emit())


func refresh(state: GameState, message: String = "") -> void:
	if state == null or state.players.is_empty():
		visible = false
		return
	visible = state.phase == "evaluation"
	if not visible:
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
	$StatusLabel.text = status
	$PlaceholderLabel.text = "Evaluation — placeholder (build round results here)"

	$TakeVPButton.disabled = (
		player.chose_vp or (player.exploded and player.chose_shop)
	)
	$GoShopButton.visible = state.round != 9
	$GoShopButton.disabled = (
		player.chose_shop or (player.exploded and player.chose_vp)
	)
	$ConvertCoinsButton.visible = state.round == 9
	$ConvertRubiesButton.visible = state.round == 9
	$ConvertCoinsButton.disabled = (
		player.coins < 5 or (player.exploded and player.chose_vp)
	)
	$ConvertRubiesButton.disabled = (
		player.rubies < 2 or (player.exploded and player.chose_vp)
	)
	$ContinueButton.disabled = not _can_continue(state, player)


func _can_continue(state: GameState, player: PlayerState) -> bool:
	if state.round == 9:
		return player.chose_vp
	# Shop path selected → Continue opens shop.
	if player.chose_shop:
		return true
	# Exploded VP-only path → Continue finishes this player.
	if player.exploded and player.chose_vp:
		return true
	# Non-exploded already have mandatory VP; they must choose Go Shop first.
	return false
