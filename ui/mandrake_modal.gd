class_name MandrakeModal
extends Control

func _ready() -> void:
	visible = false
	if not $ReturnWhiteButton.pressed.is_connected(_on_return_white_pressed):
		$ReturnWhiteButton.pressed.connect(_on_return_white_pressed)
	if not $KeepWhiteButton.pressed.is_connected(_on_keep_white_pressed):
		$KeepWhiteButton.pressed.connect(_on_keep_white_pressed)

func open() -> void:
	var pc := _controller()
	if pc == null or pc.state == null:
		return
	visible = pc.state.players[pc.state.active_player].awaiting_mandrake

func _on_return_white_pressed() -> void:
	var pc := _controller()
	if pc:
		pc.resolve_mandrake_active(true)
	visible = false

func _on_keep_white_pressed() -> void:
	var pc := _controller()
	if pc:
		pc.resolve_mandrake_active(false)
	visible = false

func _controller() -> PhaseController:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return null
	return session.get("controller") as PhaseController
