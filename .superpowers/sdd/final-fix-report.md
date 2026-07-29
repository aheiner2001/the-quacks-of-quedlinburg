# CSV Shop/Cauldron Final Fix Report

## 2026-07-27 final review fixes

- Buy-row rebuilds detach old buttons and defer deletion, preventing a pressed button from being freed while its signal is emitting.
- Both source CSV files use Godot's `keep` importer so `FileAccess` can read them in exported builds.
- `MarketCatalog` parses its CSV once, caches a stock template, and deep-copies that template for each game.
- `GameState.can_buy()` owns shared purchase validation; both `buy()` and shop UI availability use it.
- Flask refills are available during evaluation and shop phases when the active evaluation player has two rubies and an empty flask.
- Pot clamping now explicitly tests raw index 56 clamping to space 54.
- Evaluation VP coverage lands on space 23 and asserts five VP; market coverage restores the Poots round-three unlock assertion.

## Additional quick fixes

- Flask confirmation now includes a Cancel button.
- Draw animation cleanup uses a completion callback, so killed tweens are not awaited.
- Round nine skips the unspent-coin warning.

## Regression evidence

The pre-fix regression run reproduced the missing `can_buy()` API, potions-phase flask refill, evaluation flask gating, and locked-object error from freeing a pressed buy-row button.

Final verification from the feature worktree:

```bash
/opt/homebrew/bin/godot --headless --path . --import
/opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd
```

Both commands exited 0 with Godot 4.7.1. The test runner printed `ALL TESTS PASSED`; CSV-backed PotTrack and MarketCatalog assertions passed after import.

---

# Brew Progress Track — DROPLET scoring fix

**Date:** 2026-07-27  
**Status:** Complete

## Fix: DROPLET must not change this round's evaluation grants

Bonus-die `DROPLET` previously did `player.pot.droplet += 1` immediately in `apply_bonus_die`. For an empty pot, `scoring_space()` returns `droplet`, so evaluation coins/VP/ruby grants used the post-bump space.

**Change:**
- `PlayerState.pending_droplet_bonus` stores deferred droplet advances
- `apply_bonus_die(DROPLET)` increments pending only (does not touch `pot.droplet`)
- `GameState.end_turn()` applies pending onto `pot.droplet`
- `begin_round()` carries `pot.droplet` into the new pot so the permanent bump survives round reset

## Regression tests

- Empty pot + DROPLET → `finish_bonus_die` / evaluation: coins/VP/ruby match `scoring_space` **before** droplet bump; droplet applied on `end_turn`
- All players exploded → empty `bonus_die_queue` → finish → phase `evaluation` (controller + modal `open()` paths)

## Verification

```
/opt/homebrew/bin/godot --headless --path . --import   # IMPORT_EXIT=0
/opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd
ALL TESTS PASSED
TEST_EXIT=0
```

## Report path

`.worktrees/brew-progress-track/.superpowers/sdd/final-fix-report.md`

---

# Set 1 effects and shop review fixes

**Date:** 2026-07-29  
**Status:** Complete

## Fixes

- Hawkmoth rewards now require the player to have at least one black chip, preventing 0–0 ties from granting a droplet.
- The root `CONTINUE` button and panel Done button share gating and visibility; the Done handler also rejects direct calls when a first or second affordable purchase remains.
- White chips are available through the WhiteShop list while shopping, and participate in the same affordability gating.
- Crow Skull choice rows detach old buttons before queuing them for deletion.

## Regression coverage

- Added zero-black-chip moth cases for two- and three-player games.
- Added shop UI coverage for root Continue parity, the direct-handler bypass, and purchasing when only white chips are affordable.

## Verification

```bash
./tests/run.sh
```

Exited 0 with `ALL TESTS PASSED`.
