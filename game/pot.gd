class_name Pot
extends RefCounted

var droplet: int = 0
var placements: Array = [] # {chip, index}

func _last_index() -> int:
	if placements.is_empty():
		return droplet
	return int(placements[placements.size() - 1]["index"])

func place(chip: Dictionary) -> Dictionary:
	var cap := PotTrack.max_space()
	var idx := _last_index() + int(chip["value"])
	if idx > cap:
		idx = cap
	placements.append({"chip": chip, "index": idx})
	var sum := white_sum()
	var exploded := sum > 7
	return {"index": idx, "white_sum": sum, "exploded": exploded, "chip": chip}

func white_sum() -> int:
	var s := 0
	for p in placements:
		var c: Dictionary = p["chip"]
		if Chip.is_white(c):
			s += int(c["value"])
	return s

func scoring_space() -> int:
	var cap := PotTrack.max_space()
	if placements.is_empty():
		return droplet
	var last := int(placements[placements.size() - 1]["index"])
	if last >= cap:
		return cap
	return last + 1

func last_chip() -> Dictionary:
	if placements.is_empty():
		return {}
	return placements[placements.size() - 1]["chip"]

func undo_last() -> Dictionary:
	assert(not placements.is_empty())
	var p: Dictionary = placements.pop_back()
	return p["chip"]

func clear_round() -> Array:
	var chips: Array = []
	for p in placements:
		chips.append(p["chip"])
	placements.clear()
	return chips

func furthest_index() -> int:
	return _last_index()
