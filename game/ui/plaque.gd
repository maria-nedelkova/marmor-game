## The title plaque: "LEVEL 1" over the world's name, in a neon banner.
##
## Also the way back to the map, so it emits `pressed`.
##
## ## The shape
##
## A banner, not a rectangle: stepped corners, and both ends drawn out to a
## point at mid-height. The points are what make it read as a plaque hung on
## the screen rather than as a box of text, and they are the reason the frame
## can be wide without looking like a bar.
##
## ## Why it hugs its text
##
## World names run from NEONIA-1 (8 characters) to CELESTIAL RING STATION (22)
## — nearly three times the width. A plaque sized for the longest is two-thirds
## empty on the shortest; one sized for the shortest cannot hold the longest at
## all. So it is measured and drawn to fit, the same thing the web version's
## `width: max-content` does: the frame follows the words rather than the words
## being squeezed into a frame.
##
## A minimum width keeps a short name from producing a stub, and the name's
## font steps down rather than the plaque running off the screen. Shrinking the
## text is the lesser evil — a plaque wider than the phone is broken, a
## slightly smaller name is not.
extends Control

signal pressed

## Corner cut, built from three steps of CUT / STEPS. A single diagonal would
## be a chamfer; the staircase is what reads as pixel art.
const CUT := 24.0
## Six steps rather than three. More, smaller steps read as a finer pixel grid
## — the staircase is still the point, but at three steps each tread was large
## enough to look like a chamfer with notches rather than like pixel art.
const STEPS := 6
## How far each end is drawn out past the body, and how tall the point's base
## is. A shallow point reads as a mistake; this is deep enough to be a shape.
## The end points are shallower and wider than before, so their edges run
## closer to straight — a steep point reads as an arrowhead, a shallow one as a
## banner. Built as a staircase too, for the same reason the corners are.
const POINT := 16.0
const POINT_BASE := 26.0
const POINT_STEPS := 5

const PAD_X := 30.0
const PAD_Y := 14.0
const MIN_WIDTH := 210.0

const LEVEL_SIZE_MAX := 23
const NAME_SIZE_MAX := 34
const NAME_SIZE_MIN := 19

const FILL := Color(0.043, 0.035, 0.125)
## The border's gradient, cyan into pink, running top to bottom — the same
## gradient the control panel and the score badges carry, so every framed thing
## on the screen is edged the same way.
const EDGE_TOP := Color(0.45, 1.55, 1.85)
const EDGE_BOTTOM := Color(1.85, 0.48, 1.20)
## The reference's title colour, used for both lines.
##
## It is a LILAC, not a pink: blue sits above red in those letters, which is
## what gives them their violet cast. Earlier passes read it as magenta and
## then as rose, and both were wrong in the same way — too warm, because they
## had red leading. Getting the channel order right matters more here than the
## exact brightness.
## Kept just over the threshold rather than well past it. The channel RATIO is
## what carries the hue; the level only decides how much it blooms — and past
## about 1.5 the bloom whitens the letters until the lilac is gone and they
## read as plain white text with a coloured halo.
const INK := Color(1.24, 0.90, 1.38)
const INK_LEVEL := Color(1.18, 0.92, 1.33)

var level_text := ""
var name_text := ""

var _plaque: Rect2
var _name_size := NAME_SIZE_MAX
var _level_size := LEVEL_SIZE_MAX


func set_lines(level: String, world_name: String) -> void:
	level_text = level
	name_text = world_name
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tapped := false
	var at := Vector2.ZERO
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tapped = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		at = mb.position
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		tapped = st.pressed
		at = st.position
	if not tapped:
		return
	# Only inside the plaque itself — this control spans the full width, and a
	# tap out in the starfield beside it should not leave the world.
	if _plaque.grow(POINT).has_point(at):
		accept_event()
		pressed.emit()


func _measure() -> void:
	var font := ThemeDB.fallback_font
	# The points stick out past the body, so the body has to stop short of the
	# edge by that much or they are clipped.
	var available := size.x - (POINT + 10.0) * 2.0

	_name_size = NAME_SIZE_MAX
	while _name_size > NAME_SIZE_MIN:
		var w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name_size).x
		if w + PAD_X * 2.0 <= available:
			break
		_name_size -= 1
	# The level line scales with the name so the two never look unrelated.
	_level_size = maxi(16, int(round(_name_size * 0.68)))

	var name_w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name_size).x
	var level_w := font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _level_size).x
	var width := clampf(maxf(name_w, level_w) + PAD_X * 2.0, MIN_WIDTH, available)
	var height := float(_level_size + _name_size) + PAD_Y * 2.0 + 8.0
	_plaque = Rect2(Vector2((size.x - width) * 0.5, 2.0), Vector2(width, height))


## The banner outline: stepped corners, and a point at each end.
func _outline() -> PackedVector2Array:
	var s := CUT / float(STEPS)
	var p := _plaque
	var mid := p.position.y + p.size.y * 0.5
	var points := PackedVector2Array()

	points.append(Vector2(p.position.x + CUT, p.position.y))
	points.append(Vector2(p.end.x - CUT, p.position.y))
	for i in STEPS:
		var x := p.end.x - CUT + (i + 1) * s
		var y := p.position.y + i * s
		points.append(Vector2(x, y))
		points.append(Vector2(x, y + s))

	# Right-hand point, stepped out and back.
	points.append(Vector2(p.end.x, mid - POINT_BASE))
	for i in POINT_STEPS:
		var t := float(i + 1) / float(POINT_STEPS)
		points.append(Vector2(p.end.x + POINT * t, mid - POINT_BASE * (1.0 - t)))
		points.append(Vector2(p.end.x + POINT * t, mid - POINT_BASE * (1.0 - t) + POINT_BASE / POINT_STEPS))
	for i in POINT_STEPS:
		var t := 1.0 - float(i + 1) / float(POINT_STEPS)
		points.append(Vector2(p.end.x + POINT * t, mid + POINT_BASE * (1.0 - t)))
	points.append(Vector2(p.end.x, mid + POINT_BASE))

	points.append(Vector2(p.end.x, p.end.y - CUT))
	for i in STEPS:
		var x := p.end.x - i * s
		var y := p.end.y - CUT + (i + 1) * s
		points.append(Vector2(x, y))
		points.append(Vector2(x - s, y))

	points.append(Vector2(p.position.x + CUT, p.end.y))
	for i in STEPS:
		var x := p.position.x + CUT - (i + 1) * s
		var y := p.end.y - i * s
		points.append(Vector2(x, y))
		points.append(Vector2(x, y - s))

	# Left-hand point, the mirror of the right.
	points.append(Vector2(p.position.x, mid + POINT_BASE))
	for i in POINT_STEPS:
		var t := float(i + 1) / float(POINT_STEPS)
		points.append(Vector2(p.position.x - POINT * t, mid + POINT_BASE * (1.0 - t)))
		points.append(Vector2(p.position.x - POINT * t, mid + POINT_BASE * (1.0 - t) - POINT_BASE / POINT_STEPS))
	for i in POINT_STEPS:
		var t := 1.0 - float(i + 1) / float(POINT_STEPS)
		points.append(Vector2(p.position.x - POINT * t, mid - POINT_BASE * (1.0 - t)))
	points.append(Vector2(p.position.x, mid - POINT_BASE))

	points.append(Vector2(p.position.x, p.position.y + CUT))
	for i in STEPS:
		var x := p.position.x + i * s
		var y := p.position.y + CUT - (i + 1) * s
		points.append(Vector2(x, y))
		points.append(Vector2(x + s, y))

	return points


func _draw() -> void:
	if name_text.is_empty():
		return
	_measure()

	var outline := _outline()
	draw_colored_polygon(outline, FILL)
	_draw_gradient_edge(outline)

	var font := ThemeDB.fallback_font
	var level_w := font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _level_size).x
	var name_w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name_size).x
	var cx := _plaque.position.x + _plaque.size.x * 0.5

	draw_string(
		font, Vector2(cx - level_w * 0.5, _plaque.position.y + PAD_Y + _level_size),
		level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _level_size, INK_LEVEL,
	)
	draw_string(
		font, Vector2(cx - name_w * 0.5, _plaque.position.y + PAD_Y + _level_size + _name_size + 6.0),
		name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name_size, INK,
	)

	_draw_specks()


## The border, segment by segment, tinted by how far down the segment sits.
##
## draw_polyline takes one colour for the whole line, so a gradient edge has to
## be drawn as its own segments — the same reason the control panel and the
## score badges build their frames out of slices.
func _draw_gradient_edge(outline: PackedVector2Array) -> void:
	var top := _plaque.position.y
	var span := maxf(1.0, _plaque.size.y)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var t := clampf(((a.y + b.y) * 0.5 - top) / span, 0.0, 1.0)
		var tint := EDGE_TOP.lerp(EDGE_BOTTOM, t)
		draw_line(a, b, tint, 3.0)


## Stars inside the frame, as the reference has them: a larger one flanking
## each end of the text, and smaller ones filling the corners.
##
## Pinned to the plaque's own edges rather than to fixed coordinates, so they
## travel with it when the text changes length instead of drifting off a short
## plaque.
func _draw_specks() -> void:
	var mid := _plaque.position.y + _plaque.size.y * 0.5
	_draw_star(Vector2(_plaque.position.x + 17.0, mid), 7.0, Color(0.70, 1.75, 1.95))
	_draw_star(Vector2(_plaque.end.x - 17.0, mid), 7.0, Color(1.90, 0.60, 1.40))
	_draw_star(Vector2(_plaque.position.x + 34.0, _plaque.position.y + 13.0), 3.5, Color(1.85, 1.60, 0.75))
	_draw_star(Vector2(_plaque.end.x - 34.0, _plaque.end.y - 13.0), 3.5, Color(1.85, 1.60, 0.75))
	_draw_star(Vector2(_plaque.end.x - 34.0, _plaque.position.y + 13.0), 2.5, Color(0.80, 1.60, 1.90))
	_draw_star(Vector2(_plaque.position.x + 34.0, _plaque.end.y - 13.0), 2.5, Color(1.85, 0.70, 1.45))


## A filled rhomb, not a cross of thin arms — at this size a thin cross is
## nothing but its arms and reads as a plus sign.
func _draw_star(centre: Vector2, radius: float, tint: Color) -> void:
	var waist := radius * 0.30
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -radius), centre + Vector2(waist, 0.0),
		centre + Vector2(0.0, radius), centre + Vector2(-waist, 0.0),
	]), tint)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-radius, 0.0), centre + Vector2(0.0, -waist),
		centre + Vector2(radius, 0.0), centre + Vector2(0.0, waist),
	]), tint)
