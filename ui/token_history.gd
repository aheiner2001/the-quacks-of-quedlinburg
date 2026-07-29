class_name TokenHistory
extends Control

signal scroll_changed(offset: float)

## Row height along the synced track; keep equal to ProgressTrack.SEGMENT_H.
const SEGMENT_H := 22.0
## Fit icons inside one track row so scroll doesn't clip them.
const TOKEN_SIZE :=75
const BOARD_TEX_DIR := "res://assets/ui/board/"

var _guard_scroll: bool = false
var _token_count: int = 0

var scroll_offset: float = 0.0:
	set(value):
		scroll_offset = value
		var scroll := get_node_or_null("ScrollContainer") as ScrollContainer
		if scroll:
			scroll.scroll_vertical = int(round(value))
		if not _guard_scroll:
			scroll_changed.emit(value)

func _ready() -> void:
	clip_contents = true
	var scroll := get_node_or_null("ScrollContainer") as ScrollContainer
	if scroll:
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.clip_contents = true
		var bar := scroll.get_v_scroll_bar()
		if bar and not bar.value_changed.is_connected(_on_scrollbar_scrolled):
			bar.value_changed.connect(_on_scrollbar_scrolled)

func _on_scrollbar_scrolled(value: float) -> void:
	_guard_scroll = true
	scroll_offset = value
	_guard_scroll = false
	scroll_changed.emit(value)

## Applies an externally-driven scroll offset (e.g. from the linked ProgressTrack)
## without re-emitting scroll_changed, avoiding feedback loops.
func set_scroll_offset(offset: float) -> void:
	_guard_scroll = true
	scroll_offset = offset
	_guard_scroll = false

func token_count() -> int:
	return _token_count

func refresh(pot: Pot) -> void:
	PotTrack.ensure_loaded()
	_rebuild_tokens(pot)

func _rat_texture() -> Texture2D:
	var rat_path := BOARD_TEX_DIR + "rat.png"
	if ResourceLoader.exists(rat_path):
		return load(rat_path) as Texture2D
	return load(BOARD_TEX_DIR + "rat_stone.png") as Texture2D

func _make_icon(tex: Texture2D, at: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(TOKEN_SIZE, TOKEN_SIZE)
	icon.position = at
	icon.size = Vector2(TOKEN_SIZE, TOKEN_SIZE)
	return icon

func _rebuild_tokens(pot: Pot) -> void:
	var content := get_node_or_null("ScrollContainer/Content") as Control
	if content == null:
		return
	for child in content.get_children():
		content.remove_child(child)
		child.free()

	var max_space := PotTrack.max_space()
	var content_w := maxf(size.x - 8.0, TOKEN_SIZE * 2.0 + 24.0)
	content.custom_minimum_size = Vector2(
		content_w, float(max_space + 1) * SEGMENT_H
	)
	content.clip_contents = false

	# Center icon on the space row so it lines up with track ticks.
	var y_pad := (SEGMENT_H - TOKEN_SIZE) * 0.5
	var col0 := 8.0
	var col1 := col0 + TOKEN_SIZE + 10.0
	var rat := _make_icon(_rat_texture(), Vector2(col0, float(max_space - pot.droplet) * SEGMENT_H + y_pad))
	rat.name = "Rat"
	content.add_child(rat)
	_force_token_size(rat)

	_token_count = pot.placements.size()
	for i in pot.placements.size():
		var placement: Dictionary = pot.placements[i]
		var chip: Dictionary = placement["chip"]
		var index := int(placement["index"])
		var token := _make_icon(
			ChipArt.texture_for(chip),
			Vector2(col1, float(max_space - index) * SEGMENT_H + y_pad)
		)
		token.name = "Token%d" % i
		content.add_child(token)
		_force_token_size(token)

func _force_token_size(icon: TextureRect) -> void:
	# TextureRect resets to texture pixel size until sized after entering the tree.
	icon.custom_minimum_size = Vector2(TOKEN_SIZE, TOKEN_SIZE)
	icon.size = Vector2(TOKEN_SIZE, TOKEN_SIZE)
	icon.offset_right = icon.offset_left + TOKEN_SIZE
	icon.offset_bottom = icon.offset_top + TOKEN_SIZE
