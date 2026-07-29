class_name FlaskDrag
extends TextureRect

signal dropped_on_cauldron

@export var cauldron_path: NodePath

var _dragging := false
var _enabled := true
var _home_position := Vector2.ZERO

func _ready() -> void:
	_home_position = global_position
	gui_input.connect(_on_gui_input)

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if not enabled:
		_dragging = false
		global_position = _home_position

func _on_gui_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			accept_event()
		elif _dragging:
			_dragging = false
			_finish_drag()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - size / 2.0
		accept_event()

func _finish_drag() -> void:
	var cauldron := get_node_or_null(cauldron_path) as Control
	if cauldron and cauldron.get_global_rect().has_point(get_global_mouse_position()):
		dropped_on_cauldron.emit()
	global_position = _home_position
