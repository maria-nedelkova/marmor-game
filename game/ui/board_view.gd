## Draws a GameSession's board and turns taps into cell coordinates.
##
## Deliberately thin. It owns no rules — every tap goes to `session.tap()` and
## every rule lives there, which is what lets the whole game be tested without
## a scene. If a rule ever starts creeping in here, that is the bug.
##
## Marbles are drawn rather than sprited for now. The web version's hand-drawn
## pixel art has not been ported, and a flat disc with a highlight is an honest
## placeholder — it reads correctly and does not pretend to be the final look.
extends Control

signal cell_tapped(cell: Vector2i)

## The eight marble colours, matched to the web version's --c0..--c7.
const MARBLE_COLORS: Array[Color] = [
	Color(0.91, 0.26, 0.33),  # red
	Color(0.36, 0.60, 0.98),  # blue
	Color(0.36, 0.84, 0.47),  # green
	Color(0.96, 0.82, 0.26),  # yellow
	Color(0.72, 0.42, 0.95),  # purple
	Color(0.98, 0.56, 0.24),  # orange
	Color(0.36, 0.86, 0.88),  # cyan
	Color(0.96, 0.44, 0.74),  # pink
]

const GRID_LINE := Color(0.62, 0.38, 0.86, 0.55)
const BOARD_BG := Color(0.07, 0.05, 0.14)

var session: GameSession


func _ready() -> void:
	resized.connect(queue_redraw)


func set_session(new_session: GameSession) -> void:
	session = new_session
	queue_redraw()


## Side of one cell. The board is square and centred, so it is bounded by the
## shorter axis — a board that overflowed the screen on a narrow phone would be
## unplayable in exactly the places that matter most.
func cell_size() -> float:
	return minf(size.x, size.y) / float(Rules.SIZE)


## The board is centred horizontally but sits high in its vertical slack
## rather than dead centre. Centred, a 9x9 square inside a tall phone area left
## a large empty band above the grid and pushed the board down toward the
## thumb rail. A quarter of the slack reads as "attached to the HUD above it".
func board_origin() -> Vector2:
	var side := cell_size() * Rules.SIZE
	var slack := size - Vector2(side, side)
	return Vector2(slack.x * 0.5, maxf(0.0, slack.y) * 0.25)


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
	# Mouse and touch both, so this works on a desktop editor run and on a
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


func _draw() -> void:
	if session == null:
		return
	var s := cell_size()
	var origin := board_origin()
	var side := s * Rules.SIZE

	draw_rect(Rect2(origin, Vector2(side, side)), BOARD_BG)

	for i in range(Rules.SIZE + 1):
		var at := origin + Vector2(i * s, 0.0)
		draw_line(at, at + Vector2(0.0, side), GRID_LINE, 1.0)
		var at_h := origin + Vector2(0.0, i * s)
		draw_line(at_h, at_h + Vector2(side, 0.0), GRID_LINE, 1.0)

	# Selection ring under the marble, so the marble stays fully legible.
	if session.has_selection():
		draw_circle(cell_center(session.selected), s * 0.46, Color(1.0, 1.0, 1.0, 0.18))

	# The flask's first pick, in the prompt's own colour so the board and the
	# line of text asking for a second marble read as one instruction.
	if session.swap_first.x != -1:
		draw_arc(cell_center(session.swap_first), s * 0.46, 0.0, TAU, 40, Color(0.98, 0.72, 0.42), 3.0)

	# An armed tool tints the whole grid, so there is no way to be holding the
	# hammer without noticing. A rack button alone is too easy to lose track of
	# when the board is where you are looking.
	if session.is_armed():
		draw_rect(Rect2(origin, Vector2(side, side)), Color(0.98, 0.72, 0.42, 0.06))

	for r in Rules.SIZE:
		for c in Rules.SIZE:
			var color_index := session.board.at(r, c)
			if color_index == Board.EMPTY:
				continue
			_draw_marble(cell_center(Board.cell(r, c)), s * 0.38, color_index)


func _draw_marble(centre: Vector2, radius: float, color_index: int) -> void:
	var base: Color = MARBLE_COLORS[color_index % MARBLE_COLORS.size()]
	draw_circle(centre, radius, base.darkened(0.45))
	draw_circle(centre, radius * 0.88, base)
	draw_circle(centre - Vector2(radius * 0.3, radius * 0.3), radius * 0.34, base.lightened(0.45))
