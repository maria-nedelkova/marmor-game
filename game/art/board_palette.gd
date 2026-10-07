## The eight marble colours, matched to the web version's --c0..--c7.
##
## Its own class because two unrelated places draw marbles — the board and the
## control panel's next-up queue — and a second copy of these values is exactly
## how a queue ends up showing a colour the board does not have.
class_name BoardPalette

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
