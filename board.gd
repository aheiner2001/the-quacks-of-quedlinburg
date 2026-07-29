@tool
extends Node2D

@export var run_auto_numbering: bool = false:
	set(value):
		if Engine.is_editor_hint():
			auto_number_stones()

var _pending_explosion_player: int = -1
var _anim_gen: int = 0
var _draw_tween: Tween

func _ready() -> void:
	_hide_spiral_board()
	if Engine.is_editor_hint():
		return
	_ensure_brew_panels()
	$FlaskDrag.dropped_on_cauldron.connect(_on_flask_drag_dropped)
	var pc := _controller()
	if pc == null or pc.state == null:
		$HandoffLabel.text = "Start a game from the main menu."
		$DrawButton.disabled = true
		$StopButton.disabled = true
		$FlaskButton.disabled = true
		return
	pc.phase_changed.connect(_on_phase)
	pc.active_player_changed.connect(_on_active)
	pc.chip_drawn.connect(_on_drawn)
	pc.exploded.connect(_on_exploded)
	pc.flask_used.connect(_on_flask_used)
	pc.potion_choice_resolved.connect(_on_potion_choice_resolved)
	$HandoffLabel.text = "Player %d — draw or stop" % (pc.state.active_player + 1)
	_refresh()

func _hide_spiral_board() -> void:
	var gameboard := get_node_or_null("Gameboard")
	if gameboard:
		gameboard.visible = false
	for child in get_children():
		if str(child.name).begins_with("stone"):
			child.visible = false

func _on_phase(phase: String) -> void:
	if phase == "bonus_die":
		var modal := get_node_or_null("BonusDieModal")
		if modal:
			modal.open()
		_refresh()
		return
	if phase == "evaluation" or phase == "shop":
		_ensure_shop_overlay()
		$ShopOverlay.visible = true
		var shop := $ShopOverlay.get_child(0)
		if shop and shop.has_method("_refresh_evaluation"):
			shop.call("_refresh_evaluation")
		return
	if phase == "potions":
		if has_node("ShopOverlay"):
			$ShopOverlay.visible = false
	_refresh()

func _ensure_shop_overlay() -> void:
	if has_node("ShopOverlay"):
		return
	var layer := CanvasLayer.new()
	layer.name = "ShopOverlay"
	layer.visible = false
	var shop := (load("res://node_2d.tscn") as PackedScene).instantiate()
	layer.add_child(shop)
	add_child(layer)

func _on_active(player_index: int) -> void:
	if _pending_explosion_player >= 0:
		$HandoffLabel.text = "Player %d exploded — now Player %d" % [
			_pending_explosion_player + 1,
			player_index + 1,
		]
		_pending_explosion_player = -1
	else:
		$HandoffLabel.text = "Player %d — draw or stop" % (player_index + 1)
	_refresh()

func _on_drawn(player_index: int, result: Dictionary) -> void:
	$WhiteSumLabel.text = "White: %s" % str(result["white_sum"])
	_update_explosion_risk(int(result["white_sum"]), bool(result.get("exploded", false)))
	var chip: Dictionary = result.get("chip", {})
	_animate_chip_flight(chip)
	_show_placement(player_index, result)
	_refresh()

func _on_exploded(player_index: int) -> void:
	_pending_explosion_player = player_index
	$HandoffLabel.text = "Player %d exploded!" % (player_index + 1)
	_refresh()

func _on_flask_used(_player_index: int) -> void:
	_rebuild_placements()
	_refresh()

func _on_potion_choice_resolved(_player_index: int) -> void:
	_rebuild_placements()
	_refresh()

func _ensure_brew_panels() -> void:
	if get_node_or_null("ProgressTrack") == null:
		var track := (load("res://ui/progress_track.tscn") as PackedScene).instantiate()
		track.name = "ProgressTrack"
		if track is Control:
			(track as Control).position = Vector2(24, 80)
			(track as Control).size = Vector2(200, 520)
		add_child(track)
	var history := get_node_or_null("TokenHistory")
	if history:
		history.visible = false

func _refresh() -> void:
	var pc := _controller()
	if pc == null or pc.state == null or pc.state.players.is_empty():
		return
	_ensure_brew_panels()
	var player: PlayerState = pc.state.players[pc.state.active_player]
	var awaiting_choice := player.awaiting_crow_choice or player.awaiting_mandrake
	$DrawButton.disabled = awaiting_choice or not player.can_draw()
	$StopButton.disabled = awaiting_choice or player.stopped
	$FlaskButton.disabled = awaiting_choice or not player.can_use_flask()
	$FlaskDrag.set_enabled(not $FlaskButton.disabled)
	$FlaskLabel.text = "Flask: %s" % ("Full" if player.flask_full else "Empty")
	$WhiteSumLabel.text = "White: %d" % player.pot.white_sum()
	$ActivePlayerLabel.text = "P%d" % (pc.state.active_player + 1)
	_update_explosion_risk(player.pot.white_sum(), player.exploded)
	$RewardsStrip.refresh(player.pot)
	var track := get_node_or_null("ProgressTrack")
	if track and track.has_method("refresh"):
		track.call("refresh", player.pot)
	var history := get_node_or_null("TokenHistory")
	if history:
		history.visible = false
	if player.awaiting_crow_choice:
		$CrowSkullModal.open()
	elif player.awaiting_mandrake:
		$MandrakeModal.open()

func _update_explosion_risk(white_sum: int, exploded: bool) -> void:
	var bar := get_node_or_null("ExplosionRiskBar") as ProgressBar
	if bar == null:
		return
	bar.value = mini(white_sum, 8)
	bar.modulate = Color.RED if exploded else Color.WHITE

func _texture_for_chip(chip: Dictionary) -> Texture2D:
	return ChipArt.texture_for(chip)


func _animate_chip_flight(chip: Dictionary = {}) -> void:
	_anim_gen += 1
	var generation := _anim_gen
	if _draw_tween != null and _draw_tween.is_valid():
		_draw_tween.kill()
	var chip_flight := $DrawStage/ChipFlight as TextureRect
	var bag := $DrawStage/BagPlaceholder as TextureRect
	var cauldron := $DrawStage/CauldronPlaceholder as TextureRect
	chip_flight.texture = _texture_for_chip(chip)
	chip_flight.position = bag.position + (bag.size - chip_flight.size) / 2.0
	chip_flight.scale = Vector2.ONE
	chip_flight.visible = true

	var target_pos := cauldron.position + (cauldron.size - chip_flight.size) / 2.0
	target_pos.y -= 90  # move landing point up by 40px — tweak this number

	_draw_tween = create_tween()
	_draw_tween.set_parallel(true)
	_draw_tween.tween_property(
		chip_flight,
		"position",
		target_pos,
		0.28
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_draw_tween.tween_property(
		chip_flight,
		"scale",
		Vector2(1.35, 1.35),
		0.14
	).set_trans(Tween.TRANS_SINE)
	_draw_tween.chain().tween_property(
		chip_flight,
		"scale",
		Vector2.ONE,
		0.14
	).set_trans(Tween.TRANS_SINE)
	_draw_tween.finished.connect(_on_draw_tween_finished.bind(generation, chip_flight))

func _on_draw_tween_finished(generation: int, chip_flight: TextureRect) -> void:
	if generation == _anim_gen and is_instance_valid(chip_flight):
		chip_flight.visible = false

func _show_placement(player_index: int, result: Dictionary) -> void:
	var index := int(result["index"])
	for child in get_children():
		if child.has_node("Label") and child.get_node("Label").text == str(index):
			var marker := Label.new()
			var chip: Dictionary = result["chip"]
			marker.text = "%s %s" % [str(chip["color"]), str(chip["value"])]
			marker.position = Vector2(-20, -24)
			marker.set_meta("pot_chip_marker", true)
			child.add_child(marker)
			return
	var fallback_chip: Dictionary = result["chip"]
	$PlacementsList.add_item(
		"P%d: %s %s → %d" % [
			player_index + 1,
			str(fallback_chip["color"]),
			str(fallback_chip["value"]),
			index,
		]
	)

func _rebuild_placements() -> void:
	$PlacementsList.clear()
	for child in get_children():
		for marker in child.get_children():
			if marker.has_meta("pot_chip_marker"):
				child.remove_child(marker)
				marker.free()
	var pc := _controller()
	if pc == null or pc.state == null:
		return
	for player_index in pc.state.players.size():
		for placement: Dictionary in pc.state.players[player_index].pot.placements:
			_show_placement(player_index, placement)

func _on_draw_pressed() -> void:
	_controller().draw_active()

func _on_stop_pressed() -> void:
	_controller().stop_active()

func _on_flask_pressed() -> void:
	_controller().use_flask_active()
	_refresh()

func _on_flask_drag_dropped() -> void:
	if not $FlaskButton.disabled:
		_on_flask_pressed()

func _controller() -> PhaseController:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return null
	return session.get("controller") as PhaseController

func auto_number_stones() -> void:
	var current_number = 1
	var children = get_children()
	
	print("--- DEBUG: Checking board children ---")
	print("Total children found: ", children.size())
	
	for child in children:
		print("Found child named: ", child.name, " of type: ", child.get_class())
		
		if child.has_node("Label"):
			var lbl = child.get_node("Label") as Label
			if lbl:
				lbl.text = str(current_number)
				print(" -> Successfully numbered stone: ", current_number)
				current_number += 1
		else:
			print(" -> WARNING: Child '", child.name, "' does NOT have a child node named 'Label'!")
			
	print("Successfully auto-numbered ", current_number - 1, " stones on the board!")
