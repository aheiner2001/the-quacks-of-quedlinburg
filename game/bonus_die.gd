class_name BonusDie
extends RefCounted

enum Face { VP1, VP2, RUBY, DROPLET, ORANGE }

static func roll(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, 4)
