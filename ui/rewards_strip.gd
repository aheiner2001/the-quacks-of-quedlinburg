class_name RewardsStrip
extends Control

const ICON_DIR := "res://assets/ui/track/"
const TILE_SIZE := Vector2(120, 100)

func refresh(pot: Pot) -> void:
	PotTrack.ensure_loaded()
	var tiles := $ScrollContainer/Tiles as HBoxContainer
	for child in tiles.get_children():
		tiles.remove_child(child)
		child.queue_free()

	var space := pot.scoring_space()
	_add_tile(tiles, "Now", space, PotTrack.coins_for_space(space), PotTrack.vp_for_space(space), PotTrack.has_ruby(space))
	for milestone: Dictionary in PotTrack.upcoming_milestones(space, 5):
		_add_tile(
			tiles,
			"Next",
			int(milestone["space"]),
			int(milestone["money"]),
			int(milestone["vp"]),
			bool(milestone["ruby"])
		)

func _add_tile(tiles: HBoxContainer, title: String, space: int, money: int, vp: int, ruby: bool) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = TILE_SIZE
	var content := VBoxContainer.new()
	panel.add_child(content)

	var heading := Label.new()
	heading.text = "%s · Space %d" % [title, space]
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)

	var rewards := HBoxContainer.new()
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(rewards)
	_add_reward(rewards, "icon_money_mini.png", money)
	_add_reward(rewards, "icon_vp_mini.png", vp)
	if ruby:
		_add_reward(rewards, "icon_ruby_mini.png", 1)
	tiles.add_child(panel)

func _add_reward(parent: HBoxContainer, icon_name: String, amount: int) -> void:
	var icon := TextureRect.new()
	icon.texture = load(ICON_DIR + icon_name) as Texture2D
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	var label := Label.new()
	label.text = str(amount)
	parent.add_child(label)
