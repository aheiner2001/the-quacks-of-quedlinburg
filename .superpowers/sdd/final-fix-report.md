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
