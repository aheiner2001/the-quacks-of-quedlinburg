class_name TestSupplyScaler
extends RefCounted

static func run() -> int:
	var f := 0
	f += AssertUtil.eq(SupplyScaler.shared_token_supply(1), 75, "tokens n=1")
	f += AssertUtil.eq(SupplyScaler.shared_ruby_supply(1), 8, "rubies n=1")
	f += AssertUtil.eq(SupplyScaler.shared_token_supply(3), 225, "tokens n=3")
	f += AssertUtil.eq(SupplyScaler.shared_ruby_supply(10), 80, "rubies n=10")
	f += AssertUtil.eq(SupplyScaler.fortune_deck_size(2), 18, "fortune size reserved")
	var m1 := SupplyScaler.build_market(1)
	var sum1 := 0
	for id in m1:
		sum1 += int(m1[id]["stock"])
	f += AssertUtil.eq(sum1, 75, "market stocks sum to 75 for n=1")
	f += AssertUtil.truthy(m1.has("white_1"), "white_1 in market")
	var m3 := SupplyScaler.build_market(3)
	var sum3 := 0
	for id in m3:
		sum3 += int(m3[id]["stock"])
	f += AssertUtil.eq(sum3, 225, "market stocks sum to 225 for n=3")
	# proportions: gary_1 / total similar across n
	var r1 := float(m1["gary_1"]["stock"]) / 75.0
	var r3 := float(m3["gary_1"]["stock"]) / 225.0
	f += AssertUtil.truthy(abs(r1 - r3) < 0.05, "gary_1 proportion stable")
	var g := GameState.new_game(2, 1)
	f += AssertUtil.eq(g.rubies_remaining, 16, "game ruby pool")
	return f
