class_name GameState
extends RefCounted

var players: Array[PlayerState] = []
var round: int = 1
var phase: String = ""
var active_player: int = 0
var eval_player: int = 0
var market: Dictionary = {}
var rubies_remaining: int = 0
var rng: RandomNumberGenerator
var start_player: int = 0
var round_6_white_granted: bool = false
var bonus_die_queue: Array[int] = []
var bonus_die_index: int = 0

static func new_game(player_count: int, seed: int) -> GameState:
	var game := GameState.new()
	for i in max(player_count, 0):
		game.players.append(PlayerState.create_fresh())
	game.market = SupplyScaler.build_market(player_count)
	game.rubies_remaining = SupplyScaler.shared_ruby_supply(player_count)
	game.rng = RandomNumberGenerator.new()
	game.rng.seed = seed
	return game

func begin_round() -> void:
	if round == 6 and not round_6_white_granted:
		for player in players:
			player.bag.add(Chip.make(Chip.ChipColor.WHITE, 1))
		round_6_white_granted = true
	for player in players:
		var carried_droplet := player.pot.droplet if player.pot != null else 0
		player.pot = Pot.new()
		player.pot.droplet = carried_droplet
		player.exploded = false
		player.stopped = false
		player.coins = 0
		player.purchases.clear()
		player.chose_vp = false
		player.chose_shop = false
		player.evaluation_done = false
		player.pending_bag_chips = []
		player.pending_droplet_bonus = 0
		player.pending_crow_draws = []
		player.awaiting_crow_choice = false
		player.awaiting_mandrake = false
	active_player = start_player
	eval_player = 0
	bonus_die_queue.clear()
	bonus_die_index = 0
	phase = "potions"

func draw_active() -> Dictionary:
	if phase != "potions" or players.is_empty():
		return {}
	var player := players[active_player]
	if not player.can_draw():
		return {}
	return player.draw(rng)

func draw() -> Dictionary:
	return draw_active()

func stop_active() -> void:
	if phase != "potions" or players.is_empty():
		return
	var player := players[active_player]
	if player.awaiting_crow_choice or player.awaiting_mandrake:
		return
	player.stop()

func stop() -> void:
	stop_active()

func use_flask_active() -> bool:
	if phase != "potions" or players.is_empty():
		return false
	var player := players[active_player]
	if player.awaiting_crow_choice or player.awaiting_mandrake:
		return false
	return player.use_flask()

func use_flask() -> bool:
	return use_flask_active()

func resolve_crow_skull(player_index: int, keep_index: int) -> Dictionary:
	if not _valid_player(player_index):
		return {}
	var player := players[player_index]
	if not player.awaiting_crow_choice:
		return {}
	if keep_index < -1 or keep_index >= player.pending_crow_draws.size():
		return {}
	var kept := ChipEffects.finish_crow_skull(player, keep_index)
	if kept.is_empty():
		if player.bag.is_empty():
			player.stopped = true
		return {}
	return player.place_drawn_chip(kept, rng)

func resolve_mandrake(player_index: int, return_white: bool) -> void:
	if not _valid_player(player_index):
		return
	var player := players[player_index]
	if not player.awaiting_mandrake:
		return
	if return_white and player.pot.placements.size() >= 2:
		var white_placement: Dictionary = player.pot.placements[player.pot.placements.size() - 2]
		var white_chip: Dictionary = white_placement["chip"]
		if Chip.is_white(white_chip):
			player.pot.placements.remove_at(player.pot.placements.size() - 2)
			player.bag.put_back(white_chip)
	player.awaiting_mandrake = false
	if player.bag.is_empty():
		player.stopped = true

func all_players_stopped() -> bool:
	if players.is_empty():
		return true
	for player in players:
		if not player.stopped and not player.exploded:
			return false
	return true

func advance_hotseat() -> int:
	if players.is_empty():
		return -1
	for offset in range(1, players.size() + 1):
		var candidate := (active_player + offset) % players.size()
		var player := players[candidate]
		if not player.stopped and not player.exploded:
			active_player = candidate
			break
	return active_player

func advance_hotseat_if_needed() -> int:
	if players.is_empty():
		return -1
	var player := players[active_player]
	if player.stopped or player.exploded:
		return advance_hotseat()
	return active_player

func bonus_die_eligible() -> Array[int]:
	var best := -1
	for player in players:
		if not player.exploded:
			best = maxi(best, player.pot.scoring_space())
	var eligible: Array[int] = []
	for i in players.size():
		var player := players[i]
		if not player.exploded and player.pot.scoring_space() == best:
			eligible.append(i)
	return eligible

func begin_bonus_die() -> void:
	bonus_die_queue = bonus_die_eligible().duplicate()
	bonus_die_index = 0
	phase = "bonus_die"

func apply_bonus_die(player_index: int, face: int) -> void:
	if not _valid_player(player_index):
		return
	var player := players[player_index]
	match face:
		BonusDie.Face.VP1:
			player.vp += 1
		BonusDie.Face.VP2:
			player.vp += 2
		BonusDie.Face.RUBY:
			if rubies_remaining > 0:
				player.rubies += 1
				rubies_remaining -= 1
		BonusDie.Face.DROPLET:
			# Defer droplet bump so this round's scoring_space grants stay unchanged.
			player.pending_droplet_bonus += 1
		BonusDie.Face.ORANGE:
			player.bag.add(Chip.make(Chip.ChipColor.ORANGE, 1))

func finish_bonus_die() -> void:
	begin_evaluation()

func resolve_chip_actions() -> void:
	var player_count := players.size()
	if player_count == 0:
		return
	for i in player_count:
		var index := (start_player + i) % player_count
		var player := players[index]
		var pot := player.pot
		player.rubies += ChipEffects.spider_ruby_count(pot)

		var left_index := (index - 1 + player_count) % player_count
		var right_index := (index + 1) % player_count
		var moth := ChipEffects.moth_reward(
			pot.count_color(Chip.ChipColor.BLACK),
			players[left_index].pot.count_color(Chip.ChipColor.BLACK),
			players[right_index].pot.count_color(Chip.ChipColor.BLACK),
			player_count
		)
		player.pot.droplet += int(moth["droplet"])
		player.rubies += int(moth["ruby"])

		var ghost := ChipEffects.ghost_best_tier(pot.count_color(Chip.ChipColor.PURPLE))
		player.vp += int(ghost["vp"])
		player.rubies += int(ghost["ruby"])
		player.pot.droplet += int(ghost["droplet"])

func begin_evaluation() -> void:
	phase = "evaluation"
	eval_player = 0
	resolve_chip_actions()
	for player in players:
		var space := player.pot.scoring_space()
		player.coins = PotTrack.coins_for_space(space)
		if PotTrack.has_ruby(space):
			player.rubies += 1
		if not player.exploded and not player.chose_vp:
			player.vp += PotTrack.vp_for_space(space)
			player.chose_vp = true
		if round == 9:
			player.final_pot_furthest = player.pot.furthest_index()

func take_vp(player_index: int) -> bool:
	if not _valid_player(player_index):
		return false
	if phase != "evaluation" and phase != "shop":
		return false
	var player := players[player_index]
	if player.chose_vp or (player.exploded and player.chose_shop):
		return false
	player.vp += PotTrack.vp_for_space(player.pot.scoring_space())
	player.chose_vp = true
	if player.exploded:
		player.evaluation_done = true
	return true

func go_to_shop(player_index: int) -> bool:
	if round == 9 or not _valid_player(player_index):
		return false
	if phase != "evaluation" and phase != "shop":
		return false
	var player := players[player_index]
	if player.chose_shop or (player.exploded and player.chose_vp):
		return false
	player.chose_shop = true
	phase = "shop"
	return true

func can_buy(player_index: int, sku_id: String) -> bool:
	if round == 9 or not _valid_player(player_index) or phase != "shop":
		return false
	var player := players[player_index]
	if (
		not player.chose_shop
		or player.evaluation_done
		or player.purchases.size() >= 2
		or not market.has(sku_id)
	):
		return false
	var entry: Dictionary = market[sku_id]
	if not MarketCatalog.is_unlocked(entry, round):
		return false
	if int(entry["stock"]) < 1 or int(entry["cost"]) > player.coins:
		return false
	if entry["kind"] == "chip" and _already_bought_color(player, int(entry["color"])):
		return false
	return true


func buy(player_index: int, sku_id: String) -> bool:
	if not can_buy(player_index, sku_id):
		return false
	var player := players[player_index]
	var entry: Dictionary = market[sku_id]
	player.coins -= int(entry["cost"])
	entry["stock"] = int(entry["stock"]) - 1
	player.purchases.append(sku_id)
	if entry["kind"] == "chip":
		player.pending_bag_chips.append(Chip.make(int(entry["color"]), int(entry["value"])))
	return true

func refill_flask(player_index: int) -> bool:
	if not _valid_player(player_index):
		return false
	if phase != "evaluation" and phase != "shop":
		return false
	var player := players[player_index]
	if player.flask_full or player.rubies < 2:
		return false
	player.rubies -= 2
	player.flask_full = true
	return true

func finish_shop(player_index: int) -> void:
	if not _valid_player(player_index):
		return
	var player := players[player_index]
	if player.chose_shop:
		player.evaluation_done = true

func finish_eval_player() -> bool:
	if not _valid_player(eval_player):
		return true
	var player := players[eval_player]
	if player.chose_shop:
		finish_shop(eval_player)
	elif player.chose_vp:
		player.evaluation_done = true
	else:
		return false
	for offset in range(1, players.size() + 1):
		var candidate := (eval_player + offset) % players.size()
		if not players[candidate].evaluation_done:
			eval_player = candidate
			return false
	return true

func convert_coins_to_vp(player_index: int) -> bool:
	if not _can_convert(player_index):
		return false
	var player := players[player_index]
	if player.coins < 5:
		return false
	player.coins -= 5
	player.vp += 1
	player.chose_shop = true
	return true

func convert_rubies_to_vp(player_index: int) -> bool:
	if not _can_convert(player_index):
		return false
	var player := players[player_index]
	if player.rubies < 2:
		return false
	player.rubies -= 2
	player.vp += 1
	player.chose_shop = true
	return true

func end_turn() -> void:
	for player in players:
		player.pot.droplet += player.pending_droplet_bonus
		player.pending_droplet_bonus = 0
		for chip in player.pot.clear_round():
			player.bag.put_back(chip)
		for chip in player.pending_bag_chips:
			player.bag.put_back(chip)
		player.pending_bag_chips.clear()
	if round == 9:
		phase = "game_over"
	else:
		if not players.is_empty():
			start_player = (start_player + 1) % players.size()
		round += 1
		phase = "end_of_turn"

func winners() -> Array:
	var result: Array = []
	if players.is_empty():
		return result
	var best_vp := players[0].vp
	for player in players:
		best_vp = max(best_vp, player.vp)
	var best_distance := -1
	for i in players.size():
		if players[i].vp == best_vp:
			best_distance = max(best_distance, players[i].final_pot_furthest)
	for i in players.size():
		if players[i].vp == best_vp and players[i].final_pot_furthest == best_distance:
			result.append(i)
	return result

func _already_bought_color(player: PlayerState, color: int) -> bool:
	for purchased_id in player.purchases:
		if not market.has(purchased_id):
			continue
		var purchased: Dictionary = market[purchased_id]
		if purchased["kind"] == "chip" and int(purchased["color"]) == color:
			return true
	return false

func _can_convert(player_index: int) -> bool:
	if round != 9 or not _valid_player(player_index):
		return false
	if phase != "evaluation" and phase != "shop":
		return false
	var player := players[player_index]
	return not (player.exploded and player.chose_vp)

func _valid_player(player_index: int) -> bool:
	return player_index >= 0 and player_index < players.size()
