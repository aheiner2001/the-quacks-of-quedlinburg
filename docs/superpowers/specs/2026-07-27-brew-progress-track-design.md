# Brew Progress Track & BrewTable Redesign

**Date:** 2026-07-27  
**Status:** Approved — implementation plan ready  
**Approach:** Single BrewTable scene with phase overlays

## Goal

Redesign the potion-brewing UI around a vertical liquid progress track and synced token history to the left of the existing cauldron, while implementing bonus-die scoring, dynamic multiplayer supply scaling (1–15 players), and keeping brew → score → shop on one shared scene shell.

## Decisions (locked)

| Topic | Choice |
|---|---|
| Scope | Full prompt: track UI + supply scaling + bonus die + shared BrewTable |
| Spiral board / stones | Hide/remove from gameplay; vertical track is the only progress UI |
| Segment tiles | Generate filled/empty PNGs (transparent BG); replaceable later |
| Player count | Main menu 1–15; supply scales with `numPlayers` |
| Architecture | Approach 1 — one BrewTable, phase overlays |
| Fortune Teller | Out of cycle (reserve deck-size helper only) |
| Rats | Full rules out; decorative rat at droplet baseline only |
| Ingredient books/shelves | Do not replace existing art |

## Non-goals (this cycle)

- Fortune Teller cards / effects UI
- Full rat-tail catch-up placement rules
- Almanac on-draw / on-eval chip abilities beyond current stubs
- Online / simultaneous multiplayer networking
- Replacing shelf/book portraits

## Current baseline (reuse)

- `Pot.place` advances from last index (or droplet); clamps to `PotTrack.max_space()` (54)
- `Pot.scoring_space()` = last placement index + 1 (or droplet if empty); at cap stays at cap — **this is the reward space**
- White sum > 7 explodes; chip still placed
- Coins / VP / ruby from `reference/levels.csv` via `PotTrack`
- Exploded players choose VP **or** shop money path; ruby still granted on ruby scoring spaces
- Cauldron draw flight + rune art stay as implemented
- Shop buy rules (1–2 chips, different colors, unlock rounds) stay; only stock counts change

---

## Architecture

### BrewTable scene

Evolve `board.tscn` into the shared **BrewTable**:

```
[ TokenHistory | ProgressTrack ]     [ Cauldron + Flask + Draw/Stop ]
         (left / center)                        (right, unchanged)
```

- Spiral `Gameboard` / stone instances: `visible = false` or removed from the play scene
- Replace text `PlacementsList` / `RewardsBar` as primary progress UX with the new track + history
- Keep minimal HUD labels: active player, white sum, flask state, handoff / explode text, round

### Phase overlays (same scene)

| Phase | UI |
|---|---|
| `potions` | Draw / Stop / Flask; track updates live |
| `bonus_die` | Modal: eligible players roll |
| `evaluation` | Existing evaluation panel logic (ported onto BrewTable) |
| `shop` | Existing shop controls ported / instanced as overlay; round 9 converts |

Shop/evaluation: instance `node_2d.tscn` (or a stripped overlay scene derived from it) as a child CanvasLayer on BrewTable. No `change_scene` away from BrewTable mid-round after migration. Temporary shim: existing `change_scene_to_file("res://node_2d.tscn")` may remain only until the overlay path passes tests, then remove it.

### Components

| Component | Responsibility |
|---|---|
| `ProgressTrack` | Vertical tiled segments 0…54; icons; reward-preview highlight; scroll |
| `TokenHistory` | Drawn-token icons aligned to landing spaces; linked scroll; rat stub |
| `DangerBar` | White sum vs 7 (adapt boom-berry slots) |
| `DrawStage` | Existing bag → cauldron flight (keep) |
| `BonusDieModal` | Show face, apply reward, advance |
| `SupplyScaler` | Build market + ruby pool from `numPlayers` |
| `EvaluationOverlay` / `ShopOverlay` | Existing phase UI on BrewTable |

---

## Progress track UI

### Layout

- Vertical strip left-center of BrewTable
- Fills **bottom → top**
- One segment per space using:
  - `progress_segment_filled.png` — reached / passed by marker trail
  - `progress_segment_empty.png` — not yet reached
- Identical footprint (export ~100×100 logical, transparent BG) so tiles seam cleanly

### Per-space labels

From `PotTrack` for space `s`:

- Money value (diamond / coin icon)
- VP value (circle / seal icon)
- Ruby star if `has_ruby(s)`

Icons must stay legible when several spaces are visible.

### Reward preview (most important cue)

Always highlight **`scoring_space()`** — the space **immediately after** the last placed token (or droplet if none). This is what the player banks if they stop now.

- Updates live on draw and flask undo
- Visually stronger than other spaces (frame / glow / distinct empty tile state)

### Token history (parallel column)

- Stack of ingredient token icons for this round’s draws
- Vertical position aligns with the track space that draw **landed on** (placement index)
- A value-4 token spans / aligns to the jump visually (icon anchored at landing space)
- Rat marker stub anchored at droplet / start baseline
- **Linked scroll**: scrolling history or track pans both

### Danger bar

- Show boom-berry / white total vs threshold 7
- Exploded state turns danger styling on

### Cauldron / flask

- No redesign; keep current rune cauldron and flask controls/style

---

## Rules engine additions

### Bonus die

After all players have stopped or exploded, before finishing evaluation grants:

1. Compute `scoring_space()` per player
2. Eligible = `not exploded` and `scoring_space == max among non-exploded`
3. Ties: all tied eligible players roll (hotseat sequential)
4. Apply one face:
   - 1 VP
   - 2 VP
   - 1 ruby (from shared ruby pool if tracked)
   - droplet +1 (permanent)
   - gain orange 1 chip into bag
5. Proceed to evaluation / shop overlays

### Evaluation / shop

Unchanged from current faithful rules; only the shell moves onto BrewTable.

### Supply scaling

```
sharedTokenSupply = round(75 * numPlayers)
sharedRubySupply  = round(8 * numPlayers)
```

- Distribute `sharedTokenSupply` across shop SKUs (including buyable whites) using relative weights:
  - Base weight per SKU = `value_band(value) / max(cost, 1)` where `value_band` is `{1: 4, 2: 2, 3: 1, 4: 1, 6: 1}` (missing keys → 1)
  - Normalize weights so they sum to 1, multiply by `sharedTokenSupply`, assign integers with largest-remainder
  - When an official box-count CSV is added later, replace weights with those counts; formula stays “scale proportions × n”
- Ingredient book costs / unlock rounds / effects **do not** scale
- `MarketCatalog.default_stock(numPlayers)` (or `SupplyScaler.build_market(n)`) replaces flat `_CHIP_STOCK := 10`
- Track `rubies_remaining = sharedRubySupply`; decrement only for bonus-die (and future shared grants), not for pot-space ruby grants
- Fortune deck size `round(9 * numPlayers)` — helper/comment only, no cards

### Main menu

- Player count control **1–15** (stepper/slider)
- `GameSession.start_local(n)` → scaled market + n hotseat players

---

## Art checklist

Generate (transparent BG, flat/clean illustrated style matching segment tiles):

- [ ] `progress_segment_filled.png`
- [ ] `progress_segment_empty.png`
- [ ] Track money / VP / ruby mini-icons if HUD icons are too large
- [ ] Optional: scoreboard strip background
- [ ] Optional: shop-guy icon
- [ ] Danger bar polish if needed

Keep as-is:

- [x] Cauldron rune
- [x] Chip token sprites under `assets/ui/board/`
- [x] Ingredient books / shelves

Note: `assets/how_to_play.pdf` is currently empty (0 bytes); do not block on it.

---

## Data flow

```
Menu (n) → GameSession.start_local(n)
  → SupplyScaler market + ruby pool
  → BrewTable potions
       draw → Pot.place → ProgressTrack + TokenHistory + DangerBar + chip flight
       stop / explode → hotseat advance
  → all stopped → bonus_die modal
  → evaluation overlay → shop overlay
  → next round or game over
```

---

## Error / edge cases

- Empty pot: preview = droplet space rewards
- At cap (54): placement and scoring stay at 54
- Flask undo: rebuild track fill + history + preview
- Rapid draws: invalidate prior chip-flight tween (existing pattern)
- Ruby pool empty: pot-space rubies still always grant to the player; bonus-die ruby grants only if `rubies_remaining > 0` (then decrement)
- Player count 1: bonus die always that player if not exploded

---

## Testing

- `scoring_space` / placement / explode (existing + any track helpers)
- Supply: for n in {1,3,5,10,15}, token sum ≈ 75n, ruby pool = 8n; proportions stable vs n=1 baseline ratios
- Bonus die: sole leader; tie both roll; exploded excluded
- UI: stones hidden; preview == scoring_space; scroll sync; shop buy still works on BrewTable; menu accepts 1–15

---

## Implementation sketch (for later plan)

1. Generate segment (+ mini icon) assets  
2. `SupplyScaler` + menu 1–15 + market tests  
3. `ProgressTrack` + `TokenHistory` components + board integration; hide stones  
4. Bonus die phase in `PhaseController` / `GameState`  
5. Port evaluation/shop onto BrewTable overlays  
6. Danger bar polish + regression suite  

---

## Open follow-ups (not blocking)

- Official box token counts CSV to replace heuristic weights  
- Fortune Teller subsystem using reserved deck-size formula  
- Real rat rules wiring into history offset  
