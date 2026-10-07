## Drawing one marble, matched to the web version's `.marble` rule.
##
## Its own class because three places draw marbles — the board, the control
## panel's queue, and anything that previews one — and a second copy of this
## recipe is how they drift apart.
##
## The web rule, element by element, because every part of it is doing
## something and a round soft blob loses the look entirely:
##
##   outline: 2px solid rgba(0,0,0,.55)      -> the dark rim
##   box-shadow: 2px 2px 0 rgba(0,0,0,.55)   -> a HARD offset shadow, no blur
##   inset -8px -8px 0 rgba(0,0,0,.22)       -> darkening toward bottom-right
##   ::after 26% x 20% at 20%,16%, white .8  -> a RECTANGULAR highlight
##
## The rectangular highlight is the single most important part. A round
## specular dot reads as a smooth 3D sphere; a hard-edged rectangle reads as
## pixel art, which is what the rest of the game is drawn as.
class_name Marble

const RIM := Color(0.0, 0.0, 0.0, 0.55)
const SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const UNDERSIDE := Color(0.0, 0.0, 0.0, 0.22)
const HIGHLIGHT := Color(1.35, 1.35, 1.35, 0.82)


## `radius` is the marble's outer radius. The web sizes a marble at 74% of its
## cell, so a caller working from a cell should pass cell_size * 0.37.
static func draw_at(canvas: CanvasItem, centre: Vector2, radius: float, color_index: int) -> void:
	if radius <= 0.5:
		return
	var palette: Array = BoardPalette.MARBLE_COLORS
	var base: Color = palette[color_index % palette.size()]
	var offset := maxf(1.0, radius * 0.07)

	# Hard offset shadow, drawn first and never blurred — a soft shadow is what
	# makes a pixel-art marble look like a sprite from a different game.
	canvas.draw_circle(centre + Vector2(offset, offset), radius, SHADOW)
	canvas.draw_circle(centre, radius, RIM)
	canvas.draw_circle(centre, radius - maxf(1.0, radius * 0.08), base)

	# Underside shading: a disc pushed down-right and clipped by drawing it
	# slightly smaller, which is as close as draw_circle gets to an inset
	# shadow without a shader.
	canvas.draw_circle(
		centre + Vector2(radius * 0.30, radius * 0.30),
		radius * 0.72,
		UNDERSIDE,
	)
	canvas.draw_circle(centre, radius * 0.60, base)

	# The rectangular highlight, in the web's proportions: 26% x 20% of the
	# marble's box, inset 20% from the left and 16% from the top.
	var box := radius * 2.0
	canvas.draw_rect(
		Rect2(
			centre + Vector2(-radius + box * 0.20, -radius + box * 0.16),
			Vector2(box * 0.26, box * 0.20),
		),
		HIGHLIGHT,
	)
