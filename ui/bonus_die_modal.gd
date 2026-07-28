class_name BonusDieModal
extends Control

const DIE_TEX_DIR := "res://assets/ui/board/"

func _ready() -> void:
	visible = false
	if not $RollButton.pressed.is_connected(_on_roll_pressed):
		$RollButton.pressed.connect(_on_roll_pressed)
	if not $NextButton.pressed.is_connected(_on_next_pressed):
		$NextButton.pressed.connect(_on_next_pressed)

## Shows the modal and presents the first eligible player's roll, or
## immediately finishes the phase if the eligibility queue is already empty.
func open() -> void:
	visible = true
	_refresh_current()

func _controller() -> PhaseController:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return null
	return session.get("controller") as PhaseController

func _refresh_current() -> void:
	var pc := _controller()
	if pc == null or pc.state == null:
		return
	if pc.state.bonus_die_index >= pc.state.bonus_die_queue.size():
		pc.finish_bonus_die_phase()
		visible = false
		return
	var player_index: int = pc.state.bonus_die_queue[pc.state.bonus_die_index]
	$PlayerLabel.text = "Player %d rolls the bonus die" % (player_index + 1)
	$FaceTexture.texture = null
	$FaceTexture.visible = false
	$RollButton.disabled = false
	$NextButton.disabled = true

func _on_roll_pressed() -> void:
	var pc := _controller()
	if pc == null:
		return
	var face := pc.roll_bonus_die_active()
	if face < 0:
		return
	$FaceTexture.texture = _face_texture(face)
	$FaceTexture.visible = true
	$RollButton.disabled = true
	var is_last: bool = pc.state.bonus_die_index >= pc.state.bonus_die_queue.size()
	$NextButton.text = "Finish" if is_last else "Next"
	$NextButton.disabled = false

func _on_next_pressed() -> void:
	_refresh_current()

func _face_texture(face: int) -> Texture2D:
	var path := "%sbonus_die_%d.png" % [DIE_TEX_DIR, face + 1]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
