# UI Polish + Set 1 Chip Effects + Shop Flow — Design

**Date:** 2026-07-29  
**Status:** Approved  
**Scope:** Rewards bar, flask drag-use, bonus-die reward feedback, Set 1 Almanac effects (official colors), shop book-centric buy flow

## Goal

Make brewing/evaluation feel rule-faithful and readable: clearer stop-reward preview, physical flask use, visible die rewards, working Set 1 chip actions, and a calmer shop that buys from ingredient books.

## Non-goals

- Fortune teller cards
- Full rats / rat-tails
- Sets 2–4 Almanac variants (Set 1 only)
- Online multiplayer
- Replacing ingredient book art (reuse existing shelves/panels)

---

## Recommended decisions (locked)

| Topic | Recommendation |
|---|---|
| Rewards strip | Taller horizontal **section cards** for Now + next milestones; auto-centers on current; scrollable if needed |
| Flask | Replace Use Flask button with a **draggable flask**; drop on cauldron to use |
| Bonus die feedback | After roll, show a **reward card** on the modal (icon + short name) then apply |
| Color ↔ shelf mapping | **Official Set 1 colors** (remap catalog; keep display names/art) |
| Chip effects | Implement **Set 1** only, per Almanac timing (on-draw vs Evaluation B) |
| Shop | Keep Take VP / Go Shop; buy only inside opened book; Continue when done/can't buy; **must press Continue** |

---

## 1. Rewards strip (above cauldron)

Replace the tall `RichTextLabel` dump with `ui/rewards_strip.tscn`:

- Height ~96–120px (taller than today), width similar to current band above cauldron
- Horizontal row of **section tiles**:
  - **Now** (current `scoring_space()`): space #, coins, VP, ruby if any — visually emphasized
  - **Next** milestones from `PotTrack.upcoming_milestones(space, N)` (show ~4–6)
- Each tile shows mini icons (existing money/VP/ruby assets) + space number
- `ScrollContainer` horizontal; on refresh, scroll so **Now** is leftmost/visible
- Explosion risk bar stays above or beside; do not bury it

Data still comes from `PotTrack`; board calls `rewards_strip.refresh(player.pot)`.

---

## 2. Flask drag-and-drop

- Hide/remove `FlaskButton` from primary brew controls; keep flask state label or fold into flask art
- Visible flask sprite on the table (full vs empty texture or modulate)
- Drag flask; on release over cauldron rect, call existing `use_flask` / controller path
- Invalid drop or empty flask: snap back; no effect
- Same rules as today: only if last chip was white, flask full, not exploded by that chip, etc.
- Optional: brief flash/toast “Flask used — white chip returned”

---

## 3. Bonus die reward presentation

Existing faces already match rules: VP1, VP2, RUBY, DROPLET, ORANGE.

- Keep application logic in `GameState.apply_bonus_die`
- After roll in `BonusDieModal`, show reward panel: face art + label (`+1 VP`, `+2 VP`, `Ruby`, `Droplet +1`, `Orange 1` / “Pumpkin”)
- Ruby face still grants only if `rubies_remaining > 0`; if pool empty, show “No rubies left”
- Droplet remains deferred via `pending_droplet_bonus` (already correct)

---

## 4. Official Set 1 color ↔ shelf remapping

Keep shelf **names/art**; change `MarketCatalog.CHAR_META` colors to match Almanac:

| Shelf / name | New color | Official ingredient | Timing |
|---|---|---|---|
| Pumpkin | ORANGE | Pumpkin | None |
| Scary Gary | **BLUE** | Crow Skull | On draw |
| Spider | **GREEN** | Garden Spider | Eval B |
| Mushroom (shroom) | **RED** | Toadstool | On draw |
| Moth | **BLACK** | Hawkmoth | Eval B |
| Mandrake | YELLOW | Mandrake | On draw |
| Ghost (Poots) | PURPLE | Ghost’s Breath | Eval B |
| Cherry Bomb | WHITE | White | Explosion only |

Starter bag stays **4×W1, 2×W2, 1×W3, 1×O1, 1×G1** — the green 1 is now **Spider** (Garden Spider), which matches the physical game’s green starter.

Chip art already keyed by slug (`gary`, `spider`, `shroom`, …); remapping color does not require renaming PNGs.

---

## 5. Set 1 chip effect rules

### On draw (pause brew until resolved)

**Blue / Gary (Crow Skull):** After placing Gary value `V`, draw `V` chips from bag (or as many as remain). Player may place **one** into the cauldron (triggers further on-draw effects if any) or return all. Others return to bag. UI: modal “You drew Gary V — pick one to keep or discard all.”

**Red / Mushroom (Toadstool):** When placing, movement = `value + bonus` where bonus is `0` / `1` / `2` from orange count in pot **before** this chip (0 / 1–2 / 3+ oranges).

**Yellow / Mandrake:** If previous placement was white, player may return that white to bag; yellow stays; empty space remains.

### Evaluation phase B (after bonus die, before/with rubies/VP/shop — order: die → chip actions → ruby spaces → VP/shop as already structured)

Insert a **chip-actions** step (or run at start of evaluation before shop UI) resolving for each player in start-player order:

**Green / Spider:** +1 ruby per green chip that is last or next-to-last placement (by index).

**Black / Moth:**
- 2 players: equal blacks → droplet +1; more than opponent → droplet +1 + ruby
- 3+ players: more than left **or** right → droplet +1; more than **both** → droplet +1 + ruby

**Purple / Ghost:** Count purples; player may choose tier ≤ count:
- 1 → 1 VP
- 2 → 1 VP + 1 ruby
- 3+ → 2 VP + droplet +1  
Default auto-pick best tier; optional later: choose lower.

Show a short reward toast/card per grant (“Spider — +1 Ruby”, etc.).

---

## 6. Shop flow cleanup

Keep evaluation fork:

- Non-exploded: mandatory VP already granted (current behavior); primary path is shop or done
- Exploded: **Take VP** xor **Go Shop** (current)

Shop shell:

- No big “Round N dump everything” buy list as the main surface
- Board shows ingredient books; click opens that book’s info panel
- Buy controls at **bottom of the open book panel** (values/prices as buttons)
- Rules: max 2 chips, different colors; unlock rounds; stock
- **Continue** visibility:
  - Show when `purchases.size() == 2` **or** no affordable legal buy remains
  - Always require an explicit Continue press (never auto-advance)
- If player opens shop with 0 coins / nothing affordable: Continue shown immediately, still must press

---

## 7. Implementation order

1. Catalog color remap + starter/tests  
2. On-draw effects (Toadstool, Crow Skull, Mandrake) + modals  
3. Evaluation B effects (Spider, Moth, Ghost) + reward cards  
4. Bonus die reward card polish  
5. Flask drag-drop  
6. Rewards strip UI  
7. Shop book-centric buy + Continue gating  

Each step ships with tests and a playable board.

---

## 8. Risks / notes

- Remapping colors will break tests that assert `gary → BLACK`, `shroom → GREEN`, `moth → RED`, `spider → BLUE` — update those intentionally
- Crow Skull nested draws need a brew pause state so Draw/Stop are disabled until the modal finishes
- Mushroom bonus must count oranges **already in pot**, not including the mushroom itself
- Ghost “lower tier allowed”: v1 auto-best is OK if documented

## Approval

Please review this spec. Reply **approved** (or list changes) and implementation planning will start from this file.
