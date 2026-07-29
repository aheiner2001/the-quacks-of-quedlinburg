class_name ChipEffects
extends RefCounted

static func toadstool_bonus(orange_count: int) -> int:
	if orange_count <= 0:
		return 0
	if orange_count <= 2:
		return 1
	return 2

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
