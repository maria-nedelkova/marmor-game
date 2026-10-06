## Board and rule constants, ported from the web version's
## `src/game/constants.ts`.
##
## Note what is NOT here. The web file also carries CELL_SIZE_PX, CELL_GAP_PX
## and BOARD_PADDING_PX, which exist only so an imperative DOM overlay can
## position a gliding marble without reading layout back and forcing a reflow.
## Godot does its own layout and has no such problem, so those are dropped
## rather than ported — the same call the Swift port made.
##
## KING_SCORE is gone too, and that one is a real change rather than a port
## detail: the King's target is per-world now and lives in
## `game/data/worlds.gd`. See PLAN.md section 3.
class_name Rules

## The board is SIZE x SIZE.
const SIZE := 9

## Palette ceiling — how many marble colours exist at all. How many are
## actually in play is per-world (`colors` in worlds.gd); this is the maximum,
## not the setting. The classic game uses the first seven; the eighth exists
## only for the later worlds.
const COLORS := 8

## Marbles in a row needed to clear.
const LINE_MIN := 5
