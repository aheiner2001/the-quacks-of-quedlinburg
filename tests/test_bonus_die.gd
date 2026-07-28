class_name TestBonusDie
extends RefCounted

static func run() -> int:
	var failures := 0
	failures += _test_eligible_leaders()
	failures += _test_apply_faces()
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
	return failures
