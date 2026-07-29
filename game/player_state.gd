class_name PlayerState
extends RefCounted

var bag: Bag
var pot: Pot
var flask_full: bool = true
var vp: int = 0
var rubies: int = 0
var coins: int = 0
var exploded: bool = false
var stopped: bool = false
var purchases: Array = []
var chose_vp: bool = false
var chose_shop: bool = false
var evaluation_done: bool = false
var pending_bag_chips: Array = []
var pending_droplet_bonus: int = 0
var final_pot_furthest: int = 0
var pending_crow_draws: Array = []
var awaiting_crow_choice: bool = false
var awaiting_mandrake: bool = false

static func create_fresh() -> PlayerState:
	var p := PlayerState.new()
	p.bag = Bag.make_starter()
	p.pot = Pot.new()
	p.flask_full = true
	return p

func can_draw() -> bool:
	return (
		not stopped
		and not exploded
		and not awaiting_crow_choice
		and not awaiting_mandrake
		and not bag.is_empty()
	)

func can_use_flask() -> bool:
	if stopped or not flask_full or exploded or pot.placements.is_empty():
		return false
	var last: Dictionary = pot.last_chip()
	return Chip.is_white(last)

func draw(rng: RandomNumberGenerator) -> Dictionary:
	assert(can_draw())
	var chip := bag.draw(rng)
	return place_drawn_chip(chip, rng)

func place_drawn_chip(chip: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var prior_chip := pot.last_chip()
	var bonus := 0
	if int(chip["color"]) == Chip.ChipColor.RED:
		bonus = ChipEffects.toadstool_bonus(pot.count_color(Chip.ChipColor.ORANGE))
	var result := pot.place(chip, bonus)
	if result["exploded"]:
		exploded = true
		stopped = true
	if int(chip["color"]) == Chip.ChipColor.BLUE:
		ChipEffects.begin_crow_skull(self, int(chip["value"]), rng)
	if int(chip["color"]) == Chip.ChipColor.YELLOW and Chip.is_white(prior_chip):
		awaiting_mandrake = true
	if bag.is_empty() and not awaiting_crow_choice and not awaiting_mandrake:
		stopped = true
	return result

func stop() -> void:
	stopped = true

func use_flask() -> bool:
	if not can_use_flask():
		return false
	var chip := pot.undo_last()
	bag.put_back(chip)
	flask_full = false
	return true
