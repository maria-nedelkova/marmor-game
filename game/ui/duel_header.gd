## The duel row: the Pretender on the left, the world's King on the right, and
## a progress bar between them.
##
## Left and right are not arbitrary. The bar fills left to right, so with the
## Pretender on the left the fill grows out of the player's own mascot and
## advances on the King — it reads as chasing him down. The web version
## reverses the sides on its wide layout for the same reason in mirror.
extends Control

const MASCOT_SIZE := 60.0
const BAR_HEIGHT := 18.0

## Pixel-art bar: drawn as discrete cells with a gap, so it reads as the same
## material as the sprites either side of it rather than as a smooth meter
## dropped between two pixel mascots.
const BAR_CELLS := 14
const BAR_GAP := 2.0

const FILL_LOW := Color(1.35, 0.55, 1.15)
const FILL_HIGH := Color(1.55, 1.25, 0.55)
const EMPTY_CELL := Color(0.32, 0.25, 0.48)
const FRAME := Color(1.25, 0.72, 1.35)

var session: GameSession


func set_session(new_session: GameSession) -> void:
	session = new_session
	queue_redraw()


func _draw() -> void:
	if session == null:
		return

	var mid := size.y * 0.5
	var pretender := Pretender.texture()
	if pretender != null:
		PixelSprite.draw_scaled(
			self, pretender,
			Rect2(Vector2(4.0, mid - MASCOT_SIZE * 0.5), Vector2(MASCOT_SIZE, MASCOT_SIZE)),
		)

	var king := Kings.texture_for(session.world["id"])
	if king != null:
		PixelSprite.draw_scaled(
			self, king,
			Rect2(Vector2(size.x - MASCOT_SIZE - 4.0, mid - MASCOT_SIZE * 0.5), Vector2(MASCOT_SIZE, MASCOT_SIZE)),
		)

	_draw_bar(Rect2(
		Vector2(MASCOT_SIZE + 16.0, mid - BAR_HEIGHT * 0.5),
		Vector2(maxf(0.0, size.x - (MASCOT_SIZE + 16.0) * 2.0), BAR_HEIGHT),
	))

	# The score under the bar, where the fill it describes is.
	var label := "%d / %d" % [session.score, session.target()]
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(
		font, Vector2((size.x - width) * 0.5, mid + BAR_HEIGHT * 0.5 + 15.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.25, 1.32, 1.5),
	)


func _draw_bar(box: Rect2) -> void:
	if box.size.x <= 0.0:
		return
	var progress := clampf(float(session.score) / maxf(1.0, float(session.target())), 0.0, 1.0)
	var cell_width := (box.size.x - BAR_GAP * (BAR_CELLS - 1)) / float(BAR_CELLS)
	# Ceil, so any progress at all lights the first cell. Rounding down meant a
	# real clear could leave the bar looking untouched, which reads as the score
	# not having counted.
	var lit := 0 if progress <= 0.0 else int(ceil(progress * BAR_CELLS))

	for i in BAR_CELLS:
		var at := Vector2(box.position.x + i * (cell_width + BAR_GAP), box.position.y)
		var cell := Rect2(at, Vector2(cell_width, box.size.y))
		if i < lit:
			# Shifts toward gold as it fills, so the last stretch before the
			# King's score looks different from the first.
			draw_rect(cell, FILL_LOW.lerp(FILL_HIGH, float(i) / float(BAR_CELLS - 1)))
		else:
			draw_rect(cell, EMPTY_CELL)

	draw_rect(box.grow(2.0), FRAME, false, 2.0)
