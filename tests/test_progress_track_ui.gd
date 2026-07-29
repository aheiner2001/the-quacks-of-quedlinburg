class_name TestProgressTrackUI
extends RefCounted

static func run() -> int:
	var f := 0
	f += _test_progress_track()
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
	var orange_chip := Chip.make(Chip.ChipColor.ORANGE, 1)
	var white_chip := Chip.make(Chip.ChipColor.WHITE, 2)
	pot2.place(orange_chip)
	pot2.place(white_chip)
	track.refresh(pot2)
	f += AssertUtil.eq(track.preview_space(), 4, "preview tracks scoring space after refresh")
	f += AssertUtil.eq(track.last_filled_index(), 3, "last filled index matches pot.last_index")
	f += AssertUtil.eq(track.token_count(), 2, "token count matches placements")

	var content := track.get_node("ScrollContainer/Content")
	var chip1 := content.get_node_or_null("Chip1") as TextureRect
	var chip3 := content.get_node_or_null("Chip3") as TextureRect
	f += AssertUtil.truthy(chip1 != null, "orange chip icon on space 1")
	f += AssertUtil.truthy(chip3 != null, "white chip icon on space 3")
	if chip1:
		f += AssertUtil.eq(
			chip1.texture, ChipArt.texture_for(orange_chip), "chip1 uses orange art"
		)
		f += AssertUtil.eq(chip1.size.x, ProgressTrack.CHIP_SIZE, "chip width fits cell")
		f += AssertUtil.eq(chip1.size.y, ProgressTrack.CHIP_SIZE, "chip height fits cell")
	if chip3:
		f += AssertUtil.eq(
			chip3.texture, ChipArt.texture_for(white_chip), "chip3 uses white art"
		)
	f += AssertUtil.truthy(
		ProgressTrack.CHIP_SIZE <= ProgressTrack.SEGMENT_H,
		"chip icons fit inside one track row"
	)
	var rat := content.get_node_or_null("Rat") as TextureRect
	f += AssertUtil.truthy(rat != null and rat.texture != null, "rat placed at droplet")

	var empty := Pot.new()
	track.refresh(empty)
	var empty_scroll: float = float(track.scroll_offset)
	var max_space := PotTrack.max_space()
	var bottomish: float = float(max_space) * ProgressTrack.SEGMENT_H * 0.2
	f += AssertUtil.truthy(
		empty_scroll >= bottomish,
		"empty pot follows toward bottom of track"
	)
	track.refresh(pot2)
	f += AssertUtil.truthy(
		track.scroll_offset < empty_scroll,
		"filled pot scrolls up to follow latest tokens"
	)

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
