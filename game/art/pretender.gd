## The Pretender — the player's own mascot, facing the King of each world.
##
## Ported in spirit from the web version's `pretender.ts`, not line for line.
## That sprite is a 16x18 full figure with a sword; this is a 12x12 head, for
## the same reason the kings are: the two face each other across a progress bar
## at the top of the board screen, and at that size a full body is a smudge
## while a face reads. It keeps the original's identity — spiky purple hair
## with a lighter streak, a smirk — at the size it is actually drawn.
##
## Uses the same palette key vocabulary as the kings (see kings.gd), so the two
## sides of the duel are authored and validated the same way.
class_name Pretender

const ROWS := [
	"..c..cc..c..",
	".ccc.cc.ccc.",
	".cccccccccc.",
	".chhcccchhc.",
	"..kkkkkkkk..",
	".kllllllllk.",
	".klleelleek.",
	".klewwellek.",
	".kmmmmmmmmk.",
	"..kmaaaamk..",
	"...kmmmmk...",
	"....kkkk....",
]

## The web version's palette, carried across: the crown/hair violet was lifted
## out of near-black deliberately there, because at #241a33 it read as a dark
## smudge at the smaller sprite size. Same problem here, same answer.
const PALETTE := {
	"k": Color(0.14, 0.10, 0.20),
	"c": Color(0.36, 0.23, 0.62),
	"h": Color(0.56, 0.45, 0.94),
	"l": Color(1.0, 0.85, 0.70),
	"m": Color(0.88, 0.67, 0.48),
	"d": Color(0.60, 0.42, 0.30),
	"e": Color(0.14, 0.10, 0.07),
	"w": Color(1.0, 1.0, 1.0),
	"b": Color(0.23, 0.17, 0.12),
	"a": Color(1.0, 0.60, 0.66),
}


static func texture() -> ImageTexture:
	return PixelSprite.build("pretender", ROWS, PALETTE)
