@tool
extends Node2D

@export var run_auto_numbering: bool = false:
	set(value):
		if Engine.is_editor_hint():
			auto_number_stones()

var _pending_explosion_player: int = -1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
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
	$HandoffLabel.text = "Player %d — draw or stop" % (pc.state.active_player + 1)
	_refresh()

func _on_phase(phase: String) -> void:
	if phase == "evaluation" or phase == "shop":
		get_tree().change_scene_to_file("res://node_2d.tscn")
		return
	_refresh()

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
	_show_placement(player_index, result)
	_refresh()

func _on_exploded(player_index: int) -> void:
	_pending_explosion_player = player_index
	$HandoffLabel.text = "Player %d exploded!" % (player_index + 1)
	_refresh()

func _on_flask_used(_player_index: int) -> void:
	_rebuild_placements()
	_refresh()

func _refresh() -> void:
	var pc := _controller()
	if pc == null or pc.state == null or pc.state.players.is_empty():
		return
	var player: PlayerState = pc.state.players[pc.state.active_player]
	$DrawButton.disabled = not player.can_draw()
	$StopButton.disabled = player.stopped
	$FlaskButton.disabled = not player.can_use_flask()
	$FlaskLabel.text = "Flask: %s" % ("Full" if player.flask_full else "Empty")
	$WhiteSumLabel.text = "White: %d" % player.pot.white_sum()
	$ActivePlayerLabel.text = "P%d" % (pc.state.active_player + 1)

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
