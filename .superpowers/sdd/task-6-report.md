# Task 6 Report: Integrate BrewTable on board (hide stones, danger bar, live refresh)

## Status: Complete

All steps from the brief implemented and passing.

## Changes

- `tests/test_board_ui.gd`: added assertions for `ProgressTrack`/`TokenHistory` node presence and type, `Gameboard.visible == false`, `stone*` children hidden (loop is a no-op today since `board.tscn` has no `stone*` children), live refresh of `TokenHistory.token_count()` / `ProgressTrack.preview_space()` on draw and on flask use, and bidirectional `scroll_offset` sync between the two components.
- `board.tscn`: added `ext_resource` entries for `res://ui/progress_track.tscn` and `res://ui/token_history.tscn`; instanced `ProgressTrack` and `TokenHistory` as children positioned left of `DrawStage` (x 400–730, DrawStage at x 900); set `Gameboard.visible = false` (kept the node/texture so nothing else that references it breaks).
- `board.gd`:
  - `_ready()` now calls `_hide_spiral_board()` (hides `Gameboard` and any `stone*` child) and `_wire_track_scroll_sync()` before the early-return for no active session, so hiding/wiring happen even on the main-menu placeholder state.
  - `_wire_track_scroll_sync()` connects `ProgressTrack.scroll_changed`/`TokenHistory.scroll_changed` to new handlers `_on_track_scrolled`/`_on_history_scrolled`, guarded by a `_syncing_scroll` bool to prevent feedback loops (mirrors the `_guard_scroll` pattern already inside each component).
  - `_refresh()` now calls `$ProgressTrack.refresh(player.pot)` and `$TokenHistory.refresh(player.pot)`. Since `_on_drawn`, `_on_flask_used`, `_on_exploded`, `_on_active`, and `_on_phase` all already end by calling `_refresh()`, this gives live refresh on draw/flask/stop/explosion without duplicating refresh calls in each handler.
  - Kept the cauldron `DrawStage` (bag/cauldron/chip-flight tween) untouched.

## TDD

1. Added the new assertions to `test_board_ui.gd` first; ran the suite — observed the expected RED: `board has ProgressTrack`, `board has TokenHistory`, and `spiral board hidden` failed (3 assertions), plus a cascading `Node not found: "TokenHistory"` error later in the same test.
2. Implemented the scene/script changes above.
3. Re-ran — GREEN.

## Verification

```bash
/opt/homebrew/bin/godot --headless --path . --import
/opt/homebrew/bin/godot --headless --path . -s res://tests/run_all_tests.gd
```

Result: exit 0, `ALL TESTS PASSED` (full suite, including all `TestBoardUI` and `TestProgressTrackUI` assertions — token history/progress track refresh on draw and flask use, and both scroll-sync directions).

## Concerns

- `board.tscn` has no `stone*` children today (the spiral board appears to be a flat sprite, not per-space stone nodes), so the "hide stone children" logic is implemented but currently a no-op; it will activate automatically if/when stone nodes are added.
- Placement of `ProgressTrack`/`TokenHistory` (offsets left of `DrawStage`) is functional but not visually tuned/screenshotted — no manual playtest of on-screen layout, only headless logic tests, consistent with Task 5's stated limitation.
- Kept `ExplosionRiskBar` (did not replace with boom-berry slot art from `TODO/new images`) since the brief said either is fine as long as the `mini(sum, 8)` mapping stays; no functional change needed there.

## Report path

`.worktrees/brew-progress-track/.superpowers/sdd/task-6-report.md`
