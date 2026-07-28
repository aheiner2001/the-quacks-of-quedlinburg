class_name TestMainMenu
extends RefCounted

static func run() -> int:
	var f := 0
	var packed := load("res://main_menu.tscn") as PackedScene
	var menu := packed.instantiate()
	f += AssertUtil.truthy(menu.get_node_or_null("PlayerCount") != null, "PlayerCount control")
	if f == 0:
		var pc := menu.get_node("PlayerCount")
		f += AssertUtil.eq(pc.min_value, 1.0, "min 1")
		f += AssertUtil.eq(pc.max_value, 15.0, "max 15")
		f += AssertUtil.eq(pc.value, 2.0, "default 2")
	menu.free()
	return f
