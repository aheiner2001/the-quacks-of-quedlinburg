# CSV Shop & Cauldron Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Load `reference/levels.csv` and `reference/token_shop_prices.csv` into rules, ship combined shelf buy panels, flask refill for 2 rubies, and placeholder cauldron draw UI (risk bar + progress bar + bob).

**Architecture:** Keep `GameState` / `PhaseController` / scenes. Replace placeholder `PotTrack` and `MarketCatalog` with CSV-backed data; extend shop UI and board potions cosmetics only.

**Tech Stack:** Godot 4.7, GDScript, existing headless `tests/run_all_tests.gd` (`./tests/run.sh` or `godot --headless --path . --import` then `-s res://tests/run_all_tests.gd`).

**Spec:** `docs/superpowers/specs/2026-07-27-csv-shop-cauldron-design.md`

## Global Constraints

- Pot track = full CSV nodes **1–54**; **no** hard-coded ≥33 → 35 coins / 15 VP.
- Flask refill = **2 rubies** via confirm popup; **not** a coin `flask_refill` SKU.
- Shelf click = one panel with **rulebook/art + buy buttons** from CSV tiers.
- Unspent coins **lost** when leaving shop; UI warns.
- Bag/cauldron art = **placeholders**.
- Use `Chip.ChipColor` (never `Chip.Color`).
- Git commits: prefer `/usr/local/git/bin/git` if `git commit` fails with `unknown option trailer`.
- Godot binary: `/opt/homebrew/bin/godot` (or `GODOT` env).

## File structure

| Path | Role |
|---|---|
| `reference/levels.csv` | Source pot nodes (already in repo) |
| `reference/token_shop_prices.csv` | Source shop prices (already in repo) |
| `game/csv_util.gd` | Tiny CSV line parser (shared) |
| `game/pot_track.gd` | CSV-backed coins/VP/ruby/max/milestones |
| `game/pot.gd` | Clamp to `PotTrack.max_space()` |
| `game/market_catalog.gd` | CSV-backed multi-value SKUs + shelf slug map |
| `game/game_state.gd` | Ruby grant; `refill_flask`; drop coin flask SKU |
| `game/phase_controller.gd` | `refill_flask_active()` |
| `node_2d.gd` / `node_2d.tscn` | Combined panels + flask confirm + coin warning |
| `board.gd` / `board.tscn` | Placeholder bag/cauldron, risk bar, progress bar, tween |
| `tests/test_pot_track_csv.gd` | New / replace pot track assertions |
| `tests/test_market.gd` | Update for CSV SKUs |
| `tests/test_game_state.gd` | Ruby + flask rubies + clamp |
| `tests/test_shop_ui.gd` | Panel buy buttons / no coin flask |
| `tests/test_board_ui.gd` | Draw-stage nodes present |

---

### Task 1: CSV util + PotTrack from levels.csv

**Files:**
- Create: `game/csv_util.gd`
- Modify: `game/pot_track.gd`
- Modify: `tests/test_pot.gd` (replace obsolete coins=space / space-33 assertions)
- Create: `tests/test_pot_track_csv.gd` (optional if all assertions live in `test_pot.gd`)
- Modify: `tests/run_all_tests.gd` if new test class added

**Interfaces:**
- Consumes: `res://reference/levels.csv`
- Produces:
  - `CsvUtil.parse_file(path: String) -> Array` of row Dictionaries (header→value strings)
  - `PotTrack.ensure_loaded() -> void`
  - `PotTrack.coins_for_space(space: int) -> int`
  - `PotTrack.vp_for_space(space: int) -> int`
  - `PotTrack.has_ruby(space: int) -> bool`
  - `PotTrack.max_space() -> int` (= 54)
  - `PotTrack.upcoming_milestones(from_space: int, count: int) -> Array` of `{space, money, vp, ruby}`

- [ ] **Step 1: Write failing tests**

Replace `tests/test_pot.gd` PotTrack assertions with:

```gdscript
	PotTrack.ensure_loaded()
	f += AssertUtil.eq(PotTrack.max_space(), 54, "max space 54")
	f += AssertUtil.eq(PotTrack.coins_for_space(0), 0, "space 0 coins")
	f += AssertUtil.eq(PotTrack.coins_for_space(6), 5, "node 6 money")
	f += AssertUtil.eq(PotTrack.vp_for_space(6), 0, "node 6 vp")
	f += AssertUtil.truthy(PotTrack.has_ruby(6), "node 6 ruby")
	f += AssertUtil.eq(PotTrack.coins_for_space(23), 18, "node 23 money")
	f += AssertUtil.eq(PotTrack.vp_for_space(23), 5, "node 23 vp")
	f += AssertUtil.eq(PotTrack.coins_for_space(54), 35, "node 54 money")
	f += AssertUtil.eq(PotTrack.vp_for_space(54), 15, "node 54 vp")
	f += AssertUtil.eq(PotTrack.has_ruby(54), false, "node 54 no ruby")
	f += AssertUtil.eq(PotTrack.coins_for_space(33), 23, "node 33 money from CSV")
	f += AssertUtil.eq(PotTrack.vp_for_space(33), 8, "node 33 vp from CSV")
```

Keep placement/explosion pot tests unchanged for now (still clamp 33 until Task 2).

- [ ] **Step 2: Run tests — expect FAIL** on old PotTrack behavior

```bash
/opt/homebrew/bin/godot --headless --path . --import
/opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd
```

- [ ] **Step 3: Implement `csv_util.gd` + rewrite `pot_track.gd`**

`game/csv_util.gd`:

```gdscript
class_name CsvUtil
extends RefCounted

static func parse_file(path: String) -> Array:
	var rows: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CsvUtil: cannot open %s" % path)
		return rows
	var header_line := f.get_line().strip_edges()
	var headers := header_line.split(",")
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",")
		var row := {}
		for i in headers.size():
			var key := str(headers[i]).strip_edges()
			var val := str(parts[i]).strip_edges() if i < parts.size() else ""
			row[key] = val
		rows.append(row)
	return rows
```

`game/pot_track.gd` — load once into static `_nodes: Dictionary` keyed by int space:

- Parse `Node num` → int (strip `node ` prefix if present; CSV uses `node 1` style — handle both `node 6` and bare numbers)
- `Money`, `victory poitns` (typo header), `ruby?` yes/no
- `coins_for_space` / `vp_for_space` / `has_ruby` read `_nodes[clamp(space, 0, max)]`
- `upcoming_milestones`: walk spaces `from_space+1 .. max`, collect up to `count` entries (all nodes is fine, or only where money/vp/ruby changes vs previous)

**Node key parsing:** CSV first column values look like `node 1`. Use:

```gdscript
static func _parse_node_num(raw: String) -> int:
	var s := raw.strip_edges().to_lower().replace("node", "").strip_edges()
	return int(s)
```

- [ ] **Step 4: Run suite — PotTrack CSV asserts PASS** (pot clamp tests may still expect 33 until Task 2)

- [ ] **Step 5: Commit**

```bash
/usr/local/git/bin/git add game/csv_util.gd game/pot_track.gd tests/test_pot.gd tests/run_all_tests.gd
/usr/local/git/bin/git commit -m "feat: load pot track rewards from levels.csv"
```

---

### Task 2: Pot clamp to max_space 54

**Files:**
- Modify: `game/pot.gd`
- Modify: `tests/test_pot.gd` — add clamp-to-54 case; keep explosion cases

**Interfaces:**
- Consumes: `PotTrack.max_space()`
- Produces: `place` / `scoring_space` clamp at 54

- [ ] **Step 1: Failing test**

```gdscript
	var p3 := Pot.new()
	# Force far placement: droplet 50 + white 4 → clamp 54
	p3.droplet = 50
	var far := p3.place(Chip.make(Chip.ChipColor.WHITE, 4))
	f += AssertUtil.eq(far["index"], 54, "clamp to max space")
	f += AssertUtil.eq(p3.scoring_space(), 54, "scoring at cap")
```

- [ ] **Step 2: Run — FAIL** (still clamps 33)

- [ ] **Step 3: Implement**

```gdscript
func place(chip: Dictionary) -> Dictionary:
	var cap := PotTrack.max_space()
	var idx := _last_index() + int(chip["value"])
	if idx > cap:
		idx = cap
	# ...

func scoring_space() -> int:
	var cap := PotTrack.max_space()
	if placements.is_empty():
		return droplet
	var last := int(placements[placements.size() - 1]["index"])
	if last >= cap:
		return cap
	return last + 1
```

- [ ] **Step 4: Suite green**

- [ ] **Step 5: Commit** `feat: clamp pot placement to CSV max space 54`

---

### Task 3: MarketCatalog from token_shop_prices.csv

**Files:**
- Modify: `game/market_catalog.gd`
- Modify: `tests/test_market.gd`
- Modify any tests that reference old sku ids (`pumpkin`, `flask_refill`, `white_1`, …)

**Interfaces:**
- Consumes: `res://reference/token_shop_prices.csv`, `CsvUtil`
- Produces:
  - `MarketCatalog.default_stock() -> Dictionary` keyed by `gary_1`, `pumpkin_6`, …
  - Entry fields: `id, kind:"chip", color, value, cost, stock, unlock_round, label, character_slug, shelf_node`
  - `MarketCatalog.skus_for_shelf(shelf_node: String) -> Array` of sku ids
  - `MarketCatalog.SHELF_SLUGS` / character map per spec
  - **No** `flask_refill` coin SKU

Slug map (exact):

```gdscript
const CHAR_META := {
	"Scary Gary": {"slug": "gary", "color": Chip.ChipColor.BLACK, "unlock": 1, "shelf": "GaryInfo"},
	"Pumpkin": {"slug": "pumpkin", "color": Chip.ChipColor.ORANGE, "unlock": 1, "shelf": "PumpkinShelf"},
	"Spider": {"slug": "spider", "color": Chip.ChipColor.BLUE, "unlock": 1, "shelf": "SpiderShelf"},
	"Mushroom": {"slug": "shroom", "color": Chip.ChipColor.GREEN, "unlock": 1, "shelf": "ShroomInfo"},
	"Ghost (Puts)": {"slug": "poots", "color": Chip.ChipColor.PURPLE, "unlock": 3, "shelf": "Pootsshelf"},
	"Mandrake (Toby Turnip)": {"slug": "mandrake", "color": Chip.ChipColor.YELLOW, "unlock": 2, "shelf": "MandrakeShelf"},
	"Moth": {"slug": "moth", "color": Chip.ChipColor.RED, "unlock": 1, "shelf": "MothShelf"},
}
```

Verify `GaryInfo` node name exists in `node_2d.tscn`; if the reveal control is named differently, match the scene exactly.

- [ ] **Step 1: Failing tests**

```gdscript
	var stock := MarketCatalog.default_stock()
	f += AssertUtil.truthy(stock.has("gary_1"), "gary_1")
	f += AssertUtil.eq(int(stock["gary_1"]["cost"]), 5, "gary 1 cost")
	f += AssertUtil.eq(int(stock["gary_2"]["cost"]), 10, "gary 2 cost")
	f += AssertUtil.eq(int(stock["gary_4"]["cost"]), 19, "gary 4 cost")
	f += AssertUtil.eq(int(stock["pumpkin_1"]["cost"]), 3, "pumpkin 1")
	f += AssertUtil.truthy(stock.has("pumpkin_6"), "pumpkin 6")
	f += AssertUtil.eq(MarketCatalog.is_unlocked(stock["mandrake_1"], 1), false, "mandrake locked r1")
	f += AssertUtil.eq(MarketCatalog.is_unlocked(stock["mandrake_1"], 2), true, "mandrake r2")
	f += AssertUtil.eq(stock.has("flask_refill"), false, "no coin flask sku")
```

Update `test_game_state.gd` / `test_shop_ui.gd` string literals from `pumpkin` → `pumpkin_1`, remove flask coin buy tests (replace with refill_flask tests in Task 4).

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement CSV-backed `default_stock`**

Parse `token_type` with regex or `split(" ")[0]` → int value.  
`id = "%s_%d" % [slug, value]`.

- [ ] **Step 4: Suite green** (fix any broken callers)

- [ ] **Step 5: Commit** `feat: load shop prices from token_shop_prices.csv`

---

### Task 4: GameState ruby grant + refill_flask

**Files:**
- Modify: `game/game_state.gd`
- Modify: `game/phase_controller.gd`
- Modify: `tests/test_game_state.gd`

**Interfaces:**
- Consumes: `PotTrack.has_ruby`, updated market
- Produces:
  - `begin_evaluation` grants `+1` ruby when `has_ruby(scoring_space)`
  - `refill_flask(player_index: int) -> bool`
  - `PhaseController.refill_flask_active() -> bool`
  - `buy()` no longer handles `flask_refill` kind

- [ ] **Step 1: Failing tests**

```gdscript
	# Ruby from CSV node 6: put last chip so scoring_space == 6
	var g := GameState.new_game(1, 1)
	g.begin_round()
	g.players[0].pot.droplet = 5
	g.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 1)) # index 6, scoring 7 — adjust to hit ruby node
	# Prefer: manually set placements so scoring_space()==6
	g.players[0].pot.placements = [{"chip": Chip.make(Chip.ChipColor.ORANGE, 1), "index": 5}]
	# scoring_space = 6
	g.begin_evaluation()
	f += AssertUtil.eq(g.players[0].rubies, 1, "ruby granted on ruby space")
	f += AssertUtil.eq(g.players[0].coins, PotTrack.coins_for_space(6), "coins from CSV")

	g.players[0].flask_full = false
	g.players[0].rubies = 2
	f += AssertUtil.truthy(g.refill_flask(0), "refill ok")
	f += AssertUtil.eq(g.players[0].rubies, 0, "spent 2 rubies")
	f += AssertUtil.truthy(g.players[0].flask_full, "flask full")
	f += AssertUtil.eq(g.refill_flask(0), false, "cannot refill when full")
```

Remove/rewrite tests that `buy(..., "flask_refill")`.

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement grant + refill_flask; strip flask_refill from buy**

```gdscript
func refill_flask(player_index: int) -> bool:
	if not _valid_player(player_index):
		return false
	var player := players[player_index]
	if player.flask_full or player.rubies < 2:
		return false
	player.rubies -= 2
	player.flask_full = true
	return true
```

In `begin_evaluation`, after setting coins:

```gdscript
		if PotTrack.has_ruby(space):
			player.rubies += 1
```

- [ ] **Step 4: Suite green**

- [ ] **Step 5: Commit** `feat: grant rubies from track and refill flask for 2 rubies`

---

### Task 5: Shop UI — combined panels + flask confirm

**Files:**
- Modify: `node_2d.gd`
- Modify: `node_2d.tscn` — add `BuyButtonRow` container template under each ingredient popup (or one shared `IngredientBuyRow` reparented); add `FlaskConfirmDialog` (AcceptDialog or Panel)
- Modify: `tests/test_shop_ui.gd`

**Interfaces:**
- Consumes: `MarketCatalog.skus_for_shelf`, `buy_active`, `refill_flask_active`
- Produces: shelf open → art + dynamic buy buttons; flask → confirm; Done warns about unspent coins

- [ ] **Step 1: Update shop UI tests**

- Assert no reliance on coin `flask_refill` TextureButton buy.
- Assert opening Pumpkin panel builds buttons for `pumpkin_1` and `pumpkin_6` when shopping.
- Assert `StatusLabel` / Done path mentions unspent coins (substring check) when `player.coins > 0`.

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement UI**

Pattern for shelf open:

```gdscript
func _open_ingredient(shelf_node: String, popup: Node) -> void:
	popup.visible = true
	_rebuild_buy_buttons(shelf_node, popup)
```

```gdscript
func _rebuild_buy_buttons(shelf_node: String, popup: Node) -> void:
	var row := popup.get_node("BuyRow") as HBoxContainer
	for c in row.get_children():
		c.queue_free()
	var shopping := _is_shopping()
	for sku in MarketCatalog.skus_for_shelf(shelf_node):
		var entry: Dictionary = _controller().state.market[sku]
		var b := Button.new()
		b.text = "%d — %d coins" % [int(entry["value"]), int(entry["cost"])]
		b.disabled = not shopping or not _can_buy(sku)
		b.pressed.connect(_on_shop_item_pressed.bind(sku))
		row.add_child(b)
```

Wire each existing `_on_*_shelf_pressed` to `_rebuild_buy_buttons`.

Flask: disconnect coin buy; on flask press show dialog; Confirm → `refill_flask_active()` → refresh.

On Done with `coins > 0`, set status text `"Unspent coins will be lost."` then proceed (or show AcceptDialog once).

- [ ] **Step 4: Suite green + quick manual note in report**

- [ ] **Step 5: Commit** `feat: shelf buy panels and ruby flask confirm UI`

---

### Task 6: Board cauldron placeholders + bars + draw tween

**Files:**
- Modify: `board.tscn` — add `DrawStage/BagPlaceholder`, `CauldronPlaceholder`, `ChipFlight` (Sprite/ColorRect), `ExplosionRiskBar` (ProgressBar max 8), `RewardsBar` (ProgressBar or RichTextLabel list)
- Modify: `board.gd`
- Modify: `tests/test_board_ui.gd` — nodes exist; risk bar value updates helper

**Interfaces:**
- Consumes: `chip_drawn` result `white_sum`; `PotTrack` for rewards text
- Produces: cosmetic only

- [ ] **Step 1: Failing board UI test** for required node paths

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement**

On `chip_drawn`:
1. Optional: animate `ChipFlight` from bag to cauldron (Tween 0.25s), bob scale, hide.
2. `ExplosionRiskBar.value = mini(result.white_sum, 8)`; modulate red if exploded.
3. `_refresh_rewards_bar(player)` — scoring space if stopped now = last index+1; label money/VP/ruby; list `upcoming_milestones(space, 3)`.

Skip/interrupt tween if another draw starts (`_anim_gen` counter).

- [ ] **Step 4: Suite green**

- [ ] **Step 5: Commit** `feat: placeholder cauldron draw stage with risk and rewards bars`

---

## Self-review vs spec

| Spec item | Task |
|---|---|
| levels.csv → PotTrack 1–54 | 1–2 |
| token_shop_prices → multi-value SKUs | 3 |
| Ruby grant on ruby spaces | 4 |
| Flask 2 rubies confirm | 4–5 |
| Combined shelf panel | 5 |
| Unspent coin warning | 5 |
| Cauldron placeholders + risk + progress | 6 |
| Remove coin flask SKU | 3–5 |
| Tests for CSV anchors / Gary costs | 1, 3, 4 |

No TBD placeholders. SKU ids consistently `slug_value`. Pot clamp uses `PotTrack.max_space()` everywhere after Task 2.
