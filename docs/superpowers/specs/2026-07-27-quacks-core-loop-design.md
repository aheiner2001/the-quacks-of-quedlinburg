# Quacks of Quedlinburg — Core Game Loop Design

**Date:** 2026-07-27  
**Status:** Approved for implementation planning  
**Source rules:** `rules.md` (consolidated Schmidt Spiele rulebook)  
**Engine:** Godot 4.7 (existing project)

---

## Goal

Ship a **local, playable core loop** for The Quacks of Quedlinburg: draw ingredients into a pot, risk explosion, score and shop, repeat for 9 rounds. This is the first sub-project; **online multiplayer (up to 15 players)** comes later and must not require rewriting the rules layer.

## Non-goals (this slice)

- Networked lobbies, rooms, or sync
- Fortune Teller cards (phase exists as a no-op stub)
- Rat stones / catch-up movement
- Bonus Die
- Almanac / Set-specific chip actions (chips only move the droplet track for now)
- Official end-of-turn ruby spends (2 rubies → droplet or flask); flask refill is shop-only in this digital version
- Test-tube pot variant
- True simultaneous potions on one machine (local uses hotseat; simultaneous is reserved for online)

## Product decisions (locked)

| Topic | Decision |
|---|---|
| Scope | Core loop first; networking second |
| Eventual capacity | Up to 15 online players (architecture must allow N players) |
| Local play | 1–2 humans; **hotseat** potions (P1 finishes, then P2), then shared evaluation/shop |
| Evaluation | Score + shop; exploded players choose VP **or** buy |
| Flask refill | Separate shop item (existing `TextureButton`); not ruby cost |
| Market | Existing shelf ingredients; effects stubbed |
| Unlocks | Mandrakes available from round **2**; Ghost/Poots from round **3** |
| Length | **9 rounds**; Turn **9** follows rulebook finale (no chip buys; convert coins/rubies to VP) |
| Architecture | Phase machine + pure `GameState` (Approach 1) |

### House rules vs rulebook

- **Flask refill:** Digital shop item instead of “2 rubies → refill flask” at end of turn.
- **Ingredient names/art:** Project shelves (pumpkin, shroom, etc.) stand in for rulebook colors; unlock timing mirrors yellow (r2) and purple (r3).
- **Everything else in this slice** follows `rules.md` unless listed under non-goals.

---

## Architecture

Three layers inside Godot:

1. **`GameState`** — Pure data and rule mutations. No scene tree dependencies. Holds all players, market, round, phase, hotseat index, RNG.
2. **`PhaseController`** — Validates and applies player intents; advances phases; emits signals for UI.
3. **Scenes (UI)** — Reuse `board.tscn` (pot / potions) and shop/`node_2d.tscn` (market + flask button). Call controller APIs; render state; do not re-implement explosion or scoring math.

```
Main Menu → PhaseController + GameState
                ↓ signals
         Board UI  /  Shop UI  /  Evaluation UI
```

Player count is a constructor parameter (local: 1–2; later: up to 15).

---

## Components

### Chip

`{ id, color, value }` — `value` is spaces advanced on the pot. Only **white** values count toward the explosion total.

### Pot

- Droplet start index (default 0).
- Ordered list of chips placed this round with their board indices.
- Placement: from last occupied space (or droplet if first chip), advance `value` spaces; gaps stay empty.
- **Scoring space** = space immediately after the last placed chip (even if exploded).
- Reaching/passing final space **33** grants **15 VP** and **35 coins** when scoring (per rules).

### Bag

Multiset of chips. Draw removes one at random (injectable RNG). Players never inspect contents. After the round, drawn chips return to the bag along with purchases.

### Player

- Bag, pot, flask (`full` | `empty`)
- VP, rubies (persist), coins (this round only)
- Flags: `exploded`, `stopped`
- Purchases this shop phase

### Market

Shelf entries mapped from existing UI, each with: id, display name, color, chip value(s) or special kind, coin cost, stock. Exact id↔color mapping (e.g. pumpkin→orange) lives in `market_catalog` and can be adjusted without changing rules code.

| Unlock | Round |
|---|---|
| Mandrake | ≥ 2 |
| Ghost / Poots | ≥ 3 |
| Other current shelves | Round 1 |

**Flask refill** is a market item (not a chip). Buying it sets flask to `full`.

**Buy limits (this slice):**

- Max **2 purchases** per shop phase (chips and/or flask refill).
- If buying **two chips**, they must be **different colors**.
- Flask refill **counts toward the 2-purchase max** but does **not** consume a chip color slot (you may buy one chip + flask, or two different-color chips, or flask only, etc., within the max of 2).

Chip Almanac effects are **stubs**: purchased chips only affect future draws/placement.

### Starter bag (each player)

Per rules: **4× white 1, 2× white 2, 1× white 3, 1× orange 1, 1× green 1.**

### Turn indicator events

- Before round 2: unlock Mandrake.
- Before round 3: unlock Ghost/Poots.
- Before round 6: each player adds **1× white 1** to their bag.

---

## Phase flow

Phases (stubs allowed):

1. **FortuneTeller** — no-op; advance immediately.
2. **Rats** — no-op; advance immediately.
3. **Potions** — hotseat per player (see below).
4. **Evaluation** — coins from scoring space; VP/shop fork; Turn 9 conversions.
5. **Shop** — only if player is eligible and round ≠ 9.
6. **EndOfTurn** — return chips to bags; clear pots; pass start index; advance flame/round; apply unlock / white-1 events; or **GameOver**.

### Potions (hotseat)

For the active player until they stop:

- **Draw** — pull chip, place on pot, resolve immediate stubs (none), update white sum.
- **Explosion** — if white sum **> 7**: set `exploded`, place the chip, force stop. Colored chips never count.
- **Flask** — if flask `full`, last chip was white, and that chip did **not** cause the explosion: return that chip to bag, undo its placement and white contribution, set flask `empty`.
- **Stop** — voluntary, or required if bag empty / exploded.
- Then next player; when all done → Evaluation.

### Evaluation

1. Determine scoring space → set **coins** (and apply space-33 special if applicable).
2. **Rubies from ruby-symbol spaces** — **stub this slice:** no rubies granted from pot spaces until the board layout encodes ruby symbols in data. Players start with **0 rubies**. Turn 9’s “2 rubies → 1 VP” remains implemented so it works once ruby income exists.
3. **Bonus Die / chip actions** — skip.
4. **VP vs shop:**
   - Not exploded: gain VP from scoring space **and** may enter Shop.
   - Exploded: choose **either** Take VP **or** Shop (not both).
5. **Turn 9:** no chip/flask shop. Eligible players may repeatedly: **5 coins → 1 VP**, **2 rubies → 1 VP**. Exploded players still choose between taking printed VP **or** doing conversions (mirror the VP-or-buy fork: printed VP **or** conversion spending, not both).

### End of game

After round 9 resolution: highest VP wins. Tie → furthest pot fill in the final round. Still tied → shared win.

---

## Data flow & UI

1. Main menu starts local game (1 or 2 players) → controller creates `GameState`.
2. **Board UI** binds to potions: show active player, pot chips, white total, flask; buttons Draw / Stop / Flask.
3. Hotseat handoff prompt when active player changes.
4. **Evaluation UI** shows scoring space, coins, exploded state; Take VP / Go to shop / Turn 9 convert controls.
5. **Shop UI** enables items by unlock + stock; cart max 2; checkout mutates state via controller.
6. Round summary → next potions or winner screen.

**Signals (illustrative):** `phase_changed`, `active_player_changed`, `chip_drawn`, `exploded`, `flask_used`, `round_ended`, `game_over`.

---

## Error handling

Illegal actions are rejected (disabled controls and/or short message); state unchanged:

- Draw when stopped, exploded, or bag empty
- Flask when empty / last chip not white / explosion chip
- Buy locked, sold-out, unaffordable, over cart limit, or two chips of same color
- Shop on Turn 9
- Exploded player taking both VP and shop (or VP and Turn 9 conversions)

RNG is seedable for reproducible tests.

---

## Testing

Prefer a light automated suite (GUT or equivalent) against `GameState` / controller:

- Starter bag composition
- Placement and scoring-space index
- White sum > 7 explodes and still places the chip
- Flask undo legality
- Evaluation coins/VP and exploded fork
- Market unlocks by round; stock decrement
- Flask shop refill
- Turn 9 conversion-only economy
- Nine-round winner and tiebreak

Manual: 2-player hotseat smoke through one full short path and a Turn 9 finish.

---

## File / module sketch (implementation guidance)

Exact paths can follow repo conventions when planning:

- `game/chip.gd` / chip resource
- `game/player_state.gd`
- `game/game_state.gd`
- `game/phase_controller.gd`
- `game/market_catalog.gd` (shelf ids, costs, unlock round)
- UI scripts on existing `board.tscn` / `node_2d.tscn` thinned to presentation + intent calls

Refactor existing shop cart helpers in `node_2d.gd` to call into `GameState` rather than owning economy rules.

---

## Follow-on sub-projects (not this spec)

1. **Session & sync** — lobbies, join codes, phase barriers for true simultaneous potions, up to 15 clients.
2. **Rules fidelity** — Fortune cards, rats, bonus die, Almanac Set 1 effects, ruby droplet spends, full pot ruby spaces.
3. **Scale polish** — market supply for 15, spectator/UI for many pots, reconnect.

---

## Success criteria

- Local 1–2 players can complete a 9-round game using draw/stop/flask, explosion, score/shop (with house flask item), Mandrake/Ghost unlocks, and Turn 9 conversions.
- Rules logic lives outside scenes and is unit-tested for the cases above.
- Adding networked simultaneous play later means syncing `GameState` + phase barriers, not rewriting pot/bag math.
