## The title plaque: "LEVEL 6" over "TERRA-FORMER", in a stepped neon frame.
##
## Also the way back to the map, so it emits `pressed`.
##
## ## Why it hugs its text instead of being a fixed shape
##
## The world names run from NEONIA-1 (8 characters) to CELESTIAL RING STATION
## (22). A plaque sized for the longest is two-thirds empty on the shortest,
## and one sized for the shortest cannot hold the longest at all. So it is
## measured and drawn to fit, the same thing the web version's
## `width: max-content` does — the frame follows the words rather than the
## words being squeezed into a frame.
##
## A minimum width keeps a short name from producing a stub, and the name's
## font steps down rather than the plaque running off the screen when the text
## is longer than the space. Shrinking the text is the lesser evil: a plaque
## wider than the phone is broken, a slightly smaller name is not.
extends Control

signal pressed

## Corner cut, and the staircase step it is built from. Three steps of
## `CUT / 3` each, which is what makes the corner read as pixel art rather than
## as a bevel — a single diagonal would just be a chamfer.
const CUT := 27.0
const STEPS := 3

const PAD_X := 26.0
const PAD_Y := 12.0
const MIN_WIDTH := 190.0

const LEVEL_SIZE := 15
const NAME_SIZE_MAX := 26
const NAME_SIZE_MIN := 15

const FILL := Color(0.043, 0.035, 0.125)
const CORE := Color(2.0, 1.88, 2.0)
const EDGE := Color(1.85, 0.52, 1.25)
const LEVEL_INK := Color(1.30, 1.38, 1.55)
const NAME_INK := Color(1.95, 1.20, 1.85)

var level_text := ""
var name_text := ""

var _plaque: Rect2
var _name_size := NAME_SIZE_MAX


func set_lines(level: String, world_name: String) -> void:
	level_text = level
	name_text = world_name
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tapped = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		tapped = (event as InputEventScreenTouch).pressed
	if not tapped:
		return
	# Only inside the plaque itself — the control spans the full width, and a
	# tap out in the starfield beside it should not leave the world.
	if _plaque.has_point((event as InputEventMouse).position if event is InputEventMouse else event.position):
		accept_event()
		pressed.emit()


func _measure() -> void:
	var font := ThemeDB.fallback_font
	var available := size.x - 24.0

	# Step the name down until it fits, rather than letting the plaque grow off
	# the screen.
	_name_size = NAME_SIZE_MAX
	while _name_size > NAME_SIZE_MIN:
		var w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name_size).x
		if w + PAD_X * 2.0 <= available:
			break
		_name_size -= 1

	var name_w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name_size).x
	var level_w := font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LEVEL_SIZE).x
	var width := clampf(maxf(name_w, level_w) + PAD_X * 2.0, MIN_WIDTH, available)
	var height := float(LEVEL_SIZE + _name_size) + PAD_Y * 2.0 + 10.0
	_plaque = Rect2(Vector2((size.x - width) * 0.5, 2.0), Vector2(width, height))


## A rectangle with each corner replaced by a staircase.
func _outline() -> PackedVector2Array:
	var s := CUT / float(STEPS)
	var p := _plaque
	var points := PackedVector2Array()

	# Top edge, then down the top-right corner.
	points.append(Vector2(p.position.x + CUT, p.position.y))
	points.append(Vector2(p.end.x - CUT, p.position.y))
	for i in STEPS:
		var x := p.end.x - CUT + (i + 1) * s
		var y := p.position.y + i * s
		points.append(Vector2(x, y))
		points.append(Vector2(x, y + s))

	# Right edge, then the bottom-right corner.
	points.append(Vector2(p.end.x, p.end.y - CUT))
	for i in STEPS:
		var x := p.end.x - i * s
		var y := p.end.y - CUT + (i + 1) * s
		points.append(Vector2(x, y))
		points.append(Vector2(x - s, y))

	# Bottom edge, then the bottom-left corner.
	points.append(Vector2(p.position.x + CUT, p.end.y))
	for i in STEPS:
		var x := p.position.x + CUT - (i + 1) * s
		var y := p.end.y - i * s
		points.append(Vector2(x, y))
		points.append(Vector2(x, y - s))

	# Left edge, then back up the top-left corner.
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

	# Pink outside, near-white inside. The order matters: the core has to be the
	# brightest thing so the bloom reads as light escaping a tube rather than as
	# a pink smear.
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, EDGE, 4.0)
	draw_polyline(closed, CORE, 2.0)

	var font := ThemeDB.fallback_font
	var level_w := font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LEVEL_SIZE).x
	var name_w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name_size).x
	var cx := _plaque.position.x + _plaque.size.x * 0.5

	draw_string(
		font, Vector2(cx - level_w * 0.5, _plaque.position.y + PAD_Y + LEVEL_SIZE),
		level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LEVEL_SIZE, LEVEL_INK,
	)
	draw_string(
		font, Vector2(cx - name_w * 0.5, _plaque.position.y + PAD_Y + LEVEL_SIZE + _name_size + 8.0),
		name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name_size, NAME_INK,
	)

	_draw_specks()


## Stars set into the frame, as the reference has them — pinned to the plaque's
## own ends so they move with it when the text changes length, rather than to
## fixed coordinates that would drift off a short plaque.
func _draw_specks() -> void:
	var mid := _plaque.position.y + _plaque.size.y * 0.5
	_draw_star(Vector2(_plaque.position.x + 13.0, mid), 5.5, Color(0.70, 1.75, 1.95))
	_draw_star(Vector2(_plaque.end.x - 13.0, mid), 5.5, Color(1.85, 0.60, 1.35))
	_draw_star(Vector2(_plaque.position.x + 26.0, _plaque.position.y + 11.0), 3.0, Color(1.80, 1.55, 0.70))
	_draw_star(Vector2(_plaque.end.x - 26.0, _plaque.end.y - 11.0), 3.0, Color(1.80, 1.55, 0.70))


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
