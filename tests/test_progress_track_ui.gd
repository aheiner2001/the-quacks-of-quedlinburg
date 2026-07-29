class_name TestProgressTrackUI
extends RefCounted

static func run() -> int:
	var f := 0
	f += _test_progress_track()
	f += _test_token_history()
	return f

static func _test_progress_track() -> int:
	var f := 0
	var track_scene := load("res://ui/progress_track.tscn") as PackedScene
	f += AssertUtil.truthy(track_scene != null, "progress track scene loads")
	if track_scene == null:
		return f

	var track := track_scene.instantiate()
	f += AssertUtil.truthy(track.get_script() != null, "progress track script compiles")

	var pot := Pot.new()
	pot.place(Chip.make(Chip.ChipColor.ORANGE, 2))
	track.refresh(pot)
	f += AssertUtil.eq(track.preview_space(), 3, "preview is scoring space")

	var pot2 := Pot.new()
	pot2.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	pot2.place(Chip.make(Chip.ChipColor.WHITE, 2))
	track.refresh(pot2)
	f += AssertUtil.eq(track.preview_space(), 4, "preview tracks scoring space after refresh")
	f += AssertUtil.eq(track.last_filled_index(), 3, "last filled index matches pot.last_index")

	var content := track.get_node("ScrollContainer/Content")
	var filled_tex := load("res://assets/ui/track/progress_segment_filled.png")
	var empty_tex := load("res://assets/ui/track/progress_segment_empty.png")
	for space in range(4):
		var segment := content.get_node("Segment%d" % space) as TextureRect
		f += AssertUtil.truthy(segment != null, "segment %d exists" % space)
		if segment:
			f += AssertUtil.eq(
				segment.texture, filled_tex, "segment %d is filled" % space
			)
	var above := content.get_node("Segment4") as TextureRect
	f += AssertUtil.truthy(above != null, "segment 4 exists")
	if above:
		f += AssertUtil.eq(above.texture, empty_tex, "segment 4 is empty")

	var received: Array = []
	track.scroll_changed.connect(func(v): received.append(v))
	track.scroll_offset = 15.0
	f += AssertUtil.eq(received.size(), 1, "scroll offset change emits once")
	if received.size() == 1:
		f += AssertUtil.eq(received[0], 15.0, "scroll changed forwards new offset")

	track.set_scroll_offset(20.0)
	f += AssertUtil.eq(received.size(), 1, "guarded external update does not re-emit")
	f += AssertUtil.eq(track.scroll_offset, 20.0, "guarded update still applies value")

	track.free()
	return f

static func _test_token_history() -> int:
	var f := 0
	var history_scene := load("res://ui/token_history.tscn") as PackedScene
	f += AssertUtil.truthy(history_scene != null, "token history scene loads")
	if history_scene == null:
		return f

	var history := history_scene.instantiate()
	f += AssertUtil.truthy(history.get_script() != null, "token history script compiles")

	var pot := Pot.new()
	var orange_chip := Chip.make(Chip.ChipColor.ORANGE, 1)
	var white_chip := Chip.make(Chip.ChipColor.WHITE, 2)
	pot.place(orange_chip)
	pot.place(white_chip)
	history.refresh(pot)
	f += AssertUtil.eq(history.token_count(), 2, "token count matches placements")

	var content := history.get_node("ScrollContainer/Content")
	var rat := content.get_node_or_null("Rat") as TextureRect
	f += AssertUtil.truthy(rat != null and rat.texture != null, "rat stub placed at droplet")

	var token0 := content.get_node_or_null("Token0") as TextureRect
	var token1 := content.get_node_or_null("Token1") as TextureRect
	f += AssertUtil.truthy(token0 != null, "first token placed")
	f += AssertUtil.truthy(token1 != null, "second token placed")
	if token0:
		f += AssertUtil.eq(
			token0.texture, ChipArt.texture_for(orange_chip), "token0 uses orange chip art"
		)
	if token1:
		f += AssertUtil.eq(
			token1.texture, ChipArt.texture_for(white_chip), "token1 uses white chip art"
		)
	f += AssertUtil.truthy(
		TokenHistory.TOKEN_SIZE <= TokenHistory.SEGMENT_H,
		"history icons fit inside one track row"
	)
	if token0:
		f += AssertUtil.eq(
			token0.custom_minimum_size.x, TokenHistory.TOKEN_SIZE, "token min width"
		)
		f += AssertUtil.eq(
			token0.custom_minimum_size.y, TokenHistory.TOKEN_SIZE, "token min height"
		)
		f += AssertUtil.eq(token0.size.x, TokenHistory.TOKEN_SIZE, "token width matches TOKEN_SIZE")
		f += AssertUtil.eq(token0.size.y, TokenHistory.TOKEN_SIZE, "token height matches TOKEN_SIZE")

	var received: Array = []
	history.scroll_changed.connect(func(v): received.append(v))
	history.set_scroll_offset(40.0)
	f += AssertUtil.eq(received.size(), 0, "guarded set does not emit scroll_changed")
	f += AssertUtil.eq(history.scroll_offset, 40.0, "guarded set still applies value")

	history.free()
	return f
