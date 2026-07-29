class_name TestBonusDie
extends RefCounted

static func run() -> int:
	var failures := 0
	failures += _test_reward_label()
	failures += _test_eligible_leaders()
	failures += _test_apply_faces()
	failures += _test_droplet_does_not_change_round_scoring()
	failures += _test_all_exploded_empty_queue_to_evaluation()
	return failures

static func _test_reward_label() -> int:
	var failures := 0
	failures += AssertUtil.eq(
		BonusDieModal.reward_label(BonusDie.Face.VP1, false),
		"+1 Victory Point",
		"VP1 label"
	)
	failures += AssertUtil.eq(
		BonusDieModal.reward_label(BonusDie.Face.VP2, false),
		"+2 Victory Points",
		"VP2 label"
	)
	failures += AssertUtil.eq(
		BonusDieModal.reward_label(BonusDie.Face.RUBY, true),
		"Ruby",
		"ruby granted label"
	)
	failures += AssertUtil.eq(
		BonusDieModal.reward_label(BonusDie.Face.RUBY, false),
		"No rubies left",
		"empty ruby pool label"
	)
	failures += AssertUtil.eq(
		BonusDieModal.reward_label(BonusDie.Face.DROPLET, false),
		"Droplet +1",
		"droplet label"
	)
	failures += AssertUtil.eq(
		BonusDieModal.reward_label(BonusDie.Face.ORANGE, false),
		"Pumpkin (Orange 1)",
		"orange label"
	)
	return failures

static func _test_eligible_leaders() -> int:
	var failures := 0
	var game := GameState.new_game(2, 1)
	game.begin_round()
	game.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 4))
	game.players[1].pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	game.players[0].stopped = true
	game.players[1].stopped = true
	failures += AssertUtil.eq(game.bonus_die_eligible(), [0], "sole leader eligible")
	game.players[0].exploded = true
	failures += AssertUtil.eq(game.bonus_die_eligible(), [1], "exploded leader excluded")

	game = GameState.new_game(2, 1)
	game.begin_round()
	game.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 2))
	game.players[1].pot.place(Chip.make(Chip.ChipColor.ORANGE, 2))
	game.players[0].stopped = true
	game.players[1].stopped = true
	failures += AssertUtil.eq(game.bonus_die_eligible(), [0, 1], "tied leaders eligible")
	return failures

static func _test_apply_faces() -> int:
	var failures := 0
	var game := GameState.new_game(1, 1)
	game.begin_round()
	var player := game.players[0]
	var vp_before := player.vp
	game.apply_bonus_die(0, BonusDie.Face.VP2)
	failures += AssertUtil.eq(player.vp, vp_before + 2, "VP2 applied")
	game.rubies_remaining = 0
	var rubies_before := player.rubies
	game.apply_bonus_die(0, BonusDie.Face.RUBY)
	failures += AssertUtil.eq(player.rubies, rubies_before, "ruby unavailable when pool empty")
	var droplet_before := player.pot.droplet
	game.apply_bonus_die(0, BonusDie.Face.DROPLET)
	failures += AssertUtil.eq(player.pot.droplet, droplet_before, "DROPLET defers pot.droplet bump")
	failures += AssertUtil.eq(player.pending_droplet_bonus, 1, "DROPLET stores pending bonus")
	return failures

static func _test_droplet_does_not_change_round_scoring() -> int:
	var failures := 0
	# Empty pot at droplet 6: space 6 = 5 coins + ruby; space 7 = 6 coins + 1 VP.
	var game := GameState.new_game(1, 1)
	game.begin_round()
	var player := game.players[0]
	player.pot.droplet = 6
	player.pot.placements.clear()
	player.stopped = true
	var space_before := player.pot.scoring_space()
	var expected_coins := PotTrack.coins_for_space(space_before)
	var expected_vp := PotTrack.vp_for_space(space_before)
	var expected_ruby := PotTrack.has_ruby(space_before)
	var rubies_before := player.rubies
	var vp_before := player.vp
	game.apply_bonus_die(0, BonusDie.Face.DROPLET)
	failures += AssertUtil.eq(player.pot.droplet, 6, "droplet unchanged before evaluation")
	failures += AssertUtil.eq(player.pot.scoring_space(), space_before, "scoring_space unchanged before evaluation")
	game.finish_bonus_die()
	failures += AssertUtil.eq(player.coins, expected_coins, "coins match pre-droplet scoring_space")
	failures += AssertUtil.eq(player.vp, vp_before + expected_vp, "VP match pre-droplet scoring_space")
	failures += AssertUtil.eq(
		player.rubies,
		rubies_before + (1 if expected_ruby else 0),
		"ruby grant matches pre-droplet scoring_space"
	)
	failures += AssertUtil.eq(player.pending_droplet_bonus, 1, "pending droplet remains until end_turn")
	failures += AssertUtil.eq(player.pot.droplet, 6, "pot.droplet still deferred after evaluation")
	game.end_turn()
	failures += AssertUtil.eq(player.pending_droplet_bonus, 0, "end_turn clears pending droplet")
	failures += AssertUtil.eq(player.pot.droplet, 7, "end_turn applies pending droplet")
	return failures

static func _test_all_exploded_empty_queue_to_evaluation() -> int:
	var failures := 0
	# Controller path: all exploded → empty bonus_die queue → finish → evaluation.
	var controller := PhaseController.new()
	controller.setup(2, 201)
	controller.begin_round()
	for player in controller.state.players:
		player.exploded = true
		player.stopped = true
	controller.stop_active()
	failures += AssertUtil.eq(controller.state.phase, "bonus_die", "all exploded enters bonus_die")
	failures += AssertUtil.eq(controller.state.bonus_die_queue, [], "all exploded yields empty queue")
	controller.finish_bonus_die_phase()
	failures += AssertUtil.eq(controller.state.phase, "evaluation", "empty queue finish → evaluation")
	controller.free()

	# Modal path: open() with empty queue finishes phase immediately.
	var packed := load("res://ui/bonus_die_modal.tscn") as PackedScene
	failures += AssertUtil.truthy(packed != null, "bonus die modal scene loads")
	if packed == null:
		return failures
	var modal := packed.instantiate()
	var root: Window = Engine.get_main_loop().root
	var session: Node = root.get_node("GameSession")
	session.call("start_local", 2)
	controller = session.get("controller") as PhaseController
	for player in controller.state.players:
		player.exploded = true
		player.stopped = true
	controller.state.begin_bonus_die()
	failures += AssertUtil.eq(controller.state.bonus_die_queue, [], "modal path starts with empty queue")
	root.add_child(modal)
	modal.open()
	failures += AssertUtil.eq(controller.state.phase, "evaluation", "modal empty queue → evaluation")
	failures += AssertUtil.eq(modal.visible, false, "modal hides after empty-queue finish")
	root.remove_child(modal)
	modal.free()
	return failures
