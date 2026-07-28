class_name ProgressTrack
extends Control

signal scroll_changed(offset: float)

const SEGMENT_H := 22.0
const TRACK_TEX_DIR := "res://assets/ui/track/"

var _preview_space: int = 0
var _last_filled_index: int = 0
var _guard_scroll: bool = false

var scroll_offset: float = 0.0:
	set(value):
		scroll_offset = value
		var scroll := get_node_or_null("ScrollContainer") as ScrollContainer
		if scroll:
			scroll.scroll_vertical = int(round(value))
		if not _guard_scroll:
			scroll_changed.emit(value)

func _ready() -> void:
	var header := get_node_or_null("HeaderRow")
	if header:
		_set_icon(header.get_node_or_null("MoneyIcon"), "icon_money_mini.png")
		_set_icon(header.get_node_or_null("VpIcon"), "icon_vp_mini.png")
		_set_icon(header.get_node_or_null("RubyIcon"), "icon_ruby_mini.png")
	var scroll := get_node_or_null("ScrollContainer") as ScrollContainer
	if scroll:
		var bar := scroll.get_v_scroll_bar()
		if bar and not bar.value_changed.is_connected(_on_scrollbar_scrolled):
			bar.value_changed.connect(_on_scrollbar_scrolled)

func _set_icon(node: Node, file_name: String) -> void:
	var rect := node as TextureRect
	if rect:
		rect.texture = load(TRACK_TEX_DIR + file_name) as Texture2D

func _on_scrollbar_scrolled(value: float) -> void:
	_guard_scroll = true
	scroll_offset = value
	_guard_scroll = false
	scroll_changed.emit(value)

## Applies an externally-driven scroll offset (e.g. from the linked TokenHistory)
## without re-emitting scroll_changed, avoiding feedback loops.
func set_scroll_offset(offset: float) -> void:
	_guard_scroll = true
	scroll_offset = offset
	_guard_scroll = false

func preview_space() -> int:
	return _preview_space

func last_filled_index() -> int:
	return _last_filled_index

func refresh(pot: Pot) -> void:
	PotTrack.ensure_loaded()
	_preview_space = pot.scoring_space()
	_last_filled_index = pot.last_index()
	_rebuild_segments()

func _rebuild_segments() -> void:
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
	var filled_tex := load(TRACK_TEX_DIR + "progress_segment_filled.png") as Texture2D
	var empty_tex := load(TRACK_TEX_DIR + "progress_segment_empty.png") as Texture2D

	for space in range(max_space + 1):
		var y := float(max_space - space) * SEGMENT_H

		var segment := TextureRect.new()
		segment.name = "Segment%d" % space
		segment.texture = filled_tex if space <= _last_filled_index else empty_tex
		segment.position = Vector2(0.0, y)
		segment.size = Vector2(SEGMENT_H, SEGMENT_H)
		segment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		segment.stretch_mode = TextureRect.STRETCH_SCALE
		if space == _preview_space:
			segment.modulate = Color(1.3, 1.3, 0.6)
		content.add_child(segment)

		var label := Label.new()
		label.name = "Label%d" % space
		label.position = Vector2(SEGMENT_H + 4.0, y)
		label.text = _reward_text(space)
		content.add_child(label)

func _reward_text(space: int) -> String:
	var parts: Array[String] = []
	var money := PotTrack.coins_for_space(space)
	var vp := PotTrack.vp_for_space(space)
	if money > 0:
		parts.append("$%d" % money)
	if vp > 0:
		parts.append("%dvp" % vp)
	if PotTrack.has_ruby(space):
		parts.append("Ruby")
	return " ".join(parts)
