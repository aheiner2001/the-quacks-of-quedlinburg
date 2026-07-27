# Quacks Core Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a local 1–2 player hotseat Quacks core loop (draw/stop/flask → score/shop → 9 rounds with Turn 9 conversions) with rules in pure GDScript, tested headlessly, UI wired to existing board/shop scenes.

**Architecture:** `GameState` owns all rules mutations; `PhaseController` (Node) applies intents and emits signals; board/`node_2d` scenes only render and call intents. No networking in this plan.

**Tech Stack:** Godot 4.7, GDScript, headless `SceneTree` test runner (no GUT addon required).

**Spec:** `docs/superpowers/specs/2026-07-27-quacks-core-loop-design.md`  
**Rules:** `rules.md`

## Global Constraints

- Godot **4.7**; keep `project.godot` features compatible.
- Rules logic must have **zero** scene-tree dependencies (`RefCounted` / static helpers only).
- Player count parameter supports **N** players (local UI uses 1–2); do not hardcode 2 in `GameState`.
- Stub: fortune cards, rats, bonus die, Almanac effects, ruby spaces, end-of-turn ruby droplet spends.
- House rule: flask refill is shop item id `flask_refill` (UI node `TextureButton`), not 2-rubies.
- Mandrake unlock round **≥ 2**; Poots unlock round **≥ 3**.
- Coins for a scoring space = **space index** (except space ≥ 33 → **35** coins). VP from `PotTrack` lookup (space ≥ 33 → **15** VP).
- Explosion: white values sum **> 7**; exploding chip is still placed; flask cannot undo an exploding chip.
- Max **2** purchases per shop; two **chips** must be different colors; `flask_refill` counts toward the 2 but is not a chip color.
- Turn **9**: no shop; convert **5 coins → 1 VP** and **2 rubies → 1 VP**; exploded players choose printed VP **or** conversions, not both.
- Test command (adjust binary path to the developer’s Godot 4.7):  
  `godot --headless --path . -s res://tests/run_all_tests.gd`  
  Expected: exit code `0` and `ALL TESTS PASSED` on stdout.

## File structure

| Path | Responsibility |
|---|---|
| `game/chip.gd` | Chip color enum + chip dictionary helpers |
| `game/bag.gd` | Multiset bag, seeded draw |
| `game/pot_track.gd` | Coins/VP for scoring spaces |
| `game/pot.gd` | Placement, white sum, scoring space, flask undo placement |
| `game/player_state.gd` | One player’s bag/pot/flask/VP/coins/flags |
| `game/market_catalog.gd` | Shelf SKUs, costs, stock, unlocks |
| `game/game_state.gd` | Full match state + rule mutations |
| `game/phase_controller.gd` | Phase machine, signals, intent API |
| `game/game_session.gd` | Autoload holding active controller |
| `tests/assert_util.gd` | Tiny assert helpers |
| `tests/test_*.gd` | One suite per area |
| `tests/run_all_tests.gd` | Headless entrypoint |
| `board.gd` / `board.tscn` | Potions UI |
| `node_2d.gd` / `node_2d.tscn` | Shop + evaluation overlay |
| `main_menu.gd` / `main_menu.tscn` | Start 1P/2P local game |

---

### Task 1: Headless test runner + Chip

**Files:**
- Create: `tests/assert_util.gd`
- Create: `tests/run_all_tests.gd`
- Create: `tests/test_chip.gd`
- Create: `game/chip.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `Chip.Color` enum values; `Chip.make(color: int, value: int) -> Dictionary` with keys `color`, `value`; `Chip.is_white(chip: Dictionary) -> bool`

- [ ] **Step 1: Write the failing test**

Create `tests/assert_util.gd`:

```gdscript
class_name AssertUtil
extends RefCounted

static func eq(actual, expected, label: String) -> int:
	if actual != expected:
		push_error("FAIL %s: got %s expected %s" % [label, str(actual), str(expected)])
		return 1
	print("PASS %s" % label)
	return 0

static func truthy(actual: bool, label: String) -> int:
	return eq(actual, true, label)
```

Create `tests/test_chip.gd`:

```gdscript
class_name TestChip
extends RefCounted

static func run() -> int:
	var f := 0
	var c := Chip.make(Chip.Color.WHITE, 2)
	f += AssertUtil.eq(c["color"], Chip.Color.WHITE, "chip color")
	f += AssertUtil.eq(c["value"], 2, "chip value")
	f += AssertUtil.truthy(Chip.is_white(c), "white check")
	f += AssertUtil.eq(Chip.is_white(Chip.make(Chip.Color.ORANGE, 1)), false, "orange not white")
	return f
```

Create `tests/run_all_tests.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var failures := 0
	failures += TestChip.run()
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/run_all_tests.gd`  
Expected: FAIL / parse error — `Chip` is not defined.

- [ ] **Step 3: Write minimal implementation**

Create `game/chip.gd`:

```gdscript
class_name Chip
extends RefCounted

enum Color { WHITE, ORANGE, GREEN, BLUE, RED, YELLOW, PURPLE, BLACK }

static func make(color: int, value: int) -> Dictionary:
	return {"color": color, "value": value}

static func is_white(chip: Dictionary) -> bool:
	return int(chip["color"]) == Color.WHITE
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://tests/run_all_tests.gd`  
Expected: `ALL TESTS PASSED`, exit 0.  
If Godot does not auto-register `class_name`, open the project once in the editor so `.godot` global class cache refreshes, then re-run.

- [ ] **Step 5: Commit**

```bash
git add game/chip.gd tests/assert_util.gd tests/test_chip.gd tests/run_all_tests.gd
git commit -m "feat: add Chip type and headless test runner"
```

---

### Task 2: Bag with seeded RNG + starter composition

**Files:**
- Create: `game/bag.gd`
- Create: `tests/test_bag.gd`
- Modify: `tests/run_all_tests.gd` — add `failures += TestBag.run()`

**Interfaces:**
- Consumes: `Chip.make`, `Chip.Color`
- Produces:
  - `Bag.new()` 
  - `Bag.add(chip: Dictionary) -> void`
  - `Bag.size() -> int`
  - `Bag.is_empty() -> bool`
  - `Bag.draw(rng: RandomNumberGenerator) -> Dictionary` (removes one; errors if empty)
  - `Bag.put_back(chip: Dictionary) -> void`
  - `Bag.count_matching(color: int, value: int) -> int`
  - `Bag.make_starter() -> Bag` static — 4×W1, 2×W2, 1×W3, 1×O1, 1×G1

- [ ] **Step 1: Write the failing test**

```gdscript
class_name TestBag
extends RefCounted

static func run() -> int:
	var f := 0
	var bag := Bag.make_starter()
	f += AssertUtil.eq(bag.size(), 9, "starter size")
	f += AssertUtil.eq(bag.count_matching(Chip.Color.WHITE, 1), 4, "white 1s")
	f += AssertUtil.eq(bag.count_matching(Chip.Color.WHITE, 2), 2, "white 2s")
	f += AssertUtil.eq(bag.count_matching(Chip.Color.WHITE, 3), 1, "white 3s")
	f += AssertUtil.eq(bag.count_matching(Chip.Color.ORANGE, 1), 1, "orange 1")
	f += AssertUtil.eq(bag.count_matching(Chip.Color.GREEN, 1), 1, "green 1")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var drawn := bag.draw(rng)
	f += AssertUtil.eq(bag.size(), 8, "after draw size")
	bag.put_back(drawn)
	f += AssertUtil.eq(bag.size(), 9, "after put_back")

	# Same seed => same first draw
	var b1 := Bag.make_starter()
	var b2 := Bag.make_starter()
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 42
	r2.seed = 42
	f += AssertUtil.eq(b1.draw(r1), b2.draw(r2), "seeded draw deterministic")
	return f
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/run_all_tests.gd`  
Expected: FAIL — `Bag` missing.

- [ ] **Step 3: Write minimal implementation**

```gdscript
class_name Bag
extends RefCounted

var _chips: Array = [] # Array[Dictionary]

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
		b.add(Chip.make(Chip.Color.WHITE, 1))
	for i in 2:
		b.add(Chip.make(Chip.Color.WHITE, 2))
	b.add(Chip.make(Chip.Color.WHITE, 3))
	b.add(Chip.make(Chip.Color.ORANGE, 1))
	b.add(Chip.make(Chip.Color.GREEN, 1))
	return b
```

- [ ] **Step 4: Run tests — expect `ALL TESTS PASSED`**

- [ ] **Step 5: Commit**

```bash
git add game/bag.gd tests/test_bag.gd tests/run_all_tests.gd
git commit -m "feat: add seeded Bag and starter composition"
```

---

### Task 3: PotTrack + Pot placement / explosion math

**Files:**
- Create: `game/pot_track.gd`
- Create: `game/pot.gd`
- Create: `tests/test_pot.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `Chip`
- Produces:
  - `PotTrack.coins_for_space(space: int) -> int` — `space` if `space < 33` else `35`; space `0` → `0`
  - `PotTrack.vp_for_space(space: int) -> int` — lookup; `>= 33` → `15`
  - `Pot.new()` with `droplet: int = 0`
  - `Pot.place(chip: Dictionary) -> Dictionary` result: `{index, white_sum, exploded, chip}`
  - `Pot.scoring_space() -> int` — last chip index + 1, or droplet if empty; clamp so placement never exceeds board: if computed index > 33, place on 33
  - `Pot.white_sum() -> int`
  - `Pot.last_chip() -> Dictionary` / empty if none
  - `Pot.undo_last() -> Dictionary` removes last placement, returns chip
  - `Pot.clear_round() -> Array` returns all placed chips and clears
  - `Pot.furthest_index() -> int` last placed index or droplet

**VP table (anchors from rulebook must hold):** space 19 → 5, space 23 → 7, space 33 → 15.  
Use this array for indices 0–33 (verify later against `assets/boards/gameboard.png` if art differs):

```gdscript
# index = space number
const VP := [
	0, #0
	0,0,1,1,1, #1-5
	2,2,2,2, #6-9
	3,3,3,3, #10-13
	4,4,4, #14-16
	5,5,5, #17-19  (19=5 required)
	6,6,6, #20-22
	7,7,7, #23-25  (23=7 required)
	8,8,8, #26-28
	10,10, #29-30
	12,12, #31-32
	15 #33
]
```

- [ ] **Step 1: Write the failing test**

```gdscript
class_name TestPot
extends RefCounted

static func run() -> int:
	var f := 0
	f += AssertUtil.eq(PotTrack.coins_for_space(15), 15, "coins=space")
	f += AssertUtil.eq(PotTrack.coins_for_space(33), 35, "coins at 33")
	f += AssertUtil.eq(PotTrack.vp_for_space(19), 5, "vp 19")
	f += AssertUtil.eq(PotTrack.vp_for_space(23), 7, "vp 23")
	f += AssertUtil.eq(PotTrack.vp_for_space(33), 15, "vp 33")

	var pot := Pot.new()
	var r1 := pot.place(Chip.make(Chip.Color.ORANGE, 1))
	f += AssertUtil.eq(r1["index"], 1, "first chip on 1")
	f += AssertUtil.eq(pot.white_sum(), 0, "orange ignored")
	var r2 := pot.place(Chip.make(Chip.Color.WHITE, 2))
	f += AssertUtil.eq(r2["index"], 3, "white 2 from 1 -> 3")
	f += AssertUtil.eq(pot.white_sum(), 2, "white sum 2")
	f += AssertUtil.eq(pot.scoring_space(), 4, "scoring after last")

	# Explosion: whites 3+3+2 = 8 > 7
	var p2 := Pot.new()
	p2.place(Chip.make(Chip.Color.WHITE, 3))
	p2.place(Chip.make(Chip.Color.WHITE, 3))
	var boom := p2.place(Chip.make(Chip.Color.WHITE, 2))
	f += AssertUtil.truthy(boom["exploded"], "exploded")
	f += AssertUtil.eq(boom["index"], 8, "exploding chip still placed")
	f += AssertUtil.eq(p2.scoring_space(), 9, "scoring after boom")
	return f
```

- [ ] **Step 2: Run — expect fail (missing Pot/PotTrack)**

- [ ] **Step 3: Implement `pot_track.gd` and `pot.gd`**

`game/pot_track.gd`:

```gdscript
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
```

`game/pot.gd`:

```gdscript
class_name Pot
extends RefCounted

var droplet: int = 0
var placements: Array = [] # {chip, index}

func _last_index() -> int:
	if placements.is_empty():
		return droplet
	return int(placements[placements.size() - 1]["index"])

func place(chip: Dictionary) -> Dictionary:
	var idx := _last_index() + int(chip["value"])
	if idx > 33:
		idx = 33
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
	if placements.is_empty():
		return droplet
	var last := int(placements[placements.size() - 1]["index"])
	if last >= 33:
		return 33
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
```

- [ ] **Step 4: Run — expect `ALL TESTS PASSED`**

- [ ] **Step 5: Commit**

```bash
git add game/pot_track.gd game/pot.gd tests/test_pot.gd tests/run_all_tests.gd
git commit -m "feat: add Pot placement, explosion sum, and PotTrack scoring"
```

---

### Task 4: PlayerState + potions actions (draw / stop / flask)

**Files:**
- Create: `game/player_state.gd`
- Create: `tests/test_potions.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `Bag`, `Pot`, `Chip`
- Produces `PlayerState`:
  - fields: `bag`, `pot`, `flask_full: bool`, `vp`, `rubies`, `coins`, `exploded`, `stopped`, `purchases: Array`
  - `PlayerState.create_fresh() -> PlayerState` — starter bag, flask full, zeros
  - `can_draw() -> bool`
  - `can_use_flask() -> bool` — flask full, has last chip, last is white, not exploded
  - `draw(rng) -> Dictionary` — place; set exploded/stopped if needed; return place result
  - `stop() -> void`
  - `use_flask() -> bool` — undo last into bag, flask empty; false if illegal

- [ ] **Step 1: Write failing tests for flask rules**

```gdscript
class_name TestPotions
extends RefCounted

static func run() -> int:
	var f := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var p := PlayerState.create_fresh()
	f += AssertUtil.truthy(p.flask_full, "flask starts full")
	f += AssertUtil.eq(p.bag.size(), 9, "starter bag")

	# Force-known draws by emptying and adding specific chips
	p.bag = Bag.new()
	p.bag.add(Chip.make(Chip.Color.WHITE, 3))
	p.bag.add(Chip.make(Chip.Color.WHITE, 3))
	p.bag.add(Chip.make(Chip.Color.WHITE, 2))
	# Draw order depends on RNG — instead call pot.place via a helper path:
	# Use draw after putting only one chip so draw is deterministic
	p.bag = Bag.new()
	p.bag.add(Chip.make(Chip.Color.WHITE, 2))
	var r := p.draw(rng)
	f += AssertUtil.eq(r["index"], 2, "placed white 2")
	f += AssertUtil.truthy(p.can_use_flask(), "flask ok on white")
	f += AssertUtil.truthy(p.use_flask(), "flask used")
	f += AssertUtil.eq(p.flask_full, false, "flask empty")
	f += AssertUtil.eq(p.bag.size(), 1, "chip returned")
	f += AssertUtil.eq(p.pot.placements.size(), 0, "placement undone")

	# Cannot flask after explosion
	var p2 := PlayerState.create_fresh()
	p2.bag = Bag.new()
	p2.bag.add(Chip.make(Chip.Color.WHITE, 4))
	p2.bag.add(Chip.make(Chip.Color.WHITE, 4))
	p2.pot.place(Chip.make(Chip.Color.WHITE, 4))
	p2.pot.place(Chip.make(Chip.Color.WHITE, 4)) # sum 8 exploded if via draw flags
	# Simulate draw explosion path:
	p2.exploded = true
	p2.stopped = true
	f += AssertUtil.eq(p2.can_use_flask(), false, "no flask after explode flag")
	return f
```

Tighten explosion flask test to go through `draw`:

```gdscript
	var p3 := PlayerState.create_fresh()
	p3.bag = Bag.new()
	p3.bag.add(Chip.make(Chip.Color.WHITE, 8)) # single chip value 8 > 7
	# Chip values only go to 4 in real game — use three forced places via draw of 3+3+2:
	p3.bag = Bag.new()
	# deterministic: bag size 1 each time
	p3.bag.add(Chip.make(Chip.Color.WHITE, 3))
	p3.draw(rng)
	p3.bag.add(Chip.make(Chip.Color.WHITE, 3))
	p3.draw(rng)
	p3.bag.add(Chip.make(Chip.Color.WHITE, 2))
	p3.draw(rng)
	f += AssertUtil.truthy(p3.exploded, "exploded via draws")
	f += AssertUtil.eq(p3.can_use_flask(), false, "cannot flask exploding chip")
```

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement `player_state.gd`**

```gdscript
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
var purchases: Array = [] # sku ids bought this shop
var chose_vp: bool = false
var chose_shop: bool = false
var evaluation_done: bool = false

static func create_fresh() -> PlayerState:
	var p := PlayerState.new()
	p.bag = Bag.make_starter()
	p.pot = Pot.new()
	p.flask_full = true
	return p

func can_draw() -> bool:
	return not stopped and not exploded and not bag.is_empty()

func can_use_flask() -> bool:
	if not flask_full or exploded or pot.placements.is_empty():
		return false
	var last: Dictionary = pot.last_chip()
	return Chip.is_white(last)

func draw(rng: RandomNumberGenerator) -> Dictionary:
	assert(can_draw())
	var chip := bag.draw(rng)
	var result := pot.place(chip)
	if result["exploded"]:
		exploded = true
		stopped = true
	if bag.is_empty():
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
	stopped = false
	if bag.is_empty():
		stopped = true
	return true
```

- [ ] **Step 4: Run — expect pass**

- [ ] **Step 5: Commit**

```bash
git add game/player_state.gd tests/test_potions.gd tests/run_all_tests.gd
git commit -m "feat: add PlayerState draw/stop/flask potion actions"
```

---

### Task 5: Market catalog + purchase rules

**Files:**
- Create: `game/market_catalog.gd`
- Create: `tests/test_market.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces catalog entries as Dictionaries:  
  `{id, kind, color, value, cost, stock, unlock_round, label}`  
  `kind` is `"chip"` or `"flask_refill"`
- `MarketCatalog.default_stock() -> Dictionary` id → entry (deep copy each game)
- SKUs (map shelves → colors; adjust labels only if needed):

| id | kind | color | value | cost | unlock | UI node |
|---|---|---|---|---|---|---|
| `pumpkin` | chip | ORANGE | 1 | 3 | 1 | PumpkinShelf |
| `shroom` | chip | GREEN | 1 | 4 | 1 | ShroomInfo |
| `spider` | chip | BLUE | 1 | 6 | 1 | SpiderShelf |
| `moth` | chip | RED | 1 | 6 | 1 | MothShelf |
| `mandrake` | chip | YELLOW | 1 | 8 | 2 | MandrakeShelf |
| `poots` | chip | PURPLE | 1 | 9 | 3 | Pootsshelf |
| `white_1` | chip | WHITE | 1 | 1 | 1 | (shop list / button) |
| `white_2` | chip | WHITE | 2 | 2 | 1 | (shop list) |
| `white_3` | chip | WHITE | 3 | 4 | 1 | (shop list) |
| `flask_refill` | flask_refill | — | — | 2 | 1 | TextureButton |

- `MarketCatalog.is_unlocked(entry, round: int) -> bool`
- Purchase validation lives on `GameState` in Task 6; this task only catalog + unit tests for unlock/stock structure.

- [ ] **Step 1: Write failing test**

```gdscript
class_name TestMarket
extends RefCounted

static func run() -> int:
	var f := 0
	var stock := MarketCatalog.default_stock()
	f += AssertUtil.truthy(stock.has("pumpkin"), "has pumpkin")
	f += AssertUtil.truthy(stock.has("flask_refill"), "has flask")
	f += AssertUtil.eq(MarketCatalog.is_unlocked(stock["mandrake"], 1), false, "mandrake locked r1")
	f += AssertUtil.eq(MarketCatalog.is_unlocked(stock["mandrake"], 2), true, "mandrake r2")
	f += AssertUtil.eq(MarketCatalog.is_unlocked(stock["poots"], 2), false, "poots locked r2")
	f += AssertUtil.eq(MarketCatalog.is_unlocked(stock["poots"], 3), true, "poots r3")
	return f
```

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement `market_catalog.gd`** with the table above (`stock` starting counts: chips 10 each, flask unlimited use `stock: 99`).

- [ ] **Step 4: Run — expect pass**

- [ ] **Step 5: Commit**

```bash
git add game/market_catalog.gd tests/test_market.gd tests/run_all_tests.gd
git commit -m "feat: add market catalog with round unlocks"
```

---

### Task 6: GameState — rounds, evaluation, shop, Turn 9, winners

**Files:**
- Create: `game/game_state.gd`
- Create: `tests/test_game_state.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: all prior game types
- Produces `GameState`:
  - `GameState.new_game(player_count: int, seed: int) -> GameState`
  - fields: `players: Array[PlayerState]`, `round: int` (1–9), `phase: String`, `active_player: int`, `market: Dictionary`, `rng: RandomNumberGenerator`, `start_player: int`
  - Phases: `"fortune"`, `"rats"`, `"potions"`, `"evaluation"`, `"shop"`, `"end_of_turn"`, `"game_over"`
  - `begin_round() -> void` — set phase fortune→rats→potions; reset each player pot/flags/coins/purchases; apply pre-round events when entering round 2/3/6
  - Potions: `draw()`, `stop()`, `use_flask()` on `active_player`; `advance_hotseat_if_needed()`
  - `begin_evaluation()` — set coins from scoring space for each player
  - `take_vp(player_index)` / `go_to_shop(player_index)` — enforce exploded fork; non-exploded may take VP and shop
  - `buy(player_index, sku_id) -> bool`
  - `finish_shop(player_index) -> void`
  - Turn 9: `convert_coins_to_vp(player_index)`, `convert_rubies_to_vp(player_index)` instead of shop
  - `end_turn()` — return chips to bags, clear pots, refill nothing via rubies, `round += 1` or compute winners
  - `winners() -> Array[int]` — indices; tiebreak `furthest_index` on final pot before clear (store `final_pot_furthest` on each player at end of round 9 potions)

**Buy rules to encode in `buy`:**
1. Reject if round == 9, or player not in shop eligibility, or purchases.size() >= 2.
2. Reject if locked / stock < 1 / cost > coins.
3. If sku is chip and purchases already contain a chip of same color → reject.
4. On success: deduct coins & stock; append sku to purchases; if chip, queue into `pending_bag_chips`; if flask_refill, set `flask_full = true`.
5. At shop finish / end turn: add pending chips into bag along with returned pot chips.

- [ ] **Step 1: Write failing tests (core cases)**

```gdscript
class_name TestGameState
extends RefCounted

static func run() -> int:
	var f := 0
	var gs := GameState.new_game(2, 1)
	f += AssertUtil.eq(gs.players.size(), 2, "2 players")
	f += AssertUtil.eq(gs.round, 1, "round 1")
	gs.begin_round()
	f += AssertUtil.eq(gs.phase, "potions", "skip stubs to potions")

	# Mandrake locked
	gs.players[0].coins = 20
	gs.phase = "shop"
	gs.players[0].chose_shop = true
	f += AssertUtil.eq(gs.buy(0, "mandrake"), false, "mandrake locked r1")

	gs.round = 2
	f += AssertUtil.truthy(gs.buy(0, "mandrake"), "mandrake r2")
	f += AssertUtil.eq(gs.players[0].flask_full, true, "unchanged flask")

	# flask refill
	gs.players[0].flask_full = false
	gs.players[0].coins = 20
	gs.players[0].purchases.clear()
	f += AssertUtil.truthy(gs.buy(0, "flask_refill"), "buy flask")
	f += AssertUtil.truthy(gs.players[0].flask_full, "flask refilled")

	# Exploded fork
	var g2 := GameState.new_game(1, 2)
	g2.begin_round()
	g2.players[0].exploded = true
	g2.players[0].stopped = true
	g2.begin_evaluation()
	g2.take_vp(0)
	f += AssertUtil.eq(g2.go_to_shop(0), false, "exploded cannot shop after vp")

	# Turn 9 convert
	var g3 := GameState.new_game(1, 3)
	g3.round = 9
	g3.players[0].coins = 10
	g3.players[0].exploded = false
	g3.begin_evaluation()
	g3.take_vp(0)
	var vp_before := g3.players[0].vp
	f += AssertUtil.truthy(g3.convert_coins_to_vp(0), "convert 5c")
	f += AssertUtil.eq(g3.players[0].vp, vp_before + 1, "gained 1 vp")
	f += AssertUtil.eq(g3.players[0].coins, 5, "coins left 5")
	f += AssertUtil.eq(g3.buy(0, "pumpkin"), false, "no shop r9")
	return f
```

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement `game_state.gd`** fully per interfaces above (keep methods small; fortune/rats auto-skip inside `begin_round`).

Critical snippets to include:

```gdscript
func begin_round() -> void:
	if round == 6:
		for p in players:
			p.bag.add(Chip.make(Chip.Color.WHITE, 1))
	for p in players:
		p.pot = Pot.new()
		p.exploded = false
		p.stopped = false
		p.coins = 0
		p.purchases.clear()
		p.chose_vp = false
		p.chose_shop = false
		p.evaluation_done = false
		p.pending_bag_chips = []
	active_player = start_player
	phase = "potions"

func begin_evaluation() -> void:
	phase = "evaluation"
	for p in players:
		var space := p.pot.scoring_space()
		p.coins = PotTrack.coins_for_space(space)
		if round == 9:
			p.final_pot_furthest = p.pot.furthest_index()

func take_vp(i: int) -> bool:
	var p: PlayerState = players[i]
	if p.chose_shop and p.exploded:
		return false
	if p.chose_vp:
		return false
	p.vp += PotTrack.vp_for_space(p.pot.scoring_space())
	p.chose_vp = true
	if not p.exploded:
		# may still shop / convert
		return true
	p.evaluation_done = true
	return true
```

Implement remaining methods to satisfy tests; add `pending_bag_chips` and `final_pot_furthest` fields on `PlayerState`.

- [ ] **Step 4: Run — expect pass**

- [ ] **Step 5: Commit**

```bash
git add game/game_state.gd game/player_state.gd tests/test_game_state.gd tests/run_all_tests.gd
git commit -m "feat: add GameState evaluation, shop, and Turn 9 rules"
```

---

### Task 7: PhaseController + GameSession autoload

**Files:**
- Create: `game/phase_controller.gd`
- Create: `game/game_session.gd`
- Modify: `project.godot` — register autoload `GameSession`
- Create: `tests/test_phase_controller.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- `PhaseController` extends `Node`
- Signals: `phase_changed(phase: String)`, `active_player_changed(index: int)`, `chip_drawn(player: int, result: Dictionary)`, `exploded(player: int)`, `flask_used(player: int)`, `round_ended(round: int)`, `game_over(winner_indices: Array)`
- `setup(player_count: int, seed: int) -> void`
- Intent methods mirror GameState and emit signals; after `stop`/`draw` that stops, auto-advance hotseat; when all stopped → `begin_evaluation`
- `GameSession` autoload: `controller: PhaseController`, `start_local(player_count: int) -> void` creates controller child, calls setup, begin_round

- [ ] **Step 1: Write failing test** (instantiate controller in test without tree if possible by calling methods on a plain controller after `setup`):

```gdscript
class_name TestPhaseController
extends RefCounted

static func run() -> int:
	var f := 0
	var pc := PhaseController.new()
	pc.setup(1, 99)
	pc.begin_round()
	f += AssertUtil.eq(pc.state.phase, "potions", "phase potions")
	pc.stop_active()
	f += AssertUtil.eq(pc.state.phase, "evaluation", "auto eval after only player stops")
	return f
```

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement controller + autoload**

`phase_controller.gd` sketch:

```gdscript
class_name PhaseController
extends Node

signal phase_changed(phase: String)
signal active_player_changed(index: int)
signal chip_drawn(player: int, result: Dictionary)
signal exploded(player: int)
signal flask_used(player: int)
signal round_ended(round: int)
signal game_over(winner_indices: Array)

var state: GameState

func setup(player_count: int, seed: int = 0) -> void:
	state = GameState.new_game(player_count, seed)

func begin_round() -> void:
	state.begin_round()
	phase_changed.emit(state.phase)
	active_player_changed.emit(state.active_player)

func draw_active() -> void:
	var i := state.active_player
	var result := state.draw_active()
	chip_drawn.emit(i, result)
	if result.get("exploded", false):
		exploded.emit(i)
	_after_potions_action()

func stop_active() -> void:
	state.stop_active()
	_after_potions_action()

func use_flask_active() -> void:
	if state.use_flask_active():
		flask_used.emit(state.active_player)

func _after_potions_action() -> void:
	if state.all_players_stopped():
		state.begin_evaluation()
		phase_changed.emit(state.phase)
	elif state.players[state.active_player].stopped:
		state.advance_hotseat()
		active_player_changed.emit(state.active_player)
```

Add the thin wrappers on `GameState` (`draw_active`, `stop_active`, `use_flask_active`, `all_players_stopped`, `advance_hotseat`) if not already present.

`game_session.gd`:

```gdscript
extends Node

var controller: PhaseController

func start_local(player_count: int) -> void:
	if controller:
		controller.queue_free()
	controller = PhaseController.new()
	add_child(controller)
	controller.setup(player_count)
	controller.begin_round()
```

In `project.godot` under `[autoload]`:

```
GameSession="*res://game/game_session.gd"
```

- [ ] **Step 4: Run — expect pass**

- [ ] **Step 5: Commit**

```bash
git add game/phase_controller.gd game/game_session.gd game/game_state.gd project.godot tests/test_phase_controller.gd tests/run_all_tests.gd
git commit -m "feat: add PhaseController and GameSession autoload"
```

---

### Task 8: Main menu starts 1P/2P local game

**Files:**
- Modify: `main_menu.gd`
- Modify: `main_menu.tscn` — add two buttons or a CheckButton for 2P if missing (keep existing start control; add `Players2` CheckButton)

**Interfaces:**
- Consumes: `GameSession.start_local`
- On start: `GameSession.start_local(2 if two_player else 1)` then `change_scene_to_file("res://board.tscn")`

- [ ] **Step 1: Update `main_menu.gd`**

```gdscript
extends Node2D

func _on_check_button_pressed() -> void:
	var two := false
	if has_node("Players2"):
		two = $Players2.button_pressed
	GameSession.start_local(2 if two else 1)
	get_tree().change_scene_to_file("res://board.tscn")
```

- [ ] **Step 2: In editor (or by editing tscn), add `CheckButton` named `Players2` with text `2 Players`**

- [ ] **Step 3: Manual run — main menu → start → board loads without error**

- [ ] **Step 4: Commit**

```bash
git add main_menu.gd main_menu.tscn
git commit -m "feat: main menu starts local GameSession"
```

---

### Task 9: Board potions UI

**Files:**
- Modify: `board.gd`
- Modify: `board.tscn` — add UI: `ActivePlayerLabel`, `WhiteSumLabel`, `FlaskLabel`, buttons `DrawButton`, `StopButton`, `FlaskButton`, `HandoffLabel`

**Interfaces:**
- Consumes: `GameSession.controller` signals + intents
- On `chip_drawn`: spawn/move a simple marker or Label on the matching stone if present; otherwise update a `PlacementsList` ItemList
- Disable illegal buttons using `can_draw` / `can_use_flask`

- [ ] **Step 1: Replace `board.gd` runtime logic** (keep `@tool` auto-numbering if still needed; guard with `Engine.is_editor_hint()`):

```gdscript
extends Node2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var pc: PhaseController = GameSession.controller
	pc.phase_changed.connect(_on_phase)
	pc.active_player_changed.connect(_on_active)
	pc.chip_drawn.connect(_on_drawn)
	pc.exploded.connect(func(i): $HandoffLabel.text = "Player %d exploded!" % (i + 1))
	_refresh()

func _on_phase(phase: String) -> void:
	if phase == "evaluation" or phase == "shop":
		get_tree().change_scene_to_file("res://node_2d.tscn")
	_refresh()

func _on_active(i: int) -> void:
	$HandoffLabel.text = "Player %d — draw or stop" % (i + 1)
	_refresh()

func _on_drawn(_i: int, result: Dictionary) -> void:
	$WhiteSumLabel.text = "White: %s" % str(result["white_sum"])
	_refresh()

func _refresh() -> void:
	var p: PlayerState = GameSession.controller.state.players[GameSession.controller.state.active_player]
	$DrawButton.disabled = not p.can_draw()
	$StopButton.disabled = p.stopped
	$FlaskButton.disabled = not p.can_use_flask()
	$FlaskLabel.text = "Flask: %s" % ("Full" if p.flask_full else "Empty")
	$ActivePlayerLabel.text = "P%d" % (GameSession.controller.state.active_player + 1)

func _on_draw_pressed() -> void:
	GameSession.controller.draw_active()

func _on_stop_pressed() -> void:
	GameSession.controller.stop_active()

func _on_flask_pressed() -> void:
	GameSession.controller.use_flask_active()
	_refresh()
```

- [ ] **Step 2: Wire button signals in the scene to the handlers**

- [ ] **Step 3: Manual playtest — draw until near explosion, flask a white, stop, confirm scene switches to shop scene**

- [ ] **Step 4: Commit**

```bash
git add board.gd board.tscn
git commit -m "feat: wire board potions UI to PhaseController"
```

---

### Task 10: Evaluation + shop UI in `node_2d`

**Files:**
- Modify: `node_2d.gd` (remove old fake shop cart economy; keep shelf reveal/hide cosmetics)
- Modify: `node_2d.tscn` — add evaluation panel: labels + `TakeVPButton`, `GoShopButton`, `ConvertCoinsButton`, `ConvertRubiesButton`, `DoneButton`, `StatusLabel`; ensure white chip buy buttons or ItemList `WhiteShop`

**Interfaces:**
- On ready, if phase is evaluation, show VP/shop/convert controls for `active_eval_player` (hotseat evaluation too: finish P0 then P1).
- Shelf press → `controller.buy(sku)` mapped:

```gdscript
const SHELF_SKU := {
	"PumpkinShelf": "pumpkin",
	"ShroomInfo": "shroom",
	"SpiderShelf": "spider",
	"MothShelf": "moth",
	"MandrakeShelf": "mandrake",
	"Pootsshelf": "poots",
	"TextureButton": "flask_refill",
}
```

- Disable shelves when `not MarketCatalog.is_unlocked` or round == 9.
- After all players finish evaluation/shop, call `controller.end_turn_and_continue()` → if game_over show winners; else change scene back to `board.tscn`.

- [ ] **Step 1: Implement evaluation hotseat fields on controller**

Add to `PhaseController` / `GameState`:
- `eval_player: int`
- `take_vp_active()`, `go_shop_active()`, `buy_active(sku)`, `finish_eval_player()`, `convert_coins_active()`, `convert_rubies_active()`, `end_turn_and_continue()`

- [ ] **Step 2: Rewrite `node_2d.gd` shop/eval handlers** (keep mask setup + info popups)

- [ ] **Step 3: Manual — 1P complete round 1 buy pumpkin + flask; confirm bag grew next potions**

- [ ] **Step 4: Commit**

```bash
git add node_2d.gd node_2d.tscn game/phase_controller.gd game/game_state.gd
git commit -m "feat: wire evaluation and shop UI to game rules"
```

---

### Task 11: Full-loop verification + Turn 9 path

**Files:**
- Create: `tests/test_full_loop.gd` — programmatic 9-round smoke with forced stops
- Modify: `tests/run_all_tests.gd`

- [ ] **Step 1: Write integration test**

```gdscript
class_name TestFullLoop
extends RefCounted

static func run() -> int:
	var f := 0
	var gs := GameState.new_game(2, 123)
	while gs.phase != "game_over":
		gs.begin_round()
		# Both players stop immediately
		gs.stop_active()
		gs.advance_hotseat()
		gs.stop_active()
		gs.begin_evaluation()
		for i in gs.players.size():
			gs.take_vp(i)
			if gs.round != 9:
				gs.players[i].chose_shop = true
				gs.finish_shop(i)
			else:
				gs.players[i].evaluation_done = true
		gs.end_turn()
	f += AssertUtil.eq(gs.round, 9, "ended on round 9 state")
	f += AssertUtil.truthy(gs.winners().size() >= 1, "has winner")
	return f
```

Ensure `end_turn` sets `phase = "game_over"` after finishing round 9 (do not increment past 9).

- [ ] **Step 2: Run all tests — `ALL TESTS PASSED`**

- [ ] **Step 3: Manual checklist**
  - [ ] 2P hotseat handoff label appears
  - [ ] Mandrake disabled round 1, enabled round 2
  - [ ] Poots disabled until round 3
  - [ ] Explosion stops draws; exploded choose VP **or** shop
  - [ ] Turn 9 shows convert buttons, not shelves

- [ ] **Step 4: Commit**

```bash
git add tests/test_full_loop.gd tests/run_all_tests.gd game/game_state.gd
git commit -m "test: add nine-round smoke and verify Turn 9 end"
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|---|---|
| GameState + PhaseController architecture | 6, 7 |
| Hotseat potions | 7, 9 |
| Draw / explode >7 / flask rules | 3, 4 |
| Starter bag | 2 |
| Score coins=space, VP lookup, space 33 special | 3, 6 |
| Shop 1–2, different chip colors, flask_refill item | 5, 6, 10 |
| Mandrake r2 / Poots r3 | 5, 6 |
| White +1 before round 6 | 6 |
| Turn 9 conversions, no shop | 6, 10, 11 |
| 9 rounds + winner/tiebreak | 6, 11 |
| Stub fortune/rats/bonus/almanac/ruby spaces | 6 (`begin_round` skips) |
| Unit tests listed in spec | 1–6, 11 |
| Reuse board + node_2d + TextureButton flask | 9, 10 |
| Main menu start | 8 |
| N-player parameter | 6, 7, 8 |

No TBD placeholders remain. Types/names are consistent: `PlayerState`, `GameState`, `PhaseController`, `GameSession`, sku ids match UI map.
