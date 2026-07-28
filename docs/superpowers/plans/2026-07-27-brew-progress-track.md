# Brew Progress Track & BrewTable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a BrewTable with vertical liquid progress track + synced token history (spiral stones hidden), dynamic shop/ruby supply for 1–15 players, bonus-die phase, and evaluation/shop as overlays on the same scene—without replacing ingredient books/shelves or the rune cauldron.

**Architecture:** Keep `GameState` / `PhaseController` / `GameSession`. Add `SupplyScaler` for market/ruby pools. Add `ProgressTrack` + `TokenHistory` UI nodes on `board.tscn`. Insert `bonus_die` phase before evaluation grants finish. Instance shop/eval as a `CanvasLayer` overlay instead of `change_scene` after migration.

**Tech Stack:** Godot 4.7, GDScript, headless suite via `/opt/homebrew/bin/godot --headless --path . --import` then `-s res://tests/run_all_tests.gd` (or `./tests/run.sh`).

**Spec:** `docs/superpowers/specs/2026-07-27-brew-progress-track-design.md`

## Global Constraints

- Cauldron rune + draw flight stay; do **not** replace shelf/book art.
- Spiral stones / `Gameboard` gameplay markers: hidden or removed; vertical track is sole progress UI.
- Reward preview always = `Pot.scoring_space()` (space after last token).
- Supply: `sharedTokenSupply = round(75 * n)`, `sharedRubySupply = round(8 * n)`.
- SKU weight: `value_band(value) / max(cost, 1)` with bands `{1:4, 2:2, 3:1, 4:1, 6:1}`; largest-remainder integers.
- Pot-space rubies always grant; bonus-die rubies only if `rubies_remaining > 0`.
- Fortune Teller / full rats: out of scope (helpers only).
- Use `Chip.ChipColor` (never `Chip.Color`).
- Prefer `/usr/local/git/bin/git` for commits if wrapper rejects `--trailer`.
- Godot: `/opt/homebrew/bin/godot`.

## File structure

| Path | Role |
|---|---|
| `assets/ui/track/progress_segment_filled.png` | Filled liquid tile |
| `assets/ui/track/progress_segment_empty.png` | Empty liquid tile |
| `assets/ui/track/icon_money_mini.png` | Track money icon (optional if reusing HUD coin at small size) |
| `assets/ui/track/icon_vp_mini.png` | Track VP icon |
| `assets/ui/track/icon_ruby_mini.png` | Track ruby icon |
| `game/supply_scaler.gd` | Token/ruby/fortune-size helpers + market build |
| `game/market_catalog.gd` | Accept scaled stocks; add white SKUs + costs |
| `reference/token_shop_prices.csv` | Add white 1–4 price rows |
| `game/game_state.gd` | `rubies_remaining`; scaled market; bonus die API |
| `game/phase_controller.gd` | `bonus_die` phase + signals |
| `game/bonus_die.gd` | Face enum + resolve |
| `ui/progress_track.gd` + `.tscn` | Vertical segment strip |
| `ui/token_history.gd` + `.tscn` | Synced history column |
| `ui/bonus_die_modal.gd` + `.tscn` | Hotseat roll UI |
| `board.gd` / `board.tscn` | BrewTable: host track/history/danger; hide stones; overlay shop |
| `main_menu.gd` / `main_menu.tscn` | Player count 1–15 |
| `node_2d.gd` | Work as overlay when parented under BrewTable |
| `tests/test_supply_scaler.gd` | New |
| `tests/test_bonus_die.gd` | New |
| `tests/test_progress_track_ui.gd` | New |
| `tests/test_market.gd` | Update stock expectations |
| `tests/test_board_ui.gd` | Stones hidden; track nodes; no mid-round scene swap |
| `tests/run_all_tests.gd` | Register new tests |

---

### Task 1: Generate progress segment (+ mini) assets

**Files:**
- Create: `assets/ui/track/progress_segment_filled.png`
- Create: `assets/ui/track/progress_segment_empty.png`
- Create: `assets/ui/track/icon_money_mini.png`
- Create: `assets/ui/track/icon_vp_mini.png`
- Create: `assets/ui/track/icon_ruby_mini.png`

**Interfaces:**
- Consumes: none (art generation)
- Produces: 100×100 (or 128×128) PNGs with transparent backgrounds; filled/empty identical footprint

- [ ] **Step 1: Generate filled + empty segment PNGs**

Use image generation (or PIL) to create flat/clean glossy green filled tile and matching dashed/glass empty tile, both square, transparent outside the tile. Save under `assets/ui/track/`. Resize to 128×128 with PIL if needed.

- [ ] **Step 2: Generate or downscale mini money/VP/ruby icons**

Either generate small transparent icons or copy/resize existing `assets/ui/board/icon_coin.png`, `icon_vp.png`, `icon_ruby.png` to 48×48 into `assets/ui/track/icon_*_mini.png`.

- [ ] **Step 3: Import in Godot**

Run:

```bash
/opt/homebrew/bin/godot --headless --path . --import
```

Expected: `.import` sidecars created; no crash.

- [ ] **Step 4: Commit**

```bash
/usr/local/git/bin/git add assets/ui/track/
/usr/local/git/bin/git commit -m "$(cat <<'EOF'
assets: add progress track segment and mini reward icons

EOF
)"
```

---

### Task 2: SupplyScaler + white SKUs + scaled market

**Files:**
- Create: `game/supply_scaler.gd`
- Modify: `game/market_catalog.gd`
- Modify: `reference/token_shop_prices.csv` (add white rows)
- Modify: `game/game_state.gd` (`new_game` uses scaler; `rubies_remaining`)
- Create: `tests/test_supply_scaler.gd`
- Modify: `tests/test_market.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `MarketCatalog` SKU template (costs/colors/values), `numPlayers: int`
- Produces:
  - `SupplyScaler.shared_token_supply(n: int) -> int` → `int(round(75.0 * n))`
  - `SupplyScaler.shared_ruby_supply(n: int) -> int` → `int(round(8.0 * n))`
  - `SupplyScaler.fortune_deck_size(n: int) -> int` → `int(round(9.0 * n))` (unused by gameplay yet)
  - `SupplyScaler.value_band(value: int) -> int`
  - `SupplyScaler.build_market(num_players: int) -> Dictionary` (sku_id → entry with scaled `stock`)
  - `GameState.rubies_remaining: int`
  - `GameState.new_game` sets `market = SupplyScaler.build_market(player_count)` and `rubies_remaining = SupplyScaler.shared_ruby_supply(player_count)`

White CSV rows to append:

```csv
Cherry Bomb,1 token,4
Cherry Bomb,2 token,6
Cherry Bomb,3 token,9
Cherry Bomb,4 token,12
```

Add `CHAR_META` entry:

```gdscript
"Cherry Bomb": {
	"slug": "white",
	"color": Chip.ChipColor.WHITE,
	"unlock": 1,
	"shelf": "WhiteShop",
},
```

- [ ] **Step 1: Write failing tests** in `tests/test_supply_scaler.gd`

```gdscript
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
```

Update `tests/test_market.gd`: stock is no longer always 10 — assert `default_stock()` either becomes `build_market(1)` wrapper or tests call `SupplyScaler.build_market(1)` and drop hard-coded `stock == 10` / `size == 16` (size becomes 20 with whites).

- [ ] **Step 2: Run tests — expect FAIL**

```bash
/opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL missing `SupplyScaler` / wrong stock sums.

- [ ] **Step 3: Implement `SupplyScaler` + CSV/meta + wire `GameState`**

```gdscript
# game/supply_scaler.gd
class_name SupplyScaler
extends RefCounted

const VALUE_BAND := {1: 4, 2: 2, 3: 1, 4: 1, 6: 1}

static func shared_token_supply(n: int) -> int:
	return int(round(75.0 * n))

static func shared_ruby_supply(n: int) -> int:
	return int(round(8.0 * n))

static func fortune_deck_size(n: int) -> int:
	return int(round(9.0 * n))

static func value_band(value: int) -> int:
	return int(VALUE_BAND.get(value, 1))

static func build_market(num_players: int) -> Dictionary:
	MarketCatalog.ensure_loaded()
	var template := MarketCatalog.default_stock_template() # add this accessor if needed
	var ids: Array = template.keys()
	var weights: Array = []
	var total_w := 0.0
	for id in ids:
		var e: Dictionary = template[id]
		var w := float(value_band(int(e["value"]))) / float(maxi(int(e["cost"]), 1))
		weights.append(w)
		total_w += w
	var target := shared_token_supply(num_players)
	var raw: Array = []
	var floors: Array = []
	var frac_sum := 0
	for i in ids.size():
		var exact := (weights[i] / total_w) * float(target)
		var fl := int(floor(exact))
		floors.append(fl)
		raw.append(exact - float(fl))
		frac_sum += fl
	var rem := target - frac_sum
	var order: Array = range(ids.size())
	order.sort_custom(func(a, b): return raw[a] > raw[b])
	for i in rem:
		floors[order[i]] += 1
	var out := {}
	for i in ids.size():
		var entry: Dictionary = template[ids[i]].duplicate(true)
		entry["stock"] = floors[i]
		out[ids[i]] = entry
	return out
```

`MarketCatalog.default_stock()` should call `SupplyScaler.build_market(1)` for backward-compatible tests **or** expose `default_stock_template()` with stock ignored and only `build_market` used from `GameState`.

```gdscript
# GameState.new_game
game.market = SupplyScaler.build_market(player_count)
game.rubies_remaining = SupplyScaler.shared_ruby_supply(player_count)
```

- [ ] **Step 4: Run tests — expect PASS for supply/market**

- [ ] **Step 5: Commit**

```bash
/usr/local/git/bin/git add game/supply_scaler.gd game/market_catalog.gd game/game_state.gd reference/token_shop_prices.csv tests/
/usr/local/git/bin/git commit -m "$(cat <<'EOF'
feat: scale shop and ruby supply by player count

EOF
)"
```

---

### Task 3: Main menu player count 1–15

**Files:**
- Modify: `main_menu.tscn`
- Modify: `main_menu.gd`
- Modify: `tests/test_board_ui.gd` or add `tests/test_main_menu.gd` if easy; otherwise verify via `GameSession.start_local(15)` in supply/game tests

**Interfaces:**
- Consumes: `GameSession.start_local(player_count: int)`
- Produces: UI control `PlayerCount` (SpinBox or HSlider) min 1 max 15, default 2

- [ ] **Step 1: Write failing assertion**

In `tests/test_supply_scaler.gd` (or new file):

```gdscript
	var packed := load("res://main_menu.tscn") as PackedScene
	var menu := packed.instantiate()
	f += AssertUtil.truthy(menu.get_node_or_null("PlayerCount") != null, "PlayerCount control")
	var pc := menu.get_node("PlayerCount")
	f += AssertUtil.eq(pc.min_value, 1.0, "min 1")
	f += AssertUtil.eq(pc.max_value, 15.0, "max 15")
	menu.free()
```

- [ ] **Step 2: Run — expect FAIL** (no PlayerCount)

- [ ] **Step 3: Implement menu**

Replace `Players2` CheckButton with `SpinBox` named `PlayerCount` (min 1, max 15, value 2).

```gdscript
func _on_check_button_pressed() -> void:
	var n := 2
	if has_node("PlayerCount"):
		n = int($PlayerCount.value)
	n = clampi(n, 1, 15)
	GameSession.start_local(n)
	get_tree().change_scene_to_file("res://board.tscn")
```

Keep Start button signal wired to this method (rename method if desired).

- [ ] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit**

```bash
/usr/local/git/bin/git commit -am "$(cat <<'EOF'
feat: main menu player count 1-15

EOF
)"
```

---

### Task 4: Bonus die rules

**Files:**
- Create: `game/bonus_die.gd`
- Modify: `game/game_state.gd`
- Modify: `game/phase_controller.gd`
- Create: `tests/test_bonus_die.gd`
- Modify: `tests/run_all_tests.gd`
- Modify: existing phase/full-loop tests if they assume potions → evaluation immediately

**Interfaces:**
- Consumes: player pots, `rubies_remaining`
- Produces:
  - `BonusDie.Face` enum: `VP1`, `VP2`, `RUBY`, `DROPLET`, `ORANGE`
  - `BonusDie.roll(rng: RandomNumberGenerator) -> int` (face id 0..4)
  - `GameState.bonus_die_eligible() -> Array[int]`
  - `GameState.begin_bonus_die() -> void` sets `phase = "bonus_die"`
  - `GameState.apply_bonus_die(player_index: int, face: int) -> void`
  - `GameState.finish_bonus_die() -> void` calls existing grant path currently in `begin_evaluation` (split grants)
  - `PhaseController`: on all stopped → `begin_bonus_die` not `begin_evaluation`; signal `bonus_die_needed`; methods `roll_bonus_die_active` / `finish_bonus_die_phase`

Split evaluation: move coin/VP/ruby grants from immediate `begin_evaluation` into `finish_bonus_die` → `begin_evaluation` **or** keep `begin_evaluation` for grants and insert bonus die **before** it:

Recommended flow:

```
all stopped → phase=bonus_die → (rolls) → begin_evaluation() grants as today
```

- [ ] **Step 1: Write failing tests**

```gdscript
class_name TestBonusDie
extends RefCounted

static func run() -> int:
	var f := 0
	var g := GameState.new_game(2, 1)
	g.begin_round()
	# P0 farther non-exploded
	g.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 4))
	g.players[1].pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	g.players[0].stopped = true
	g.players[1].stopped = true
	var el: Array = g.bonus_die_eligible()
	f += AssertUtil.eq(el, [0], "sole leader eligible")
	g.players[0].exploded = true
	el = g.bonus_die_eligible()
	f += AssertUtil.eq(el, [1], "exploded excluded")
	# tie
	g = GameState.new_game(2, 1)
	g.begin_round()
	g.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 2))
	g.players[1].pot.place(Chip.make(Chip.ChipColor.ORANGE, 2))
	g.players[0].stopped = true
	g.players[1].stopped = true
	el = g.bonus_die_eligible()
	f += AssertUtil.eq(el.size(), 2, "tie both eligible")
	var before_vp := g.players[0].vp
	g.apply_bonus_die(0, BonusDie.Face.VP2)
	f += AssertUtil.eq(g.players[0].vp, before_vp + 2, "VP2 applied")
	g.rubies_remaining = 0
	var rubies_before := g.players[0].rubies
	g.apply_bonus_die(0, BonusDie.Face.RUBY)
	f += AssertUtil.eq(g.players[0].rubies, rubies_before, "no ruby if pool empty")
	return f
```

Phase controller test: after both stop, `state.phase == "bonus_die"` before finish.

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement**

```gdscript
# bonus_die.gd
class_name BonusDie
extends RefCounted
enum Face { VP1, VP2, RUBY, DROPLET, ORANGE }

static func roll(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, 4)
```

```gdscript
func bonus_die_eligible() -> Array:
	var best := -1
	for p in players:
		if p.exploded:
			continue
		best = maxi(best, p.pot.scoring_space())
	var out: Array = []
	if best < 0:
		return out
	for i in players.size():
		var p: PlayerState = players[i]
		if not p.exploded and p.pot.scoring_space() == best:
			out.append(i)
	return out

func apply_bonus_die(player_index: int, face: int) -> void:
	var p := players[player_index]
	match face:
		BonusDie.Face.VP1:
			p.vp += 1
		BonusDie.Face.VP2:
			p.vp += 2
		BonusDie.Face.RUBY:
			if rubies_remaining > 0:
				p.rubies += 1
				rubies_remaining -= 1
		BonusDie.Face.DROPLET:
			p.pot.droplet += 1
		BonusDie.Face.ORANGE:
			p.bag.add(Chip.make(Chip.ChipColor.ORANGE, 1))
```

`PhaseController._after_potions_action`:

```gdscript
	if state.all_players_stopped():
		state.phase = "bonus_die"
		phase_changed.emit(state.phase)
```

Add `finish_bonus_die_phase()` → `state.begin_evaluation(); phase_changed.emit(...)`.

- [ ] **Step 4: Run tests — PASS** (fix full-loop / shop UI if they auto-assumed evaluation)

- [ ] **Step 5: Commit**

```bash
/usr/local/git/bin/git commit -am "$(cat <<'EOF'
feat: bonus die phase for farthest non-exploded players

EOF
)"
```

---

### Task 5: ProgressTrack + TokenHistory UI components

**Files:**
- Create: `ui/progress_track.gd`, `ui/progress_track.tscn`
- Create: `ui/token_history.gd`, `ui/token_history.tscn`
- Create: `tests/test_progress_track_ui.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `Pot`, `PotTrack`, chip textures under `res://assets/ui/board/`
- Produces:
  - `ProgressTrack.refresh(pot: Pot) -> void`
  - `ProgressTrack.preview_space() -> int` (for tests: equals `pot.scoring_space()`)
  - `ProgressTrack.scroll_offset: float` + signal `scroll_changed(offset)`
  - `TokenHistory.refresh(pot: Pot) -> void`
  - `TokenHistory.set_scroll_offset(offset: float) -> void`
  - Linked: board connects both `scroll_changed` bidirectionally with a guard flag

Segment layout: `VBox` or manual `Y = (max_space - space) * segment_h` so space 0 at bottom.

Filled rule: space `s` is filled if `s <= pot._last_index()` (use a public `Pot.last_index()` helper). Preview highlight on `pot.scoring_space()`.

- [ ] **Step 1: Add `Pot.last_index() -> int`** (public wrapper of `_last_index`) + test in `test_pot.gd`

- [ ] **Step 2: Write UI tests**

```gdscript
	var track_scene := load("res://ui/progress_track.tscn") as PackedScene
	var track := track_scene.instantiate()
	var pot := Pot.new()
	pot.place(Chip.make(Chip.ChipColor.ORANGE, 2))
	track.refresh(pot)
	f += AssertUtil.eq(track.preview_space(), 3, "preview is scoring space")
```

- [ ] **Step 3: Run — FAIL**

- [ ] **Step 4: Implement scenes**

`progress_track.tscn`: `ScrollContainer` → `Control` content with stacked `TextureRect` segments + label row for money/VP/ruby.

`token_history.tscn`: parallel `ScrollContainer`; place token `TextureRect`s at Y matching landing index; `rat` stub `TextureRect` at droplet Y using `res://assets/ui/board/` rat or `TODO` rat_stone copied into `assets/ui/board/rat_stone.png` if missing from board folder.

Reuse board `_texture_for_chip` logic via shared `ChipArt.texture_for(chip) -> Texture2D` in `game/chip_art.gd` to avoid duplication.

- [ ] **Step 5: Run — PASS**

- [ ] **Step 6: Commit**

```bash
/usr/local/git/bin/git commit -am "$(cat <<'EOF'
feat: progress track and token history UI components

EOF
)"
```

---

### Task 6: Integrate BrewTable on board (hide stones, danger bar, live refresh)

**Files:**
- Modify: `board.tscn`, `board.gd`
- Modify: `tests/test_board_ui.gd`

**Interfaces:**
- Consumes: Task 5 components; existing DrawStage
- Produces: BrewTable layout; stones hidden; track/history refresh on draw/flask

- [ ] **Step 1: Update board UI tests**

```gdscript
	f += AssertUtil.truthy(board.get_node_or_null("ProgressTrack") != null, "ProgressTrack")
	f += AssertUtil.truthy(board.get_node_or_null("TokenHistory") != null, "TokenHistory")
	var gb := board.get_node_or_null("Gameboard")
	if gb:
		f += AssertUtil.eq(gb.visible, false, "spiral board hidden")
	# stone instances: either absent or visible=false
	for child in board.get_children():
		if str(child.name).begins_with("stone"):
			f += AssertUtil.eq(child.visible, false, "stone hidden")
```

Remove expectations that depend on `PlacementsList` as sole history if removed; keep list optional/hidden.

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Integrate**

Instance `ProgressTrack` + `TokenHistory` left of DrawStage. In `_ready` / `_on_drawn` / `_on_flask_used` / `_refresh`:

```gdscript
	$ProgressTrack.refresh(player.pot)
	$TokenHistory.refresh(player.pot)
	_update_explosion_risk(...)
```

Hide `Gameboard` and all `stone*` children. Wire scroll signals with `_syncing_scroll` bool.

Danger: keep `ExplosionRiskBar` or replace with boom-berry slots from `TODO/new images` copied to `assets/ui/track/` — either is fine if white sum mapping stays `mini(sum, 8)`.

- [ ] **Step 4: Run board + full suite — PASS**

- [ ] **Step 5: Commit**

```bash
/usr/local/git/bin/git commit -am "$(cat <<'EOF'
feat: BrewTable progress track integrated; hide spiral stones

EOF
)"
```

---

### Task 7: Bonus die modal + BrewTable phase handling

**Files:**
- Create: `ui/bonus_die_modal.tscn`, `ui/bonus_die_modal.gd`
- Modify: `board.gd`
- Modify: `tests/test_board_ui.gd` / `tests/test_phase_controller.gd`

**Interfaces:**
- Consumes: `PhaseController` bonus die API; `TODO/new images/bonus_die_*.png` → copy to `assets/ui/track/` or `assets/ui/board/`
- Produces: modal shows face; on confirm applies and advances eligibility queue; when queue empty calls `finish_bonus_die_phase()`

- [ ] **Step 1: Failing test** — after both players stop with controller, `state.phase == "bonus_die"` and board has `BonusDieModal` node.

- [ ] **Step 2: Implement modal**

Queue = `bonus_die_eligible()`. For each index: show Roll button → `BonusDie.roll` → display texture `bonus_die_{face+1}.png` → Apply → next. Then `finish_bonus_die_phase()`.

Board `_on_phase`: if `bonus_die`, show modal; if `evaluation`/`shop`, show overlay (Task 8); **do not** `change_scene` for evaluation anymore once Task 8 lands — for this task, allow temporary scene change still if overlay not ready, but prefer showing modal only.

- [ ] **Step 3: Tests PASS**

- [ ] **Step 4: Commit**

```bash
/usr/local/git/bin/git commit -am "$(cat <<'EOF'
feat: bonus die modal on BrewTable

EOF
)"
```

---

### Task 8: Shop/evaluation overlay on BrewTable (remove scene swap)

**Files:**
- Modify: `board.tscn` / `board.gd`
- Modify: `node_2d.gd` (detect overlay mode: if get_parent() is CanvasLayer under board, skip full-screen assumptions as needed)
- Modify: `tests/test_board_ui.gd`, `tests/test_shop_ui.gd`, `tests/test_full_loop.gd`

**Interfaces:**
- Consumes: existing `node_2d.tscn` shop/eval UI
- Produces: `ShopOverlay` CanvasLayer child; `phase_changed` to evaluation/shop instances overlay once; `end_turn_and_continue` hides overlay and stays on board

- [ ] **Step 1: Failing test**

```gdscript
	# board must NOT change_scene on evaluation
	# After controller forces evaluation, board still in tree and has ShopOverlay visible
```

Implement by spying: replace `_on_phase` so evaluation does not call `change_scene_to_file`.

- [ ] **Step 2: Implement overlay**

```gdscript
func _on_phase(phase: String) -> void:
	if phase == "bonus_die":
		$BonusDieModal.show_for_state(_controller())
		return
	if phase == "evaluation" or phase == "shop":
		_ensure_shop_overlay()
		$ShopOverlay.visible = true
		return
	if phase == "potions":
		if has_node("ShopOverlay"):
			$ShopOverlay.visible = false
	_refresh()
```

`_ensure_shop_overlay`: instance `node_2d.tscn` under `CanvasLayer` named `ShopOverlay` once.

Ensure `node_2d.gd` `Done` / continue still calls `PhaseController.end_turn_and_continue` and does not change to board scene if already on board (use `get_tree().current_scene` check).

- [ ] **Step 3: Full suite PASS** including shop buys and full loop

- [ ] **Step 4: Commit**

```bash
/usr/local/git/bin/git commit -am "$(cat <<'EOF'
feat: evaluation and shop overlays on BrewTable

EOF
)"
```

---

### Task 9: Regression polish + docs status

**Files:**
- Modify: `docs/superpowers/specs/2026-07-27-brew-progress-track-design.md` status → Implemented
- Modify: `docs/manual-todo.md` if present (optional short note)
- Run full suite

- [ ] **Step 1: Run full suite**

```bash
/opt/homebrew/bin/godot --headless --path . --import
/opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd
```

Expected: `ALL TESTS PASSED`

- [ ] **Step 2: Manual smoke checklist** (record in commit message or manual-todo)

1. Menu set 3 players → start  
2. Draw chips → track fills bottom-up; preview highlight moves to scoring space  
3. History icons align; scroll syncs  
4. Explode → danger; bonus die skipped for exploded leader  
5. Shop overlay on same scene; books unchanged  
6. Cauldron flight unchanged  

- [ ] **Step 3: Commit**

```bash
/usr/local/git/bin/git commit -am "$(cat <<'EOF'
docs: mark brew progress track spec implemented

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| Vertical liquid track from segments | 1, 5, 6 |
| Reward preview = scoring_space | 5, 6 |
| Token history + linked scroll | 5, 6 |
| Hide spiral stones | 6 |
| Keep cauldron / no shelf replace | Global + 6, 8 |
| Danger bar | 6 |
| Supply 75n / 8n + weights | 2 |
| Menu 1–15 | 3 |
| Bonus die | 4, 7 |
| Shared BrewTable overlays | 8 |
| Fortune size helper only | 2 (`fortune_deck_size`) |
| Rat stub only | 5 |
| White buyable SKUs in pool | 2 |

## Placeholder scan

No TBD steps; white costs explicitly listed; overlay migration path explicit.

## Type consistency

- `SupplyScaler.build_market(num_players: int) -> Dictionary`
- `GameState.rubies_remaining: int`
- `BonusDie.Face` + `apply_bonus_die(player_index, face)`
- `ProgressTrack.refresh(pot)` / `preview_space()`
- Phase string `"bonus_die"` before `"evaluation"`
