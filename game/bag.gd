class_name Bag
extends RefCounted

var _chips: Array = []

func add(chip: Dictionary) -> void:
	_chips.append(chip)

func size() -> int:
	return _chips.size()

func is_empty() -> bool:
	return _chips.is_empty()

func draw(rng: RandomNumberGenerator) -> Dictionary:
	assert(not _chips.is_empty())
	var i := rng.randi_range(0, _chips.size() - 1)
	var chip: Dictionary = _chips[i]
	_chips.remove_at(i)
	return chip

func put_back(chip: Dictionary) -> void:
	_chips.append(chip)

func count_matching(color: int, value: int) -> int:
	var n := 0
	for c in _chips:
		if int(c["color"]) == color and int(c["value"]) == value:
			n += 1
	return n

static func make_starter() -> Bag:
	var b := Bag.new()
	for i in 4:
		b.add(Chip.make(Chip.ChipColor.WHITE, 1))
	for i in 2:
		b.add(Chip.make(Chip.ChipColor.WHITE, 2))
	b.add(Chip.make(Chip.ChipColor.WHITE, 3))
	b.add(Chip.make(Chip.ChipColor.ORANGE, 1))
	b.add(Chip.make(Chip.ChipColor.GREEN, 1))
	return b
