class_name GameState
extends RefCounted

var players: Array[PlayerState] = []
var round: int = 1
var phase: String = ""
var active_player: int = 0
var market: Dictionary = {}
var rng: RandomNumberGenerator
var start_player: int = 0

static func new_game(player_count: int, seed: int) -> GameState:
	var game := GameState.new()
	for i in max(player_count, 0):
		game.players.append(PlayerState.create_fresh())
	game.market = MarketCatalog.default_stock()
	game.rng = RandomNumberGenerator.new()
	game.rng.seed = seed
	return game

func begin_round() -> void:
	if round == 6:
		for player in players:
			player.bag.add(Chip.make(Chip.ChipColor.WHITE, 1))
	for player in players:
		player.pot = Pot.new()
		player.exploded = false
		player.stopped = false
		player.coins = 0
		player.purchases.clear()
		player.chose_vp = false
		player.chose_shop = false
		player.evaluation_done = false
		player.pending_bag_chips = []
	active_player = start_player
	phase = "potions"

func draw_active() -> Dictionary:
	if phase != "potions" or players.is_empty():
		return {}
	var player := players[active_player]
	if not player.can_draw():
		return {}
	return player.draw(rng)

func stop_active() -> void:
	if phase == "potions" and not players.is_empty():
		players[active_player].stop()

func use_flask_active() -> bool:
	if phase != "potions" or players.is_empty():
		return false
	return players[active_player].use_flask()

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

func begin_evaluation() -> void:
	phase = "evaluation"
	for player in players:
		var space := player.pot.scoring_space()
		player.coins = PotTrack.coins_for_space(space)
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

func buy(player_index: int, sku_id: String) -> bool:
	if round == 9 or not _valid_player(player_index) or phase != "shop":
		return false
	var player := players[player_index]
	if not player.chose_shop or player.purchases.size() >= 2 or not market.has(sku_id):
		return false
	var entry: Dictionary = market[sku_id]
	if not MarketCatalog.is_unlocked(entry, round):
		return false
	if int(entry["stock"]) < 1 or int(entry["cost"]) > player.coins:
		return false
	if entry["kind"] == "chip" and _already_bought_color(player, int(entry["color"])):
		return false

	player.coins -= int(entry["cost"])
	entry["stock"] = int(entry["stock"]) - 1
	player.purchases.append(sku_id)
	if entry["kind"] == "chip":
		player.pending_bag_chips.append(Chip.make(int(entry["color"]), int(entry["value"])))
	elif entry["kind"] == "flask_refill":
		player.flask_full = true
	return true

func finish_shop(player_index: int) -> void:
	if not _valid_player(player_index):
		return
	var player := players[player_index]
	if player.chose_shop:
		player.evaluation_done = true

func convert_coins_to_vp(player_index: int) -> bool:
	if not _can_convert(player_index):
		return false
	var player := players[player_index]
	if player.coins < 5:
		return false
	player.coins -= 5
	player.vp += 1
	return true

func convert_rubies_to_vp(player_index: int) -> bool:
	if not _can_convert(player_index):
		return false
	var player := players[player_index]
	if player.rubies < 2:
		return false
	player.rubies -= 2
	player.vp += 1
	return true

func end_turn() -> void:
	for player in players:
		for chip in player.pot.clear_round():
			player.bag.put_back(chip)
		for chip in player.pending_bag_chips:
			player.bag.put_back(chip)
		player.pending_bag_chips.clear()
	if round == 9:
		phase = "game_over"
	else:
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
