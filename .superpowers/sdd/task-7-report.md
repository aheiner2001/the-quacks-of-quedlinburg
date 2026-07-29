# Task 7 Report: Gate ingredient shelves by shop choice

## Status

Complete.

## Root cause

`_refresh_shop_controls()` gated shelf buttons only by the final-round condition, so evaluation left ingredient shelves interactive before the active player chose the shop.

## Fix

- Gate ingredient shelf visibility and enabled state on `player.chose_shop` outside round 9.
- Close ingredient panels and hide their buy rows while the shop is unavailable.
- Prevent direct ingredient-opening calls from exposing a panel outside the active shopping state.

## Test

Added shop UI coverage showing the Pumpkin shelf is hidden and disabled during evaluation, then visible and enabled after `go_shop_active()`.

## Verification

`./tests/run.sh` exited 0 with `ALL TESTS PASSED`.
