## A hand-authored 5x7 pixel font.
##
## Drawn as rectangles rather than shipped as a TTF. A font file would be
## simpler to wire into Labels, but it would also be the one piece of the
## game's look that came from somewhere else, with its own licence and its own
## idea of hinting — and at these sizes a hinted vector font is exactly what
## pixel art is not. Everything else here is authored the same way: see
## kings.gd and marble.gd.
##
## Uppercase only, plus digits and the punctuation the UI actually uses.
## `draw_text` uppercases what it is given, which is also the aesthetic the
## reference uses throughout.
##
## 5 wide and 7 tall is the classic cell for this: wide enough for a legible M
## and W, narrow enough that a 22-character world name still fits a phone.
class_name PixelFont

const W := 5
const H := 7
## One blank column between glyphs, in source pixels.
const TRACKING := 1

const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#...#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
	"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
	".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
	",": [".....", ".....", ".....", ".....", ".##..", ".##..", ".#..."],
	":": [".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	"'": ["..#..", "..#..", ".....", ".....", ".....", ".....", "....."],
	"/": ["....#", "...#.", "..#..", ".#...", "#....", ".....", "....."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
}

## Anything unmapped draws as this, so a stray character is visible as a
## missing glyph rather than silently swallowing the space.
const FALLBACK := ["#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#####"]


## Width of `text` at `scale`, in screen pixels. No trailing gap after the last
## glyph, or centring comes out half a space off.
static func measure(text: String, scale: float) -> float:
	var n := text.length()
	if n == 0:
		return 0.0
	return (n * (W + TRACKING) - TRACKING) * scale


static func height(scale: float) -> float:
	return H * scale


## Draws `text` with its TOP-LEFT at `at`. Top-left rather than a baseline:
## there are no descenders in this set, so a baseline would be a fiction that
## every caller had to compensate for.
static func draw_text(
	canvas: CanvasItem, text: String, at: Vector2, scale: float, tint: Color
) -> void:
	var cursor := at
	for i in text.length():
		var ch := text[i].to_upper()
		var glyph: Array = GLYPHS.get(ch, FALLBACK)
		for y in H:
			var row: String = glyph[y]
			var x := 0
			while x < W:
				if row[x] != "#":
					x += 1
					continue
				# Runs of lit pixels become one rect rather than one each: a
				# solid bar drawn as five abutting rectangles shows seams at
				# fractional scales.
				var run := 1
				while x + run < W and row[x + run] == "#":
					run += 1
				canvas.draw_rect(Rect2(
					cursor + Vector2(x * scale, y * scale),
					Vector2(run * scale, scale),
				), tint)
				x += run
		cursor.x += (W + TRACKING) * scale


## Draws centred horizontally within `width`, which is what nearly every caller
## wants and what they would otherwise all reimplement.
static func draw_centered(
	canvas: CanvasItem, text: String, centre_x: float, top_y: float, scale: float, tint: Color
) -> void:
	draw_text(canvas, text, Vector2(centre_x - measure(text, scale) * 0.5, top_y), scale, tint)
