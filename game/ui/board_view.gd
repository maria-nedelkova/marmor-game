## Draws a GameSession's board and turns taps into cell coordinates.
##
## Deliberately thin on rules: every tap goes to `session.tap()` and every rule
## lives there. If a rule ever starts creeping in here, that is the bug.
##
## ## Why there is a second board in here
##
## `GameSession` resolves a whole turn synchronously — the move, any clear, the
## spawn, and any clear that causes — and emits a signal at each step. By the
## time the view hears the first one, `session.board` is already in its final
## state, so drawing from it would skip straight to the end.
##
## So the view keeps `_display`, its own copy, and a queue of the events the
## session reported. Playback applies them one at a time. The alternative was
## making the session await the view between steps, which would have put
## animation timing inside the game rules and made every one of its tests
## need a scene.
##
## Marbles are drawn rather than sprited for now. The web version's hand-drawn
## pixel art has not been ported, and a flat disc with a highlight is an honest
## placeholder — it reads correctly without pretending to be the final look.
extends Control

signal cell_tapped(cell: Vector2i)
## Emitted when the queue drains, so the host can re-enable input and refresh
## anything that was waiting for the board to settle.
signal animation_finished


## The grid's gradient: RADIAL from the board's centre — pink in the middle,
## purple toward the border. The web stylesheet's
## `radial-gradient(circle, #ec6fc0 0%, #ab63d4 42%, #7268cf 100%)`.
##
## It was briefly vertical, from a misreading of the reference. Radial is what
## the design wants and what the stylesheet says, and the reason is that the
## middle of the board is where the play is: holding the brightest hue there
## lights the cells the player is actually looking at, and lets the edges fall
## away without the board losing its centre.
##
## The three stops are not evenly spaced, and that is the point. Pink holds
## everything inside 42% of the radius, and the whole fall to violet happens
## across the outer half — so the middle reads as one warm field rather than
## as a bullseye with a ring in it.
const GRID_CENTRE := Color(1.00, 0.36, 0.78)   # #ec6fc0, pushed
const GRID_MID := Color(0.70, 0.38, 0.88)      # #ab63d4
const GRID_EDGE := Color(0.38, 0.33, 0.90)     # #7268cf, pushed
const GRID_MID_STOP := 0.42
## The grid is lit, so it crosses the bloom threshold. Low, per HIGHLIGHT_GAIN.
const GRID_GAIN := 1.30

## The board's neon frame: a near-white core with pink either side, which is
## what the web version's `border: 1px solid #fff2fb` plus its stacked pink
## box-shadows add up to. The glow itself is the WorldEnvironment's job now
## rather than four shadow layers.
const FRAME_CORE := Color(2.0, 1.85, 1.95)       # #fff2fb, driven hot
const FRAME_EDGE := Color(1.85, 0.42, 1.05)      # #ff52c8, driven hot
const FRAME_THICKNESS := 4.0

const BOARD_BG := Color(0.10, 0.07, 0.19)
## Multiplier for a marble's specular highlight. The highlight is the only part
## of a marble that blooms — pushing the whole disc over the threshold turns 81
## marbles into 81 lamps and the board washes out.
##
## Low, for the same reason as the map's HDR_GAIN: at 1.55 every highlight
## clipped to flat white, so a red marble and a blue one had identical white
## dots on them.
const HIGHLIGHT_GAIN := 1.18
const ARMED_TINT := Color(1.45, 1.02, 0.58)
## The full-board armed wash, deliberately BELOW the glow threshold while
## ARMED_TINT above it is above. A wash is meant to be noticed and not looked
## at; at HDR values the bloom spread it across the whole grid and turned a
## violet board warm orange.
const ARMED_WASH := Color(0.62, 0.44, 0.26)

## Seconds per cell travelled. Short, because a marble crossing the board can
## cover sixteen cells and a per-cell cost that feels right over three becomes
## a wait over sixteen.
const MOVE_PER_CELL := 0.035
## Floor on a move, so a one-cell nudge still registers as movement.
const MOVE_MIN := 0.12
const CLEAR_TIME := 0.26
const SPAWN_TIME := 0.18

var session: GameSession

## What is drawn. Lags `session.board` by however much of the queue is unplayed.
var _display: Board
var _events: Array[Dictionary] = []
var _current: Dictionary = {}
var _elapsed: float = 0.0


func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(true)


func set_session(new_session: GameSession) -> void:
	session = new_session
	# The opening deal happens in the session's constructor, before anything is
	# connected, so it is adopted rather than animated — there is nothing for a
	# spawn animation to contrast against on an empty board anyway.
	_display = session.board.duplicate_board()
	_events.clear()
	_current = {}
	queue_redraw()


func is_busy() -> bool:
	return not _current.is_empty() or not _events.is_empty()


func enqueue_move(path: Array[Vector2i], color: int) -> void:
	_events.append({"type": "move", "path": path, "color": color})


func enqueue_clear(cells: Array[Vector2i]) -> void:
	_events.append({"type": "clear", "cells": cells})


func enqueue_spawn(cells: Array[Vector2i], colors: Array[int]) -> void:
	_events.append({"type": "spawn", "cells": cells, "colors": colors})


## Applies every queued event at once and stops animating. Used when the board
## must be correct immediately — leaving a world mid-turn, or a test that cares
## about the end state rather than the journey.
func settle() -> void:
	while not _current.is_empty() or not _events.is_empty():
		if _current.is_empty():
			_current = _events.pop_front()
			_elapsed = 0.0
		_finish_current()
	if session != null:
		_display = session.board.duplicate_board()
	queue_redraw()


func _process(delta: float) -> void:
	if _current.is_empty():
		if _events.is_empty():
			return
		_current = _events.pop_front()
		_elapsed = 0.0

	_elapsed += delta
	if _elapsed >= _duration(_current):
		_finish_current()
		if _current.is_empty() and _events.is_empty():
			animation_finished.emit()
	queue_redraw()


func _duration(event: Dictionary) -> float:
	match event["type"]:
		"move":
			return maxf(MOVE_MIN, (event["path"] as Array).size() * MOVE_PER_CELL)
		"clear":
			return CLEAR_TIME
		_:
			return SPAWN_TIME


## Commits an event to the display board. Separated from _process so `settle`
## can run the same transitions without waiting for them.
func _finish_current() -> void:
	match _current["type"]:
		"move":
			var path: Array[Vector2i] = _current["path"]
			_display.clear_at(path[0].x, path[0].y)
			_display.set_at_cell(path[path.size() - 1], _current["color"])
		"clear":
			for p in (_current["cells"] as Array[Vector2i]):
				_display.clear_at(p.x, p.y)
		"spawn":
			var cells: Array[Vector2i] = _current["cells"]
			var colors: Array[int] = _current["colors"]
			for i in cells.size():
				_display.set_at_cell(cells[i], colors[i])
	_current = {}
	_elapsed = 0.0


# --- geometry ----------------------------------------------------------------


## Side of one cell, sized so HALF A CELL of clear space is left either side of
## the board.
##
## That margin is self-referential — it is half the cell, and the cell is what
## is left after the margins — but it resolves exactly. Nine cells plus two
## half-cells is ten cells across the width, so:
##
##   9 * cell + 2 * (cell / 2) = width   ->   cell = width / 10
##
## which makes the leftover `(width - 9 * cell) / 2` come out at precisely
## cell / 2. Height is still divided by nine: the margin was asked for on the
## left and right, and the board has the rack above it and the panel below.
func cell_size() -> float:
	return minf(size.x / float(Rules.SIZE + 1), size.y / float(Rules.SIZE))


## Centred horizontally, pinned to the TOP of its box vertically.
##
## The host gives this a box as tall as whatever is left on the screen, and a
## 9x9 square is bounded by the width, so centring it in that box left the
## board floating with a wide empty band above it. Pinned to the top it sits
## directly under the duel row, and all the slack collects below where the rack
## and the control panel are.
func board_origin() -> Vector2:
	var side := cell_size() * Rules.SIZE
	return Vector2((size.x - side) * 0.5, 0.0)


func cell_at(point: Vector2) -> Vector2i:
	var origin := board_origin()
	var s := cell_size()
	if s <= 0.0:
		return Vector2i(-1, -1)
	var local := point - origin
	var c := int(floor(local.x / s))
	var r := int(floor(local.y / s))
	if not Board.in_bounds(r, c):
		return Vector2i(-1, -1)
	return Board.cell(r, c)


func cell_center(cell: Vector2i) -> Vector2:
	var s := cell_size()
	return board_origin() + Vector2((cell.y + 0.5) * s, (cell.x + 0.5) * s)


func _gui_input(event: InputEvent) -> void:
	# Mouse and touch both, so this works in a desktop editor run and on a
	# phone without a second code path.
	var pressed_at := Vector2.INF
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed_at = mb.position
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			pressed_at = st.position
	if pressed_at == Vector2.INF:
		return

	var cell := cell_at(pressed_at)
	if cell.x == -1:
		return
	accept_event()
	cell_tapped.emit(cell)


# --- drawing -----------------------------------------------------------------


func _draw() -> void:
	if session == null or _display == null:
		return
	var s := cell_size()
	var origin := board_origin()
	var side := s * Rules.SIZE

	draw_rect(Rect2(origin, Vector2(side, side)), BOARD_BG)
	_draw_grid(origin, s, side)
	_draw_frame(origin, side)

	# Selection ring under the marble, so the marble stays fully legible.
	if session.has_selection() and not is_busy():
		draw_circle(cell_center(session.selected), s * 0.46, Color(1.6, 1.6, 1.7, 0.22))

	# The flask's first pick, in the prompt's colour so the board and the line
	# of text asking for a second marble read as one instruction.
	if session.swap_first.x != -1:
		draw_arc(cell_center(session.swap_first), s * 0.46, 0.0, TAU, 40, ARMED_TINT, 3.0)

	var clearing := {}
	var progress := 0.0
	if not _current.is_empty():
		progress = clampf(_elapsed / maxf(0.001, _duration(_current)), 0.0, 1.0)
		if _current["type"] == "clear":
			for p in (_current["cells"] as Array[Vector2i]):
				clearing[p] = true

	var spawning := {}
	if not _current.is_empty() and _current["type"] == "spawn":
		for p in (_current["cells"] as Array[Vector2i]):
			spawning[p] = true

	var moving_from := Vector2i(-1, -1)
	if not _current.is_empty() and _current["type"] == "move":
		moving_from = (_current["path"] as Array[Vector2i])[0]

	for r in Rules.SIZE:
		for c in Rules.SIZE:
			var cell := Board.cell(r, c)
			var color_index := _display.at(r, c)
			if color_index == Board.EMPTY:
				continue
			# The travelling marble is drawn separately, at its interpolated
			# position, not in the cell it started from.
			if cell == moving_from:
				continue

			var radius := s * 0.37
			if clearing.has(cell):
				# Swell slightly, then collapse — a straight shrink reads as the
				# marble falling through the board rather than being destroyed.
				radius *= (1.0 + 0.25 * sin(progress * PI)) * (1.0 - progress)
			elif spawning.has(cell):
				radius *= progress
			if radius > 0.3:
				_draw_marble(cell_center(cell), radius, color_index)

	if moving_from.x != -1:
		_draw_marble(_moving_position(progress), s * 0.37, _current["color"])

	# An armed tool tints the whole grid, so there is no way to be holding the
	# hammer without noticing. A rack button alone is too easy to lose track of
	# when the board is where you are looking.
	if session.is_armed():
		draw_rect(Rect2(origin, Vector2(side, side)), Color(ARMED_WASH.r, ARMED_WASH.g, ARMED_WASH.b, 0.05))


## Samples the radial gradient at a point, by its distance from the board's
## centre as a fraction of the half-diagonal.
##
## Half-diagonal, not half-side: CSS `radial-gradient(circle, ...)` defaults to
## farthest-corner, so the last stop lands in the corners rather than at the
## middle of each edge. Normalising by half-side instead would saturate the
## whole outer border to the end colour and lose the gradient across the last
## two rings.
func _grid_color_at(point: Vector2, origin: Vector2, side: float) -> Color:
	var centre := origin + Vector2(side, side) * 0.5
	var t := clampf(point.distance_to(centre) / (side * 0.70710678), 0.0, 1.0)
	var base: Color
	if t <= GRID_MID_STOP:
		base = GRID_CENTRE.lerp(GRID_MID, t / GRID_MID_STOP)
	else:
		base = GRID_MID.lerp(GRID_EDGE, (t - GRID_MID_STOP) / (1.0 - GRID_MID_STOP))
	return Color(base.r * GRID_GAIN, base.g * GRID_GAIN, base.b * GRID_GAIN)


## Each line is drawn as short segments so the gradient runs ALONG it, not just
## across the grid. A single line per row would have to pick one colour, and
## the horizontal lines near the middle would then be flat pink end to end
## while the gradient only showed between rows.
func _draw_grid(origin: Vector2, s: float, side: float) -> void:
	var steps := Rules.SIZE * 2
	var step := side / float(steps)
	for i in range(Rules.SIZE + 1):
		for j in steps:
			var from_v := origin + Vector2(i * s, j * step)
			var to_v := from_v + Vector2(0.0, step)
			draw_line(from_v, to_v, _grid_color_at((from_v + to_v) * 0.5, origin, side), 2.0)

			var from_h := origin + Vector2(j * step, i * s)
			var to_h := from_h + Vector2(step, 0.0)
			draw_line(from_h, to_h, _grid_color_at((from_h + to_h) * 0.5, origin, side), 2.0)


## White core between two pink lines. The order matters: pink is laid down
## first and the white drawn inside it, so the core stays the brightest thing
## and the bloom reads as light escaping a tube rather than a pink smear.
func _draw_frame(origin: Vector2, side: float) -> void:
	var outer := Rect2(origin, Vector2(side, side)).grow(FRAME_THICKNESS)
	draw_rect(outer, FRAME_EDGE, false, FRAME_THICKNESS)
	draw_rect(Rect2(origin, Vector2(side, side)).grow(1.0), FRAME_CORE, false, 2.0)
	draw_rect(Rect2(origin, Vector2(side, side)), FRAME_EDGE, false, 1.5)


## Walks the path at constant speed, so a marble turning a corner does not
## speed up or stall — the glide should read as one continuous travel.
func _moving_position(progress: float) -> Vector2:
	var path: Array[Vector2i] = _current["path"]
	if path.size() == 1:
		return cell_center(path[0])
	var span := float(path.size() - 1) * clampf(progress, 0.0, 1.0)
	var index := mini(int(floor(span)), path.size() - 2)
	return cell_center(path[index]).lerp(cell_center(path[index + 1]), span - index)


func _draw_marble(centre: Vector2, radius: float, color_index: int) -> void:
	Marble.draw_at(self, centre, radius, color_index)
