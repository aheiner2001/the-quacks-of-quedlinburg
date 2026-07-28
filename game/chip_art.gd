class_name ChipArt
extends RefCounted

const TEX_DIR := "res://assets/ui/board/"
const _COLOR_SLUG := {
	Chip.ChipColor.WHITE: "white",
	Chip.ChipColor.ORANGE: "pumpkin",
	Chip.ChipColor.GREEN: "shroom",
	Chip.ChipColor.BLUE: "spider",
	Chip.ChipColor.RED: "moth",
	Chip.ChipColor.YELLOW: "mandrake",
	Chip.ChipColor.PURPLE: "poots",
	Chip.ChipColor.BLACK: "gary",
}

static func texture_for(chip: Dictionary) -> Texture2D:
	if chip.is_empty():
		return load(TEX_DIR + "chip_back.png") as Texture2D
	var slug := str(_COLOR_SLUG.get(int(chip["color"]), "chip_back"))
	var value := int(chip.get("value", 1))
	var path := "%s%s_%d.png" % [TEX_DIR, slug, value]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var fallback_one := "%s%s_1.png" % [TEX_DIR, slug]
	if ResourceLoader.exists(fallback_one):
		return load(fallback_one) as Texture2D
	return load(TEX_DIR + "chip_back.png") as Texture2D
