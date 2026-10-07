## The duel row: a score badge over each mascot, the Pretender on the left, the
## world's King on the right, and the progress bar between them.
##
## Left and right are not arbitrary. The bar fills left to right, so with the
## Pretender on the left the fill grows out of the player's own mascot and
## advances on the King — it reads as chasing him down.
extends Control

const MASCOT_SIZE := 76.0
const BADGE_SIZE := Vector2(84.0, 38.0)

## The bar's steps are TALLER than they are wide, as on the web — a row of
## narrow vertical bars rather than a few wide blocks. At 26 steps across the
## track each one is a slim tick, which is what makes a small score visible at
## all: two lit ticks read as "started", where two wide blocks would read as a
## quarter full.
const BAR_STEPS := 22
const BAR_HEIGHT := 26.0
const BAR_GAP := 2.0

const TRACK_FILL := Color(0.035, 0.030, 0.085)
const TRACK_EDGE := Color(0.95, 0.52, 1.05)
const STEP_LIT := Color(1.95, 0.42, 1.05)
const STEP_DARK := Color(0.26, 0.19, 0.44)

## The Pretender's badge is violet, the King's gold — the two sides of the duel
## are told apart by colour here as well as by which mascot they sit over.
const PRETENDER_EDGE_TOP := Color(0.52, 1.35, 1.85)
const PRETENDER_EDGE_BOTTOM := Color(1.25, 0.52, 1.75)
const KING_EDGE_TOP := Color(1.85, 1.45, 0.45)
const KING_EDGE_BOTTOM := Color(1.55, 0.95, 0.25)
const PRETENDER_TEXT := Color(1.35, 0.85, 1.85)
const KING_TEXT := Color(1.85, 1.55, 0.50)

var session: GameSession


func set_session(new_session: GameSession) -> void:
	session = new_session
	queue_redraw()


func _draw() -> void:
	if session == null:
		return

	var badge_y := 2.0
	var mascot_y := badge_y + BADGE_SIZE.y + 4.0

	_draw_badge(
		Rect2(Vector2(6.0, badge_y), BADGE_SIZE), str(session.score),
		PRETENDER_EDGE_TOP, PRETENDER_EDGE_BOTTOM, PRETENDER_TEXT,
	)
	_draw_badge(
		Rect2(Vector2(size.x - BADGE_SIZE.x - 6.0, badge_y), BADGE_SIZE), str(session.target()),
		KING_EDGE_TOP, KING_EDGE_BOTTOM, KING_TEXT,
	)

	var pretender := Pretender.texture()
	if pretender != null:
		PixelSprite.draw_scaled(
			self, pretender,
			Rect2(Vector2(10.0, mascot_y), Vector2(MASCOT_SIZE, MASCOT_SIZE)),
		)
	var king := Kings.texture_for(session.world["id"])
	if king != null:
		PixelSprite.draw_scaled(
			self, king,
			Rect2(Vector2(size.x - MASCOT_SIZE - 10.0, mascot_y), Vector2(MASCOT_SIZE, MASCOT_SIZE)),
		)

	# The bar runs between the mascots, level with their heads.
	# Clear of the mascots by a wide margin: they are the thing worth looking
	# at here, and the bar was eating the room they need.
	var left := MASCOT_SIZE + 34.0
	_draw_bar(Rect2(
		Vector2(left, mascot_y + MASCOT_SIZE * 0.5 - BAR_HEIGHT * 0.5),
		Vector2(maxf(0.0, size.x - left * 2.0), BAR_HEIGHT),
	))


## A rounded badge with a vertical gradient edge, the same construction the
## control panel uses — drawn as horizontal slices because a StyleBoxFlat takes
## one border colour and the gradient is the point.
func _draw_badge(box: Rect2, text: String, top: Color, bottom: Color, ink: Color) -> void:
	var radius := 10.0
	var thickness := 2.0
	draw_rect(box.grow(-thickness), TRACK_FILL)

	var rows := int(box.size.y)
	for y in rows:
		var t := float(y) / maxf(1.0, float(rows - 1))
		var tint := top.lerp(bottom, t)
		var distance := minf(float(y), float(rows - 1 - y))
		var inset := 0.0
		if distance < radius:
			var d := radius - distance
			inset = radius - sqrt(maxf(0.0, radius * radius - d * d))
		var at_y := box.position.y + y
		draw_rect(Rect2(box.position.x + inset, at_y, thickness, 1.0), tint)
		draw_rect(Rect2(box.position.x + box.size.x - inset - thickness, at_y, thickness, 1.0), tint)
		if y < thickness or y >= rows - thickness:
			draw_rect(Rect2(box.position.x + inset, at_y, box.size.x - inset * 2.0, 1.0), tint)

	var font := ThemeDB.fallback_font
	var font_size := 19
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		box.position + Vector2((box.size.x - width) * 0.5, box.size.y * 0.5 + font_size * 0.36),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink,
	)


func _draw_bar(box: Rect2) -> void:
	if box.size.x <= 0.0:
		return
	draw_rect(box, TRACK_FILL)
	draw_rect(box, TRACK_EDGE, false, 1.5)

	var inner := box.grow(-4.0)
	var step_width := (inner.size.x - BAR_GAP * (BAR_STEPS - 1)) / float(BAR_STEPS)
	var progress := clampf(float(session.score) / maxf(1.0, float(session.target())), 0.0, 1.0)
	# Ceil, so any progress at all lights the first step. Rounding down meant a
	# real clear could leave the bar looking untouched, which reads as the score
	# not having counted.
	var lit := 0 if progress <= 0.0 else int(ceil(progress * BAR_STEPS))

	for i in BAR_STEPS:
		var at := Vector2(inner.position.x + i * (step_width + BAR_GAP), inner.position.y)
		draw_rect(Rect2(at, Vector2(step_width, inner.size.y)), STEP_LIT if i < lit else STEP_DARK)
