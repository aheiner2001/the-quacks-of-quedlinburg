# Core Loop Final Fix Report

## 2026-07-27 whole-branch review fixes

- Non-exploded players now receive pot-track VP automatically when evaluation begins; exploded players retain the VP-versus-shop choice.
- Ingredient shelves are information-only. Explicit purchases use the evaluation ItemList, while the flask TextureButton remains the flask-refill purchase control.
- Rejected/empty draws no longer emit `chip_drawn`.
- Flask use is blocked after a voluntary stop, while a mid-draw flask undo still permits continued drawing.
- Flask UI refresh rebuilds pot placements, and explosion handoff text preserves both the explosion and next-player message.
- The starting player rotates when a non-final round ends.
- Board and evaluation scenes guard missing controllers and show a start-game message instead of dereferencing null.
- Godot-generated `.uid` files for `test_board_ui.gd`, `test_shop_ui.gd`, and `test_full_loop.gd` are included.
- Regression coverage was added for all corrected gameplay and UI behaviors.

## Reproducible local/CI verification

Run from the project root, in this order:

```bash
/opt/homebrew/bin/godot --headless --path . --import
/opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd
```

`tests/run.sh` runs the same two commands and accepts a `GODOT` environment override.

Final verification completed with Godot 4.7.1: `ALL TESTS PASSED`, exit code 0.
