class_name PotTrack
extends RefCounted

const LEVELS_PATH := "res://reference/levels.csv"

static var _nodes: Dictionary = {}
static var _loaded: bool = false
static var _max_space: int = 0

static func ensure_loaded() -> void:
	if _loaded:
		return
	_nodes.clear()
	for row in CsvUtil.parse_file(LEVELS_PATH):
		var space := _parse_node_num(str(row.get("Node num", "")))
		if space <= 0:
			continue
		_nodes[space] = {
			"money": int(row.get("Money", "0")),
			"vp": int(row.get("victory poitns", "0")),
			"ruby": str(row.get("ruby?", "no")).strip_edges().to_lower() == "yes",
		}
		_max_space = maxi(_max_space, space)
	_loaded = true

static func _parse_node_num(raw: String) -> int:
	var s := raw.strip_edges().to_lower().replace("node", "").strip_edges()
	return int(s)

static func _clamped_space(space: int) -> int:
	ensure_loaded()
	if space <= 0:
		return 0
	return mini(maxi(space, 1), _max_space)

static func max_space() -> int:
	ensure_loaded()
	return _max_space

static func coins_for_space(space: int) -> int:
	if space <= 0:
		return 0
	var node: Dictionary = _nodes.get(_clamped_space(space), {})
	return int(node.get("money", 0))

static func vp_for_space(space: int) -> int:
	if space <= 0:
		return 0
	var node: Dictionary = _nodes.get(_clamped_space(space), {})
	return int(node.get("vp", 0))

static func has_ruby(space: int) -> bool:
	if space <= 0:
		return false
	var node: Dictionary = _nodes.get(_clamped_space(space), {})
	return bool(node.get("ruby", false))

static func upcoming_milestones(from_space: int, count: int) -> Array:
	ensure_loaded()
	var milestones: Array = []
	var prev_money := -1
	var prev_vp := -1
	var prev_ruby := false
	for s in range(maxi(from_space, 0) + 1, _max_space + 1):
		var money := coins_for_space(s)
		var vp := vp_for_space(s)
		var ruby := has_ruby(s)
		if money != prev_money or vp != prev_vp or ruby != prev_ruby:
			milestones.append({"space": s, "money": money, "vp": vp, "ruby": ruby})
			prev_money = money
			prev_vp = vp
			prev_ruby = ruby
			if milestones.size() >= count:
				break
	return milestones
