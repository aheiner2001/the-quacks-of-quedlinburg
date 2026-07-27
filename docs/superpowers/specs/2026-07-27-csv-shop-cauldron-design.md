# CSV Data, Shop Panels & Cauldron Draw Feel — Design

**Date:** 2026-07-27  
**Status:** Approved for implementation planning  
**Engine:** Godot 4.7 (existing Quacks core loop)  
**Depends on:** `docs/superpowers/specs/2026-07-27-quacks-core-loop-design.md`  
**Reference data:** `reference/levels.csv`, `reference/token_shop_prices.csv`

---

## Goal

Plug real pot-track and shop-price data into the live Godot game, upgrade shelf shopping to combined rulebook + purchase menus, switch flask refill to a 2-ruby confirm flow, and add placeholder cauldron draw presentation (bob, explosion-risk bar, CSV-driven progress/rewards bar).

## Non-goals

- Board-as-reference-screen redesign (level indicator / next-next navigation as a separate product slice)
- Fortune cards, rats, bonus die, Almanac chip effects
- Final art for bag/cauldron (placeholders only)
- Online multiplayer / 15-player sync
- Changing the 9-round / Turn 9 conversion rules (except scoring numbers from CSV)

## Locked decisions

| Topic | Decision |
|---|---|
| Scope | A+B+C together: CSV rules + shop UX + cauldron feel |
| Pot length | Full `levels.csv` **nodes 1–54**; no hard-coded space-33 special case |
| Flask | **2 rubies**, confirm popup (not coin shop SKU) |
| Shelf click | One panel: **rulebook/art + buy buttons** (1/2/4 etc. from CSV) |
| Unspent coins | Official: leftover coins **lost** when leaving shop; UI warns |
| Art | Placeholders for bag/cauldron |
| Architecture | Extend `GameState` / `PhaseController` / existing scenes |

---

## Architecture

Unchanged layering:

1. **`GameState`** — mutations only (buy tiers, ruby grant, flask ruby refill, pot cap 54).
2. **`PhaseController`** — intents + signals (`chip_drawn` still fires after rules resolve; UI may delay visual).
3. **Scenes** — `node_2d.tscn` (shop panels), `board.tscn` (draw stage visuals).

Data loaders sit beside rules:

- `game/pot_track.gd` — reads levels CSV
- `game/market_catalog.gd` — reads shop prices CSV (+ unlock metadata)

```
reference/*.csv → PotTrack / MarketCatalog → GameState → Board UI / Shop UI
```

---

## Data: levels.csv → PotTrack

**File:** `reference/levels.csv`  
Columns: `Node num`, `Money`, `victory poitns`, `ruby?` (tolerate header typos).

| API | Behavior |
|---|---|
| `coins_for_space(space)` | `0` if space ≤ 0; else money for that node; clamp space to max node (54) when reading past end |
| `vp_for_space(space)` | VP for node; `0` if ≤ 0 |
| `has_ruby(space)` | true if CSV `ruby?` is yes for that node |
| `max_space()` | 54 |
| `upcoming_milestones(from_space, count)` | next nodes with useful labels for the progress bar (money/VP/ruby changes) |

**Placement:** `Pot.place` clamps chip index to `PotTrack.max_space()` (54), not 33.

**Evaluation:**  
`player.coins = PotTrack.coins_for_space(scoring_space)`  
`vp` from `vp_for_space`  
If `has_ruby(scoring_space)` → `player.rubies += 1` (exploded or not).

Remove ≥33 → 35/15 hardcoded branch; node 54 already has Money=35, VP=15.

---

## Data: token_shop_prices.csv → MarketCatalog

**File:** `reference/token_shop_prices.csv`  
Columns: `character`, `token_type`, `cost`.

Parse `token_type` like `1 token` / `2 token` / `4 token` / `6 token` → integer **value**.

**SKU id scheme:** `{slug}_{value}` e.g. `gary_1`, `gary_2`, `gary_4`, `pumpkin_1`, `pumpkin_6`.

**Character → shelf / color mapping**

| CSV character | Shelf / UI | Color | Unlock round |
|---|---|---|---|
| Scary Gary | Gary / info | BLACK (or dedicated) | 1 |
| Pumpkin | PumpkinShelf | ORANGE | 1 |
| Spider | SpiderShelf | BLUE | 1 |
| Mushroom | ShroomInfo | GREEN | 1 |
| Ghost (Puts) | Pootsshelf | PURPLE | 3 |
| Mandrake (Toby Turnip) | MandrakeShelf | YELLOW | 2 |
| Moth | MothShelf | RED | 1 |

Optional whites remain as catalog extras if still desired; not in this CSV.

**Stock:** keep finite stock per SKU (e.g. 10) unless CSV later adds supply.

**Flask:** not a coin SKU. Remove `flask_refill` coin entry from default catalog.

---

## Shop UX

### Combined ingredient panel

On shelf press during an eligible shop phase:

1. Show existing art/rulebook content for that ingredient.
2. Below (or beside): buy buttons for each CSV row for that character, labeled `{value} — {cost} coins`.
3. Disable buttons when: cannot afford, stock 0, purchase would violate max-2 / same-color rule, round locked, Turn 9, or player not in shop mode.
4. On press: `PhaseController.buy_active(sku_id)` → coins deducted immediately.

Info-only mode (not shopping): same panel without active buy buttons (or buttons hidden).

### Coins

Warn before Done: “Unspent coins will be lost.”  
`finish_shop` / end eval clears leftover coins (already zeroed next round; ensure UI doesn’t imply they persist).

### Flask confirm

Flask control opens modal: title “Refill Flask”, body “Cost: 2 rubies”, Confirm / Cancel.  
Confirm calls new `GameState.refill_flask(player_index) -> bool`:

- Requires `rubies >= 2`
- Sets `flask_full = true`, `rubies -= 2`
- Returns false if already full or can’t afford (UI disables Confirm when invalid)

May be used during evaluation/end-of-turn window when rubies are available (not during potions draw except existing flask **use** for undoing whites).

---

## Cauldron draw feel (board)

Cosmetic layer on potions phase:

| Element | Behavior |
|---|---|
| Bag + cauldron placeholders | Colored rects/sprites with labels |
| Draw motion | On `chip_drawn`, tween chip icon bag→cauldron, short bob, then update pot UI |
| Explosion-risk bar | `white_sum / 8` visual (boom when sum **> 7**); distinct “exploded” state |
| Progress / rewards bar | From CSV: show “if stop now” money/VP/ruby for current scoring space; show next few milestone nodes ahead |

Rules resolution stays synchronous in `GameState`; animation may queue/skip if Draw is pressed again quickly.

---

## Error handling

- Missing CSV / bad row: `push_error` and empty track/catalog in debug; tests assert happy-path files exist.
- Illegal buy/refill: no state change; button disabled or toast.
- Space > 54: clamp to 54 for scoring and placement.

---

## Testing

- PotTrack: node 6 money 5 VP 0 ruby yes; node 23 money 18 VP 5; node 54 money 35 VP 15; no ruby on 54.
- MarketCatalog: Gary costs 5/10/19 for values 1/2/4; Mandrake unlock round 2; Poots unlock 3.
- GameState: scoring uses CSV coins/VP; ruby grant; flask refill spends 2 rubies; pot clamp 54.
- Shop UI (scene/logic tests as feasible): panel exposes buy options per character; info-only when not shopping.
- Animation: optional light test that risk bar ratio matches white_sum; no need for tween frame tests.

---

## Implementation order (for the plan)

1. CSV loaders + PotTrack/MarketCatalog + GameState (54, rubies, flask API)  
2. Shop combined panels + remove coin flask SKU  
3. Board cauldron placeholders + bars + draw tween  

---

## Success criteria

- Playing a round uses CSV money/VP/ruby for the scoring space.
- Shelf opens rulebook + correct tier buy buttons; purchases match CSV costs.
- Flask refill costs 2 rubies via confirm.
- Potions UI shows placeholder cauldron flow, explosion-risk bar, and CSV progress hints.
- Headless suite updated and green.
