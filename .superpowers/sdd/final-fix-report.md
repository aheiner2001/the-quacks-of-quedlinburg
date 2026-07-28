# Brew Progress Track — Final Fix Report

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
