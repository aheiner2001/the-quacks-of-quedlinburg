# Task 6 Report: GameState rounds, evaluation, shop, Turn 9, winners

## Status

**DONE** — GameState and PlayerState additions implemented, tested, self-reviewed, and committed.

## Commit

| SHA | Subject |
|-----|---------|
| `7c9b6a0` | feat: add GameState evaluation, shop, and Turn 9 rules |

## Implementation

- Added seeded game creation, round setup, round-6 white chip event, and potion hotseat helpers.
- Added evaluation coin/VP handling and the exploded VP-or-shop fork.
- Added stock, unlock, affordability, purchase-count, and distinct-chip-color shop validation.
- Added pending purchased chips and final-pot tiebreak state to `PlayerState`.
- Added Turn 9 coin/ruby conversions, game-over transition, and winner calculation.
- Added end-turn pot/purchase chip returns and round progression.

## TDD and Verification

1. Added `TestGameState` and wired it into the test runner.
2. Observed the expected failure because `GameState` did not exist.
3. Implemented the required behavior.
4. During self-review, added a regression test for taking VP after choosing shop; observed it fail, then corrected phase handling.
5. Ran:

```bash
/opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd
```

Result: exit 0, all Chip, Bag, Pot, Potions, Market, and GameState assertions passed; final output `ALL TESTS PASSED`.

IDE diagnostics also reported no linter errors in the four changed files.

## Self-Review

- Confirmed all color references use `Chip.ChipColor`.
- Confirmed both legal non-exploded evaluation orders work: VP then shop, or shop then VP.
- Confirmed exploded players can choose only one evaluation branch.
- Confirmed failed purchases do not mutate coins, stock, purchases, or pending chips.
- Confirmed final-pot distance is captured before pots are cleared.
- Confirmed purchased and placed chips return exactly once at end of turn.

## Concerns

- Godot generated `.uid` sidecars remain untracked, consistent with prior tasks.

## Review Fixes

- Turn 9 coin and ruby conversions now select the shop/conversion branch, preserving the exploded player's exclusive VP-or-conversion choice while allowing non-exploded players to take VP and convert.
- The round-6 white-1 grant is tracked on `GameState` and occurs exactly once.
- Purchases are rejected after `finish_shop()` marks evaluation complete.
- Added `draw()`, `stop()`, and `use_flask()` aliases while retaining the existing `*_active()` methods.
- Added regressions for both exploded Turn 9 branch orders, repeated round-6 setup, buying after shop completion, and the potion helper aliases.

## Review Fix Verification

Ran:

```bash
/opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd
```

Result: exit 0. All assertions passed, including the new GameState regressions; final output `ALL TESTS PASSED`. IDE diagnostics reported no linter errors in `game/game_state.gd` or `tests/test_game_state.gd`.
