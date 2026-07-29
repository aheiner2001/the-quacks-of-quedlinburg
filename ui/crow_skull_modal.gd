class_name CrowSkullModal
extends Control

func _ready() -> void:
	visible = false
	if not $KeepNoneButton.pressed.is_connected(_on_keep_none_pressed):
		$KeepNoneButton.pressed.connect(_on_keep_none_pressed)

func open() -> void:
	var pc := _controller()
	if pc == null or pc.state == null:
		return
	var player := pc.state.players[pc.state.active_player]
	visible = player.awaiting_crow_choice
	if not visible:
		return
	for child in $ChipChoices.get_children():
		child.queue_free()
	for i in player.pending_crow_draws.size():
		var choice := TextureButton.new()
		choice.texture_normal = ChipArt.texture_for(player.pending_crow_draws[i])
		choice.custom_minimum_size = Vector2(64, 64)
		choice.tooltip_text = "Keep this chip"
		choice.pressed.connect(_on_choice_pressed.bind(i))
		$ChipChoices.add_child(choice)

func _on_choice_pressed(index: int) -> void:
	var pc := _controller()
	visible = false
	if pc:
		pc.resolve_crow_skull_active(index)

func _on_keep_none_pressed() -> void:
	var pc := _controller()
	visible = false
	if pc:
		pc.resolve_crow_skull_active(-1)

func _controller() -> PhaseController:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return null
	return session.get("controller") as PhaseController
