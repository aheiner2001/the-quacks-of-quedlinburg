# Set 1 Effects + UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remap shelves to official Set 1 colors, implement Set 1 on-draw and Evaluation B chip effects, polish bonus-die / flask / rewards / shop UX per the approved spec.

**Architecture:** Keep `GameState` / `PhaseController` / `GameSession`. Add `game/chip_effects.gd` for pure Set 1 resolution helpers. Extend `Pot.place` for bonus movement. Pause brewing with a `pending_chip_choice` state for Crow Skull. Insert Evaluation B grants before shop UI. Replace RewardsBar RichText with `ui/rewards_strip`, flask button with drag target, and shop buy surface with book-panel BuyRows + gated Continue.

**Tech Stack:** Godot 4.7, GDScript, headless suite via `./tests/run.sh` (Godot `/opt/homebrew/bin/godot`).

**Spec:** `docs/superpowers/specs/2026-07-29-set1-effects-ui-polish-design.md`

## Global Constraints

- Set **1** Almanac only; Sets 2–4 out of scope.
- Do **not** replace ingredient book/shelf art; buy controls attach to existing panels.
- Cauldron rune + chip flight stay.
- Ghost v1: auto-pick **best** tier (lower-tier choice later).
- Bonus-die ruby only if `rubies_remaining > 0`; pot-space rubies always grant.
- Use `Chip.ChipColor` (never `Chip.Color`).
- Prefer `/usr/local/git/bin/git` for commits if wrapper rejects `--trailer`.
- After each task: `./tests/run.sh` must pass (request `all` permissions if sandbox crashes Godot).

## File structure

| Path | Role |
|---|---|
| `game/market_catalog.gd` | Remap CHAR_META colors to Set 1 |
| `game/chip_art.gd` | Remap `_COLOR_SLUG` to match new colors |
| `game/chip_effects.gd` | Pure helpers: toadstool bonus, spider/moth/ghost/mandrake resolve |
| `game/pot.gd` | `place(chip, bonus_spaces := 0)`; orange count helper |
| `game/player_state.gd` | Draw path uses effects; crow-skull pending; mandrake undo white |
| `game/game_state.gd` | Eval B chip actions; crow-skull resolve API; shop `has_affordable_buy` |
| `game/phase_controller.gd` | Wire new APIs / signals |
| `ui/crow_skull_modal.gd` + `.tscn` | Pick one of N drawn chips or discard all |
| `ui/mandrake_modal.gd` + `.tscn` | Optional return previous white |
| `ui/rewards_strip.gd` + `.tscn` | Taller horizontal Now + Next tiles |
| `ui/flask_drag.gd` | Draggable flask → cauldron drop |
| `ui/bonus_die_modal.gd` + `.tscn` | Reward label after roll |
| `board.gd` / `board.tscn` | Host strip, flask, modals; hide FlaskButton |
| `node_2d.gd` | Book-centric shop; Continue gating |
| `tests/test_chip_effects.gd` | New pure effect tests |
| `tests/test_market.gd` / `test_bag.gd` / art callers | Color remap updates |
| `tests/test_board_ui.gd` / `test_shop_ui.gd` / `test_bonus_die.gd` | UI expectations |

---

### Task 1: Official Set 1 color remapping

**Files:**
- Modify: `game/market_catalog.gd`
- Modify: `game/chip_art.gd`
- Modify: `tests/test_market.gd` (and any color assertions)
- Test: `tests/test_market.gd`, full suite

**Interfaces:**
- Produces: catalog colors — `gary→BLUE`, `spider→GREEN`, `shroom→RED`, `moth→BLACK`, `poots→PURPLE`, `pumpkin→ORANGE`, `mandrake→YELLOW`, `white→WHITE`
- Produces: `ChipArt` slugs — GREEN:`spider`, BLUE:`gary`, RED:`shroom`, BLACK:`moth`, PURPLE:`poots`, ORANGE:`pumpkin`, YELLOW:`mandrake`, WHITE:`white`

- [ ] **Step 1: Write failing color assertions in `tests/test_market.gd`**

Add to `TestMarket.run()` after stock loads:

```gdscript
f += AssertUtil.eq(int(stock["gary_1"]["color"]), Chip.ChipColor.BLUE, "gary is blue Crow Skull")
f += AssertUtil.eq(int(stock["spider_1"]["color"]), Chip.ChipColor.GREEN, "spider is green")
f += AssertUtil.eq(int(stock["shroom_1"]["color"]), Chip.ChipColor.RED, "mushroom is red Toadstool")
f += AssertUtil.eq(int(stock["moth_1"]["color"]), Chip.ChipColor.BLACK, "moth is black Hawkmoth")
f += AssertUtil.eq(int(stock["poots_1"]["color"]), Chip.ChipColor.PURPLE, "ghost is purple")
```

- [ ] **Step 2: Run suite — expect FAIL on new color asserts**

Run: `./tests/run.sh`  
Expected: FAIL messages naming the wrong colors

- [ ] **Step 3: Remap `MarketCatalog.CHAR_META` colors**

```gdscript
"Scary Gary": { "slug": "gary", "color": Chip.ChipColor.BLUE, "unlock": 1, "shelf": "GaryInfo" },
"Spider": { "slug": "spider", "color": Chip.ChipColor.GREEN, "unlock": 1, "shelf": "SpiderShelf" },
"Mushroom": { "slug": "shroom", "color": Chip.ChipColor.RED, "unlock": 1, "shelf": "ShroomInfo" },
"Moth": { "slug": "moth", "color": Chip.ChipColor.BLACK, "unlock": 1, "shelf": "MothShelf" },
# Pumpkin ORANGE, Mandrake YELLOW, Ghost PURPLE, Cherry Bomb WHITE unchanged
```

Force catalog reload in tests if `_loaded` is sticky: add `MarketCatalog.reset_for_tests()` that sets `_loaded = false` and clears `_stock_template`, call it at start of `TestMarket.run()` if needed.

- [ ] **Step 4: Remap `ChipArt._COLOR_SLUG`**

```gdscript
const _COLOR_SLUG := {
	Chip.ChipColor.WHITE: "white",
	Chip.ChipColor.ORANGE: "pumpkin",
	Chip.ChipColor.GREEN: "spider",
	Chip.ChipColor.BLUE: "gary",
	Chip.ChipColor.RED: "shroom",
	Chip.ChipColor.YELLOW: "mandrake",
	Chip.ChipColor.PURPLE: "poots",
	Chip.ChipColor.BLACK: "moth",
}
```

- [ ] **Step 5: Run suite — expect PASS**

Run: `./tests/run.sh`  
Expected: `ALL TESTS PASSED`

- [ ] **Step 6: Commit**

```bash
/usr/local/git/bin/git add game/market_catalog.gd game/chip_art.gd tests/test_market.gd
/usr/local/git/bin/git commit -m "$(cat <<'EOF'
fix: remap shelf colors to official Set 1 Almanac

EOF
)"
```

---

### Task 2: Chip effects helpers + Toadstool placement bonus

**Files:**
- Create: `game/chip_effects.gd`
- Modify: `game/pot.gd`
- Modify: `game/player_state.gd` (`draw` uses toadstool bonus)
- Create: `tests/test_chip_effects.gd`
- Modify: `tests/run_all_tests.gd` (preload + run)
- Modify: `tests/test_pot.gd` if `place` signature changes need coverage

**Interfaces:**
- Produces: `ChipEffects.toadstool_bonus(orange_count: int) -> int` → 0 / 1 / 2
- Produces: `Pot.count_color(color: int) -> int`
- Produces: `Pot.place(chip: Dictionary, bonus_spaces: int = 0) -> Dictionary` — index = last + value + bonus_spaces, clamped
- Consumes: remapped RED = mushroom / toadstool

- [ ] **Step 1: Write failing tests in `tests/test_chip_effects.gd`**

```gdscript
class_name TestChipEffects
extends RefCounted

static func run() -> int:
	var f := 0
	f += AssertUtil.eq(ChipEffects.toadstool_bonus(0), 0, "0 orange → +0")
	f += AssertUtil.eq(ChipEffects.toadstool_bonus(1), 1, "1 orange → +1")
	f += AssertUtil.eq(ChipEffects.toadstool_bonus(2), 1, "2 orange → +1")
	f += AssertUtil.eq(ChipEffects.toadstool_bonus(3), 2, "3 orange → +2")

	var pot := Pot.new()
	pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	f += AssertUtil.eq(pot.count_color(Chip.ChipColor.ORANGE), 2, "count oranges")

	var red := Chip.make(Chip.ChipColor.RED, 1)
	var before_oranges := pot.count_color(Chip.ChipColor.ORANGE)
	var result := pot.place(red, ChipEffects.toadstool_bonus(before_oranges))
	# droplet 0 + orange1 → idx1; +orange1 → idx2; red1 + bonus1 → idx4
	f += AssertUtil.eq(int(result["index"]), 4, "toadstool lands with orange bonus")
	return f
```

- [ ] **Step 2: Run — expect FAIL (ChipEffects missing / place ignores bonus)**

Run: `/opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd` after registering the test, or temporarily run via a one-off. Prefer register in `run_all_tests.gd` first so FAIL is clean.

- [ ] **Step 3: Implement `game/chip_effects.gd`**

```gdscript
class_name ChipEffects
extends RefCounted

static func toadstool_bonus(orange_count: int) -> int:
	if orange_count <= 0:
		return 0
	if orange_count <= 2:
		return 1
	return 2
```

- [ ] **Step 4: Extend `Pot`**

```gdscript
func count_color(color: int) -> int:
	var n := 0
	for p in placements:
		if int(p["chip"]["color"]) == color:
			n += 1
	return n

func place(chip: Dictionary, bonus_spaces: int = 0) -> Dictionary:
	var cap := PotTrack.max_space()
	var idx := _last_index() + int(chip["value"]) + maxi(bonus_spaces, 0)
	if idx > cap:
		idx = cap
	placements.append({"chip": chip, "index": idx})
	var sum := white_sum()
	var exploded := sum > 7
	return {"index": idx, "white_sum": sum, "exploded": exploded, "chip": chip}
```

- [ ] **Step 5: Update `PlayerState.draw`**

```gdscript
func draw(rng: RandomNumberGenerator) -> Dictionary:
	assert(can_draw())
	var chip := bag.draw(rng)
	var bonus := 0
	if int(chip["color"]) == Chip.ChipColor.RED:
		bonus = ChipEffects.toadstool_bonus(pot.count_color(Chip.ChipColor.ORANGE))
	var result := pot.place(chip, bonus)
	# ... existing exploded / empty bag stop logic ...
	return result
```

- [ ] **Step 6: Register test; run suite PASS; commit**

```bash
/usr/local/git/bin/git add game/chip_effects.gd game/pot.gd game/player_state.gd tests/test_chip_effects.gd tests/run_all_tests.gd
/usr/local/git/bin/git commit -m "$(cat <<'EOF'
feat: Set 1 toadstool bonus spaces from orange count

EOF
)"
```

---

### Task 3: Crow Skull (Gary) on-draw pick-one + Mandrake optional white return

**Files:**
- Modify: `game/player_state.gd` — `pending_crow_draws: Array`, `awaiting_crow_choice: bool`, `awaiting_mandrake: bool`
- Modify: `game/game_state.gd` / `phase_controller.gd` — resolve APIs
- Create: `ui/crow_skull_modal.gd` + `.tscn`
- Create: `ui/mandrake_modal.gd` + `.tscn`
- Modify: `board.gd` / `board.tscn` — instance modals; pause Draw/Stop while awaiting
- Extend: `tests/test_chip_effects.gd`, `tests/test_board_ui.gd`

**Interfaces:**
- Produces: after placing BLUE chip value `V`, draw up to `V` from bag into `pending_crow_draws`; set `awaiting_crow_choice`
- Produces: `GameState.resolve_crow_skull(player_index, keep_index: int)` — `keep_index == -1` returns all; else place kept chip (recursive on-draw), return rest to bag
- Produces: `GameState.resolve_mandrake(player_index, return_white: bool)` — if true and previous-before-yellow was white, remove that white from pot back to bag (yellow stays)
- Produces: signals or board polls `awaiting_*` to open modals

- [ ] **Step 1: Failing logic tests for crow + mandrake**

```gdscript
# Crow: bag seeded so draw places blue 2 then offers 2 chips
# Mandrake: place white then yellow; resolve_mandrake(true) → white back in bag, yellow remains; empty hole OK (indices unchanged)
```

Concrete crow test sketch:

```gdscript
var p := PlayerState.create_fresh()
p.bag = Bag.new()
p.bag.add(Chip.make(Chip.ChipColor.BLUE, 1))
p.bag.add(Chip.make(Chip.ChipColor.ORANGE, 1))
p.bag.add(Chip.make(Chip.ChipColor.WHITE, 1))
# Force order with a test-only Bag.peek/draw sequence OR inject after place:
# After implementing, call GameState helper that runs crow follow-up after a blue place.
```

Prefer testing pure helpers first:

```gdscript
static func begin_crow_skull(player: PlayerState, value: int, rng: RandomNumberGenerator) -> void:
	player.pending_crow_draws.clear()
	for i in value:
		if player.bag.is_empty():
			break
		player.pending_crow_draws.append(player.bag.draw(rng))
	player.awaiting_crow_choice = not player.pending_crow_draws.is_empty()

static func finish_crow_skull(player: PlayerState, keep_index: int) -> Dictionary:
	# returns place result if kept, else {}
```

- [ ] **Step 2: Implement helpers + GameState wrappers; wire `PlayerState.draw` to call `begin_crow_skull` after placing BLUE**

Disable further `can_draw` while `awaiting_crow_choice or awaiting_mandrake`.

- [ ] **Step 3: Mandrake — after placing YELLOW, if prior placement chip is white, set `awaiting_mandrake`**

`resolve_mandrake(true)`: find second-to-last placement, if white, remove it from `placements` array (do not move yellow), `bag.put_back(white)`.

- [ ] **Step 4: Modals**

`CrowSkullModal`: show pending chip textures as buttons; “Keep none”; on choose call controller.  
`MandrakeModal`: “Return white to bag” / “Keep white”.

Board `_refresh`: if awaiting, open modal and disable Draw/Stop/Flask.

- [ ] **Step 5: Suite PASS; commit**

```bash
/usr/local/git/bin/git commit -m "$(cat <<'EOF'
feat: Crow Skull pick-one and Mandrake white return

EOF
)"
```

---

### Task 4: Evaluation B — Spider, Moth, Ghost

**Files:**
- Extend: `game/chip_effects.gd`
- Modify: `game/game_state.gd` — call from `finish_bonus_die` → new `resolve_chip_actions()` before `begin_evaluation` grants, **or** at start of `begin_evaluation` before coins/VP
- Spec order: die → chip actions → ruby spaces → VP/shop  
  Current `begin_evaluation` already grants coins + ruby spaces + auto VP. Insert chip actions **first** inside `begin_evaluation` (before space ruby/VP), after die phase already finished.
- Extend: `tests/test_chip_effects.gd`, `tests/test_game_state.gd`

**Interfaces:**
- Produces: `ChipEffects.spider_ruby_count(pot: Pot) -> int`
- Produces: `ChipEffects.moth_reward(my_blacks: int, left: int, right: int, player_count: int) -> Dictionary` `{droplet: int, ruby: int}`
- Produces: `ChipEffects.ghost_best_tier(purple_count: int) -> Dictionary` `{vp, ruby, droplet}`
- Produces: `GameState.resolve_chip_actions()` applies to all players (start-player order: `for i in players.size(): idx = (start_player + i) % n`)

- [ ] **Step 1: Failing unit tests**

```gdscript
# Spider: last green → 1; last+prev green → 2; green earlier only → 0
# Moth 2p: equal → droplet 1 ruby 0; more → droplet 1 ruby 1
# Moth 3p: more than one neighbor → droplet 1; more than both → droplet 1 ruby 1
# Ghost: 0→none; 1→1vp; 2→1vp1ruby; 3→2vp1droplet
```

```gdscript
f += AssertUtil.eq(ChipEffects.ghost_best_tier(3), {"vp": 2, "ruby": 0, "droplet": 1}, "ghost 3+")
f += AssertUtil.eq(ChipEffects.moth_reward(2, 1, 1, 3), {"droplet": 1, "ruby": 1}, "moth beats both")
f += AssertUtil.eq(ChipEffects.moth_reward(2, 1, 2, 3), {"droplet": 1, "ruby": 0}, "moth beats one")
```

- [ ] **Step 2: Implement helpers**

```gdscript
static func spider_ruby_count(pot: Pot) -> int:
	var n := 0
	var size := pot.placements.size()
	if size == 0:
		return 0
	for offset in [1, 2]:
		var i := size - offset
		if i < 0:
			break
		if int(pot.placements[i]["chip"]["color"]) == Chip.ChipColor.GREEN:
			n += 1
	return n

static func ghost_best_tier(purple_count: int) -> Dictionary:
	if purple_count >= 3:
		return {"vp": 2, "ruby": 0, "droplet": 1}
	if purple_count == 2:
		return {"vp": 1, "ruby": 1, "droplet": 0}
	if purple_count == 1:
		return {"vp": 1, "ruby": 0, "droplet": 0}
	return {"vp": 0, "ruby": 0, "droplet": 0}

static func moth_reward(mine: int, left: int, right: int, player_count: int) -> Dictionary:
	if player_count <= 2:
		if mine > left: # left == only opponent
			return {"droplet": 1, "ruby": 1}
		if mine == left and mine > 0:
			return {"droplet": 1, "ruby": 0}
		# Almanac: equal (including 0?) → droplet. Official: "same number" includes 0==0.
		if mine == left:
			return {"droplet": 1, "ruby": 0}
		return {"droplet": 0, "ruby": 0}
	var beat_left := mine > left
	var beat_right := mine > right
	if beat_left and beat_right:
		return {"droplet": 1, "ruby": 1}
	if beat_left or beat_right:
		return {"droplet": 1, "ruby": 0}
	return {"droplet": 0, "ruby": 0}
```

Note: 2p moth uses opponent as `left`; pass `right = left` or overload.

- [ ] **Step 3: `GameState.resolve_chip_actions()` apply rubies/VP/`pending_droplet_bonus`**

Call at top of `begin_evaluation()` before scoring-space grants. Droplet from moth/ghost: add to `pending_droplet_bonus` (same deferral as die) **or** apply immediately to `pot.droplet` — spec Eval B is after brewing, so **immediate** `pot.droplet +=` is correct for chip actions (die droplet stays deferred until end_turn). Prefer immediate droplet for Eval B chip actions.

- [ ] **Step 4: Suite PASS; commit**

```bash
/usr/local/git/bin/git commit -m "$(cat <<'EOF'
feat: Set 1 Evaluation B spider moth ghost rewards

EOF
)"
```

---

### Task 5: Bonus die reward card UI

**Files:**
- Modify: `ui/bonus_die_modal.gd` + `.tscn`
- Modify: `tests/test_bonus_die.gd` / board bonus tests if they assert labels

**Interfaces:**
- Produces: after roll, `$RewardLabel.text` set from face; empty-pool ruby → `"No rubies left"`

- [ ] **Step 1: Add RewardLabel to modal scene; test label text helper**

```gdscript
static func reward_label(face: int, ruby_granted: bool) -> String:
	match face:
		BonusDie.Face.VP1: return "+1 Victory Point"
		BonusDie.Face.VP2: return "+2 Victory Points"
		BonusDie.Face.RUBY: return "Ruby" if ruby_granted else "No rubies left"
		BonusDie.Face.DROPLET: return "Droplet +1"
		BonusDie.Face.ORANGE: return "Pumpkin (Orange 1)"
		_: return ""
```

- [ ] **Step 2: On roll, set label visible; clear on next player**

- [ ] **Step 3: Suite PASS; commit**

```bash
/usr/local/git/bin/git commit -m "$(cat <<'EOF'
feat: show bonus die reward label after roll

EOF
)"
```

---

### Task 6: Flask drag-and-drop + Rewards strip

**Files:**
- Create: `ui/rewards_strip.gd` + `.tscn`
- Create: `ui/flask_drag.gd` (or script on board DrawStage node)
- Modify: `board.gd` / `board.tscn` — replace RewardsBar; hide FlaskButton; add FlaskDrag near table
- Modify: `tests/test_board_ui.gd` — expect `RewardsStrip` Control; FlaskButton hidden or absent from required list

**Interfaces:**
- Produces: `RewardsStrip.refresh(pot: Pot) -> void` builds Now + up to 5 Next tiles
- Produces: flask `gui_input` / drag; drop if cauldron `get_global_rect().has_point(pos)` → `use_flask_active()`

- [ ] **Step 1: Failing board test for RewardsStrip node + refresh tile count ≥ 1**

- [ ] **Step 2: Implement rewards strip**

Horizontal `ScrollContainer` → `HBoxContainer` of panels (~120×100). Each tile: Space N, money/VP/ruby icons from `assets/ui/track/icon_*_mini.png`. First tile labeled `Now`.

Board positions: ~`offset_left=426, offset_top=120, offset_right=900, offset_bottom=240` (taller); keep ExplosionRiskBar above.

- [ ] **Step 3: Flask drag**

`TextureRect` flask at table; on drag end over cauldron, call flask; snap home otherwise. Hide `$FlaskButton` (`visible = false`). Update `$FlaskLabel` still.

- [ ] **Step 4: Suite PASS; commit**

```bash
/usr/local/git/bin/git commit -m "$(cat <<'EOF'
feat: rewards strip and drag flask onto cauldron

EOF
)"
```

---

### Task 7: Shop book-centric buy + Continue gating

**Files:**
- Modify: `game/game_state.gd` — `has_affordable_buy(player_index) -> bool`
- Modify: `node_2d.gd` — hide/clear main WhiteShop list as primary; BuyRow on shelves already exist — make evaluation default show Take VP / Go Shop only; when shop, books clickable; Done/Continue enabled only when `purchases.size()==2 or not has_affordable_buy`; never auto-finish
- Modify: `tests/test_shop_ui.gd`

**Interfaces:**
- Produces: `GameState.has_affordable_buy(player_index: int) -> bool` — any sku with `can_buy`
- Produces: `_refresh_evaluation` sets `$EvaluationPanel/DoneButton.visible = true` when shop and (2 buys or !affordable); `disabled = false` only then; still requires press

- [ ] **Step 1: Failing tests**

```gdscript
# With 0 coins in shop: Done visible and enabled; finish_shop still needs button path
# After 2 purchases: Done enabled
# After 1 purchase with remaining affordable: Done disabled
```

- [ ] **Step 2: Implement `has_affordable_buy`**

```gdscript
func has_affordable_buy(player_index: int) -> bool:
	for sku_id in market:
		if can_buy(player_index, sku_id):
			return true
	return false
```

- [ ] **Step 3: Shop UI**

- Keep TakeVP / GoShop as today for exploded / entry
- When `chose_shop`: focus shelves; ensure each shelf `BuyRow` builds from `MarketCatalog.skus_for_shelf` (already largely true)
- Hide or collapse `$EvaluationPanel/WhiteShop` ItemList (set `visible = false`) so the big dump is gone
- Done button:

```gdscript
var shop_ready := player.chose_shop and (
	player.purchases.size() >= 2 or not state.has_affordable_buy(state.eval_player)
)
$EvaluationPanel/DoneButton.visible = player.chose_shop
$EvaluationPanel/DoneButton.disabled = not shop_ready
# Non-shop evaluation still uses existing chose_vp / conversion rules for Done
```

Merge carefully with round-9 conversion Done rules.

- [ ] **Step 4: Suite PASS; commit**

```bash
/usr/local/git/bin/git commit -m "$(cat <<'EOF'
feat: book-centric shop buy flow with gated Continue

EOF
)"
```

---

## Spec coverage checklist

| Spec section | Task |
|---|---|
| Color remapping | 1 |
| Toadstool on-draw | 2 |
| Crow Skull + Mandrake | 3 |
| Spider / Moth / Ghost Eval B | 4 |
| Bonus die reward card | 5 |
| Flask drag | 6 |
| Rewards strip | 6 |
| Shop book buy + Continue | 7 |

## Self-review notes

- `ChipArt` remap must ship with Task 1 or textures break after color change.
- Crow Skull nested blue keeps must re-enter crow flow.
- Eval B droplet = immediate; die droplet = deferred (`pending_droplet_bonus`) — do not conflate.
- No placeholders left in task steps.

---

**Plan complete and saved to `docs/superpowers/plans/2026-07-29-set1-effects-ui-polish.md`.**

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — run tasks in this session with checkpoints  

Which approach?
