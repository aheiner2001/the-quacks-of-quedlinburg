class_name TokenHistory
extends Control

signal scroll_changed(offset: float)

const SEGMENT_H := 22.0
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
	var scroll := get_node_or_null("ScrollContainer") as ScrollContainer
	if scroll:
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

func _rebuild_tokens(pot: Pot) -> void:
	var content := get_node_or_null("ScrollContainer/Content") as Control
	if content == null:
		return
	for child in content.get_children():
		content.remove_child(child)
		child.free()

	var max_space := PotTrack.max_space()
	content.custom_minimum_size = Vector2(
		content.custom_minimum_size.x, float(max_space + 1) * SEGMENT_H
	)

	var rat := TextureRect.new()
	rat.name = "Rat"
	rat.texture = _rat_texture()
	rat.position = Vector2(0.0, float(max_space - pot.droplet) * SEGMENT_H)
	rat.size = Vector2(SEGMENT_H, SEGMENT_H)
	rat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rat.stretch_mode = TextureRect.STRETCH_SCALE
	content.add_child(rat)

	_token_count = pot.placements.size()
	for i in pot.placements.size():
		var placement: Dictionary = pot.placements[i]
		var chip: Dictionary = placement["chip"]
		var index := int(placement["index"])
		var token := TextureRect.new()
		token.name = "Token%d" % i
		token.texture = ChipArt.texture_for(chip)
		token.position = Vector2(SEGMENT_H + 4.0, float(max_space - index) * SEGMENT_H)
		token.size = Vector2(SEGMENT_H, SEGMENT_H)
		token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		token.stretch_mode = TextureRect.STRETCH_SCALE
		content.add_child(token)
