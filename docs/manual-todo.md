# Manual TODO — Quacks Core Loop (smooth play)

Use this after opening the **feature branch** worktree:

`Documents/Sandbox/the-quacks-of-quedlinburg/.worktrees/quacks-core-loop`

Automated rules + headless tests already exist. Everything below is **manual / editor / playtest / content** work so a human game feels correct.

---

## 0. First-time setup (do this once)

- [ ] Open the **worktree** project in Godot 4.7+ (not only the old `main` checkout)
- [ ] Confirm main scene / flow: **Main Menu → Start → Board (potions) → Shop/Eval → back to Board**
- [ ] Run tests once so the class cache is healthy:

```bash
cd .worktrees/quacks-core-loop
godot --headless --path . --import
godot --headless --path . -s res://tests/run_all_tests.gd
# or: ./tests/run.sh
```

- [ ] Merge or switch to `feature/quacks-core-loop` so you aren’t playtesting the old `main` shop that still spawns 50 debug stones
- [ ] Confirm `stone.tscn` uses `stone.gd` (has `stone_value`) — fixed for the assign error

---

## 1. Playtest checklist (must pass by hand)

### 1P smoke

- [ ] Main menu → **1 player** → Start loads board without errors
- [ ] Draw / Stop / Flask buttons enable/disable correctly
- [ ] Draw until near explosion; white total updates
- [ ] Flask undoes last **white** chip (only when legal)
- [ ] Stop → evaluation/shop scene loads
- [ ] Non-exploded: VP already applied; can still shop
- [ ] Buy via **explicit buy list** (not shelf info click); flask refill via flask button
- [ ] Done → next round board loads
- [ ] Play through to **round 9**; convert coins→VP; no chip shop; game over + winner

### 2P hotseat smoke

- [ ] Main menu → **2 Players** checked → Start
- [ ] P1 finishes potions → handoff text shows P2
- [ ] Explosion message readable before/with handoff (“P1 exploded — now P2”)
- [ ] Each player gets their own evaluation/shop turn
- [ ] Start player rotates each round (P2 potions first on round 2)

### Unlock / economy smoke

- [ ] Round 1: Mandrake **locked**, Poots **locked**
- [ ] Round 2: Mandrake buyable; Poots still locked
- [ ] Round 3: Poots buyable
- [ ] Can’t buy two chips of the **same color** in one shop
- [ ] Max **2** purchases (chip + flask OK)
- [ ] Exploded: can Take VP **or** shop, not both
- [ ] Bag grows next round after purchases

---

## 2. Board / pot visuals (biggest “feel” gap)

Today chips mostly show in a **text list** (`PlacementsList`), not on the spiral pot art.

- [ ] Place **33+ numbered stone markers** on `board.tscn` matching `gameboard.png` spaces (0…33+)
- [ ] Each stone child needs a `Label` with the space number (use board auto-number tool or set via `stone_value`)
- [ ] Wire `_show_placement` so drawn chips land on the matching stone (color/value icon), not only the list
- [ ] Show **droplet** marker on the droplet start space
- [ ] Clear chip markers at end of round / when returning to bag
- [ ] Optional: animate chip place / explosion shake

---

## 3. PotTrack data vs real board

`game/pot_track.gd` VP numbers are **approximate** (anchors 19→5, 23→7 from the rulebook examples).

- [ ] Open `assets/boards/gameboard.png` (or physical pot) and copy **exact VP** for spaces 0–33 into `PotTrack.VP`
- [ ] Mark which spaces have **ruby** icons (stubbed today — no ruby income)
- [ ] Update tests if any VP anchors change after the art read
- [ ] Confirm space **33** = 15 VP / 35 coins (already coded)

---

## 4. Market / ingredient content

Catalog costs are placeholders mapped to your shelves.

- [ ] Align shelf art ↔ colors in `market_catalog.gd` (pumpkin=orange, etc.) to what you want players to see
- [ ] Set real **Set 1** coin prices from the ingredient books
- [ ] Set real **stock counts** per chip type (box limits)
- [ ] Add buyable **white 1/2/3/4** values you care about (UI list already supports whites)
- [ ] Confirm Mandrake = yellow unlock r2, Poots/Ghost = purple unlock r3 naming in UI labels
- [ ] Write short **info popup text** per ingredient (shelf still opens info; buy is separate)
- [ ] Price/cost labels visible in shop UI (coins remaining, item cost)

---

## 5. Evaluation / shop UI polish

- [ ] Layout evaluation panel so it’s readable on your resolution
- [ ] Show: round, player, scoring space, coins, VP, flask, exploded yes/no
- [ ] Turn 9: convert buttons clear; shelves/buy list hidden
- [ ] Winner screen: names/indices + VP; tiebreak message if shared
- [ ] CONTINUE / Done can’t be double-pressed into weird states
- [ ] Remove leftover debug stone grid from old `main` `node_2d.gd` if you still open that checkout

---

## 6. Main menu / flow polish

- [ ] Rename project from `"test button"` in `project.godot` to Quacks title
- [ ] Set main scene to `main_menu.tscn`
- [ ] Clear 1P vs 2P control styling
- [ ] Settings button → back to menu (already partly wired) without killing mid-round state unexpectedly — or confirm “abandon game”
- [ ] Optional: “Resume” only if you add save later

---

## 7. Rules fidelity still stubbed (implement when you want “real Quacks”)

Do these **after** the core loop feels good:

### Fortune Teller
- [ ] 24-card deck data + draw at round start
- [ ] Purple immediate / blue lasting effects
- [ ] Skip yellow/purple/rat refs when unlocked content isn’t out yet

### Rats (from round 2)
- [ ] Scoring-track rat-tail count vs leader
- [ ] Place rat stone ahead of droplet; draws start after rat

### Bonus Die
- [ ] Highest non-exploded scoring space rolls
- [ ] Results: 1 VP, 2 VP, 1 ruby, droplet +1, orange chip

### Almanac chip effects (Set 1 first)
- [ ] Blue / red / yellow: on draw
- [ ] Green / purple / black: evaluation B
- [ ] Black 2p vs 3–4p pages

### Rubies (official)
- [ ] Ruby spaces on pot grant 1 ruby
- [ ] End of turn: 2 rubies → droplet +1; (flask refill is shop-only in your house rule — keep or restore book rule)

### Final round “Stir!”
- [ ] Simultaneous reveal cadence for Turn 9 potions (local UX; true sync later online)

---

## 8. Multiplayer / 15 players (next major project)

- [ ] Lobby + join code
- [ ] Host authoritative `GameState` (or server)
- [ ] Phase barrier: everyone must stop before evaluation
- [ ] Per-client pot UI; spectator / summary for many players
- [ ] Market stock scaled for 15
- [ ] Reconnect / mid-game join policy
- [ ] Replace local hotseat with simultaneous potions

---

## 9. Asset / project hygiene

- [ ] Commit or ignore `.uid` consistently
- [ ] Clean unused Gemini / scratch PNGs or move under `assets/`
- [ ] Fix stone spawn loop on **main** if you keep that branch around
- [ ] Delete or quarantine `@tool` debug prints once auto-number is done
- [ ] Add a short `README` with: open worktree, run `tests/run.sh`, how to start a game

---

## 10. Suggested order (smooth path)

1. Setup (§0) + 1P/2P playtest (§1)  
2. Fix anything broken from playtest  
3. PotTrack from art (§3)  
4. Board chip placement visuals (§2)  
5. Market prices/labels (§4–5)  
6. Menu/project naming (§6)  
7. Only then Fortune/Rats/Die/Almanac (§7)  
8. Networking last (§8)

---

## Quick “definition of smooth”

You’re done with the **manual core** when:

- A friend can play **2P hotseat** for 9 rounds without instructions beyond the UI  
- Chips appear on the **pot**, not only a list  
- Shop prices/unlocks match what you intend  
- No console errors on menu → board → shop → board → game over  
