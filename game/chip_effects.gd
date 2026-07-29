class_name ChipEffects
extends RefCounted

static func toadstool_bonus(orange_count: int) -> int:
	if orange_count <= 0:
		return 0
	if orange_count <= 2:
		return 1
	return 2

static func spider_ruby_count(pot: Pot) -> int:
	var count := 0
	var size := pot.placements.size()
	for offset in [1, 2]:
		var index: int = size - offset
		if index < 0:
			break
		if int(pot.placements[index]["chip"]["color"]) == Chip.ChipColor.GREEN:
			count += 1
	return count

static func moth_reward(mine: int, left: int, right: int, player_count: int) -> Dictionary:
	if player_count < 2 or mine <= 0:
		return {"droplet": 0, "ruby": 0}
	if player_count <= 2:
		if mine > left:
			return {"droplet": 1, "ruby": 1}
		if mine == left:
			return {"droplet": 1, "ruby": 0}
		return {"droplet": 0, "ruby": 0}
	var beats_left := mine > left
	var beats_right := mine > right
	if beats_left and beats_right:
		return {"droplet": 1, "ruby": 1}
	if beats_left or beats_right:
		return {"droplet": 1, "ruby": 0}
	return {"droplet": 0, "ruby": 0}

static func ghost_best_tier(purple_count: int) -> Dictionary:
	if purple_count >= 3:
		return {"vp": 2, "ruby": 0, "droplet": 1}
	if purple_count == 2:
		return {"vp": 1, "ruby": 1, "droplet": 0}
	if purple_count == 1:
		return {"vp": 1, "ruby": 0, "droplet": 0}
	return {"vp": 0, "ruby": 0, "droplet": 0}

static func begin_crow_skull(player: PlayerState, value: int, rng: RandomNumberGenerator) -> void:
	player.pending_crow_draws.clear()
	for _i in value:
		if player.bag.is_empty():
			break
		player.pending_crow_draws.append(player.bag.draw(rng))
	player.awaiting_crow_choice = not player.pending_crow_draws.is_empty()

static func finish_crow_skull(player: PlayerState, keep_index: int) -> Dictionary:
	var kept: Dictionary = {}
	if keep_index >= 0 and keep_index < player.pending_crow_draws.size():
		kept = player.pending_crow_draws[keep_index]
	for i in player.pending_crow_draws.size():
		if i != keep_index:
			player.bag.put_back(player.pending_crow_draws[i])
	player.pending_crow_draws.clear()
	player.awaiting_crow_choice = false
	return kept
