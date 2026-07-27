class_name PotTrack
extends RefCounted

const VP := [
	0,
	0, 0, 1, 1, 1,
	2, 2, 2, 2,
	3, 3, 3, 3,
	4, 4, 4,
	5, 5, 5,
	6, 6, 6,
	7, 7, 7,
	8, 8, 8,
	10, 10,
	12, 12,
	15
]

static func coins_for_space(space: int) -> int:
	if space <= 0:
		return 0
	if space >= 33:
		return 35
	return space

static func vp_for_space(space: int) -> int:
	if space <= 0:
		return 0
	if space >= 33:
		return 15
	return VP[space]
