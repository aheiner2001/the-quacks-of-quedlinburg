class_name TestMainMenu
extends RefCounted

static func run() -> int:
	var f := 0
	var packed := load("res://main_menu.tscn") as PackedScene
	f += AssertUtil.truthy(packed != null, "main menu scene loads")
	if packed == null:
		return f
	var menu := packed.instantiate()
	var pc := menu.get_node_or_null("PlayerCount")
	f += AssertUtil.truthy(pc != null, "PlayerCount control")
	if pc:
		f += AssertUtil.eq(pc.min_value, 1.0, "min 1")
		f += AssertUtil.eq(pc.max_value, 15.0, "max 15")
		f += AssertUtil.eq(pc.value, 2.0, "default 2")
	f += AssertUtil.truthy(menu.get_node_or_null("StartButton") != null, "StartButton")
	f += AssertUtil.truthy(menu.get_node_or_null("Brand") != null, "Brand title")
	menu.free()
	return f
