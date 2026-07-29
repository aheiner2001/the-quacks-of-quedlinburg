class_name ProgressTrack
extends Control

signal scroll_changed(offset: float)

const SEGMENT_H := 75.0
const CHIP_SIZE := 54.0
const TRACK_TEX_DIR := "res://assets/ui/track/"
const BOARD_TEX_DIR := "res://assets/ui/board/"

var _preview_space: int = 0
var _last_filled_index: int = 0
var _token_count: int = 0
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
	if _guard_scroll:
		return
	_guard_scroll = true
	scroll_offset = value
	_guard_scroll = false
	scroll_changed.emit(value)

func set_scroll_offset(offset: float) -> void:
	_guard_scroll = true
	scroll_offset = offset
	_guard_scroll = false

func preview_space() -> int:
	return _preview_space

func last_filled_index() -> int:
	return _last_filled_index

func token_count() -> int:
	return _token_count

func refresh(pot: Pot) -> void:
	PotTrack.ensure_loaded()
	_preview_space = pot.scoring_space()
	_last_filled_index = pot.last_index()
	_rebuild_segments(pot)
	_follow_brew_space(_last_filled_index)

func _follow_brew_space(space: int) -> void:
	var scroll := get_node_or_null("ScrollContainer") as ScrollContainer
	if scroll == null:
		return
	var max_space := PotTrack.max_space()
	var view_h := scroll.size.y
	if view_h < 1.0:
		view_h = size.y
	if view_h < 1.0:
		view_h = 520.0
	var content_h := float(max_space + 1) * SEGMENT_H
	var row_y := float(max_space - clampi(space, 0, max_space)) * SEGMENT_H
	var target := row_y - view_h * 0.55
	var max_scroll := maxf(0.0, content_h - view_h)
	_guard_scroll = true
	scroll_offset = clampf(target, 0.0, max_scroll)
	_guard_scroll = false
	scroll_changed.emit(scroll_offset)

func _rat_texture() -> Texture2D:
	var rat_path := BOARD_TEX_DIR + "rat.png"
	if ResourceLoader.exists(rat_path):
		return load(rat_path) as Texture2D
	return load(BOARD_TEX_DIR + "rat_stone.png") as Texture2D

func _make_chip_icon(tex: Texture2D, row_y: float) -> TextureRect:
	var pad := (SEGMENT_H - CHIP_SIZE) * 0.5
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(CHIP_SIZE, CHIP_SIZE)
	icon.position = Vector2(pad, row_y + pad)
	icon.size = Vector2(CHIP_SIZE, CHIP_SIZE)
	icon.z_index = 1
	return icon

func _force_chip_size(icon: TextureRect) -> void:
	# TextureRect resets to texture pixel size until sized after entering the tree.
	icon.custom_minimum_size = Vector2(CHIP_SIZE, CHIP_SIZE)
	icon.size = Vector2(CHIP_SIZE, CHIP_SIZE)
	icon.offset_right = icon.offset_left + CHIP_SIZE
	icon.offset_bottom = icon.offset_top + CHIP_SIZE

func _rebuild_segments(pot: Pot) -> void:
	var content := get_node_or_null("ScrollContainer/Content") as Control
	if content == null:
		return
	for child in content.get_children():
		content.remove_child(child)
		child.free()

	var max_space := PotTrack.max_space()
	content.custom_minimum_size = Vector2(
		maxf(content.custom_minimum_size.x, SEGMENT_H + 120.0),
		float(max_space + 1) * SEGMENT_H
	)
	var filled_tex := load(TRACK_TEX_DIR + "progress_segment_filled.png") as Texture2D
	var empty_tex := load(TRACK_TEX_DIR + "progress_segment_empty.png") as Texture2D

	var chips_by_space: Dictionary = {}
	for placement in pot.placements:
		chips_by_space[int(placement["index"])] = placement["chip"]
	_token_count = pot.placements.size()

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

		if chips_by_space.has(space):
			var chip_icon := _make_chip_icon(
				ChipArt.texture_for(chips_by_space[space]), y
			)
			chip_icon.name = "Chip%d" % space
			content.add_child(chip_icon)
			_force_chip_size(chip_icon)

		var label := Label.new()
		label.name = "Label%d" % space
		label.position = Vector2(SEGMENT_H + 4.0, y)
		label.text = _reward_text(space)
		content.add_child(label)

	# Droplet / rat marker on the droplet space (under chip if both share a space).
	var rat_y := float(max_space - pot.droplet) * SEGMENT_H
	var rat := _make_chip_icon(_rat_texture(), rat_y)
	rat.name = "Rat"
	rat.z_index = 0
	content.add_child(rat)
	_force_chip_size(rat)

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
