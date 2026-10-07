## The eight kings, one per world.
##
## Hand-authored 12x12 heads, drawn directly as strings so the sprite is
## visible in the source (see pixel_sprite.gd). Each character is a palette
## key; "." is transparent.
##
## ## Drawn FROM docs/reference/level-map.jpeg, not cut from it
##
## The reference's avatars are about 45x45 inside a JPEG: generated as a
## picture OF pixel art rather than as pixel art, so the blocks are smeared,
## every edge carries compression ringing, and each one sits on a different
## background (nebula, starfield, the limb of a planet) with no single colour
## to key out. Cut free and scaled up to the 76px these are drawn at, they
## would be soft and haloed next to marbles and a font that are pixel-exact.
##
## So each design is reproduced here instead — the flaming hair, the bronze
## king under a gem crown, the visored helm, the leaf-wreathed face, the hooded
## void — authored at a size that stays sharp at any scale.
##
## They are heads rather than full figures because they sit at about 76px
## facing the Pretender across a progress bar, where a full body is a smudge
## and a face reads.
##
## Palette keys, used consistently across all eight:
##   k outline   c crown/headgear   h headgear highlight   g gem
##   l skin light   m skin mid   d skin dark
##   e eye/shadow   w glint   b brow or beard   a accent
class_name Kings


## 01 NEONIA-1 — the reference's chibi king: a three-point gold crown with a
## red gem, a wide pale face, heavy slanted eyes and blushed cheeks.
const NEONIA := [
	"..c..cc..c..",
	".cc.cccc.cc.",
	".ccccggcccc.",
	".cccccccccc.",
	".kkkkkkkkkk.",
	".kllllllllk.",
	".kleelleelk.",
	".kllllllllk.",
	".kalleellak.",
	".kllllllllk.",
	".kkkkkkkkkk.",
	"....dddd....",
]

## 02 SULFUR-KOR — hair of fire. The flames are asymmetric on purpose: fire
## that mirrors itself reads as a pattern rather than as burning.
const SULFUR := [
	"..h..hh..h..",
	".hch.hch.hc.",
	".cchcchccchc",
	".cccccccccc.",
	".kkkkkkkkkk.",
	".kbbmmmmbbk.",
	".kmeemmeemk.",
	".kmmmmmmmmk.",
	".kmmeeeemmk.",
	".kmmmmmmmmk.",
	".kkkkkkkkkk.",
	"....dddd....",
]

## 03 CRYSTALLOS — a bronze king under a gold crown set with green gems, with
## the heavy brow and square frown the reference gives him.
const CRYSTALLOS := [
	"..c..cc..c..",
	".cgc.cgc.cgc",
	".cccccccccc.",
	".hhhhhhhhhh.",
	".kkkkkkkkkk.",
	".kmmmmmmmmk.",
	".kbbmmmmbbk.",
	".kmeemmeemk.",
	".kmmmmmmmmk.",
	".kmeeeeeemk.",
	".kkkkkkkkkk.",
	"....dddd....",
]

## 04 BLACK HOLE 04 — the one world the reference gives no king. It has an
## accretion ring and a dark centre, so that is what guards it: a ring of light
## around a void with two points where eyes would be.
const BLACK_HOLE := [
	"...aaaaaa...",
	"..akkkkkka..",
	".akkddddkka.",
	"akkddddddkka",
	"akddddddddka",
	"akddeddeddka",
	"akddeddeddka",
	"akddddddddka",
	"akkddddddkka",
	".akkddddkka.",
	"..akkkkkka..",
	"...aaaaaa...",
]

## 05 CELESTIAL RING STATION — a white machine helm under a gold crown with a
## violet gem, its eyes a pair of lit gold bars above a dark visor slit. The
## one king whose face you never see.
const RING_STATION := [
	"..c..cc..c..",
	".ccc.cc.ccc.",
	".cccgggcccc.",
	".cccccccccc.",
	".kkkkkkkkkk.",
	".kllllllllk.",
	".kceecceeck.",
	".kllllllllk.",
	".kmeeeeeemk.",
	".kllllllllk.",
	".kkkkkkkkkk.",
	"....dddd....",
]

## 06 TERRA-FORMER — a bark-brown face wreathed in leaves, with a beard. The
## foliage spreads outward rather than up: growth, not authority.
const TERRA_FORMER := [
	".cc.cccc.cc.",
	".cccccccccc.",
	"c.cccccccc.c",
	".ckkkkkkkkc.",
	".kmmmmmmmmk.",
	".kcmmmmmmck.",
	".kmeemmeemk.",
	".kmmmmmmmmk.",
	".kbbmmmmbbk.",
	".kbbeeeebbk.",
	".kkbbbbbbkk.",
	"....kkkk....",
]

## 07 GAIA PRIME — a living world as a face: ocean skin with landmasses across
## the brow and jaw.
const GAIA_PRIME := [
	"...cccccc...",
	"..cccccccc..",
	".cccccccccc.",
	".kkkkkkkkkk.",
	".kmmmmmmmmk.",
	".kmllmmllmk.",
	".kmeemmeemk.",
	".klmmmmmmlk.",
	".kmmeeeemmk.",
	".kmllmmllmk.",
	".kkkkkkkkkk.",
	"....dddd....",
]

## 08 GALACTIC CORE — the reference's hooded figure: a dark cowl ringed with
## stars and two burning eyes, and no face at all behind it. The finale should
## not look like another man in a hat.
const GALACTIC_CORE := [
	"..aa.aa.aa..",
	".a.cccccc.a.",
	"a.cccccccc.a",
	".cckkkkkkcc.",
	".ckkkkkkkkc.",
	".ckwwkkwwkc.",
	".ckkkkkkkkc.",
	"a.kkkkkkkk.a",
	".a.kkkkkk.a.",
	"..a.kkkk.a..",
	"...aaaaaa...",
	"....aaaa....",
]


## Palettes. Skin tones differ per world as well as headgear, so the eight do
## not read as one man in eight hats.
const PALETTES := {
	"neonia_1": {
		"k": Color(0.13, 0.08, 0.14), "c": Color(0.95, 0.76, 0.26), "h": Color(1.0, 0.92, 0.58),
		"g": Color(0.95, 0.32, 0.36), "l": Color(0.99, 0.88, 0.82), "m": Color(0.93, 0.78, 0.70),
		"d": Color(0.42, 0.72, 0.52), "e": Color(0.14, 0.09, 0.12), "w": Color(1.0, 1.0, 1.0),
		"b": Color(0.80, 0.62, 0.52), "a": Color(0.97, 0.62, 0.64),
	},
	"sulfur_kor": {
		"k": Color(0.18, 0.07, 0.05), "c": Color(0.93, 0.33, 0.10), "h": Color(1.0, 0.82, 0.26),
		"g": Color(1.0, 0.92, 0.45), "l": Color(0.92, 0.74, 0.44), "m": Color(0.82, 0.63, 0.33),
		"d": Color(0.50, 0.33, 0.14), "e": Color(0.16, 0.07, 0.05), "w": Color(1.0, 0.96, 0.80),
		"b": Color(0.36, 0.16, 0.07), "a": Color(0.98, 0.56, 0.18),
	},
	"crystallos": {
		"k": Color(0.16, 0.10, 0.14), "c": Color(0.93, 0.72, 0.22), "h": Color(0.74, 0.55, 0.20),
		"g": Color(0.22, 0.78, 0.66), "l": Color(0.78, 0.63, 0.47), "m": Color(0.64, 0.50, 0.37),
		"d": Color(0.38, 0.28, 0.20), "e": Color(0.14, 0.09, 0.08), "w": Color(1.0, 1.0, 1.0),
		"b": Color(0.26, 0.17, 0.12), "a": Color(0.72, 0.48, 0.98),
	},
	"black_hole_04": {
		"k": Color(0.05, 0.04, 0.09), "c": Color(0.30, 0.26, 0.40), "h": Color(0.46, 0.40, 0.58),
		"g": Color(0.60, 0.50, 0.75), "l": Color(0.22, 0.18, 0.30), "m": Color(0.16, 0.13, 0.24),
		"d": Color(0.09, 0.07, 0.15), "e": Color(1.0, 0.86, 0.52), "w": Color(1.0, 1.0, 1.0),
		"b": Color(0.18, 0.15, 0.26), "a": Color(0.99, 0.64, 0.26),
	},
	"celestial_ring_station": {
		"k": Color(0.13, 0.12, 0.18), "c": Color(0.96, 0.78, 0.24), "h": Color(1.0, 0.92, 0.55),
		"g": Color(0.66, 0.34, 0.92), "l": Color(0.90, 0.92, 0.96), "m": Color(0.60, 0.63, 0.72),
		"d": Color(0.36, 0.38, 0.46), "e": Color(0.12, 0.12, 0.16), "w": Color(1.0, 1.0, 1.0),
		"b": Color(0.48, 0.50, 0.60), "a": Color(0.98, 0.82, 0.30),
	},
	"terra_former": {
		"k": Color(0.10, 0.14, 0.10), "c": Color(0.32, 0.72, 0.30), "h": Color(0.56, 0.90, 0.48),
		"g": Color(0.78, 0.95, 0.52), "l": Color(0.76, 0.58, 0.42), "m": Color(0.60, 0.44, 0.31),
		"d": Color(0.36, 0.26, 0.18), "e": Color(0.14, 0.11, 0.08), "w": Color(1.0, 1.0, 1.0),
		"b": Color(0.42, 0.30, 0.18), "a": Color(0.35, 0.78, 0.95),
	},
	"gaia_prime": {
		"k": Color(0.08, 0.14, 0.17), "c": Color(0.30, 0.70, 0.45), "h": Color(0.56, 0.92, 0.62),
		"g": Color(0.80, 0.96, 0.70), "l": Color(0.44, 0.78, 0.46), "m": Color(0.22, 0.52, 0.66),
		"d": Color(0.13, 0.32, 0.42), "e": Color(0.08, 0.16, 0.20), "w": Color(1.0, 1.0, 1.0),
		"b": Color(0.30, 0.60, 0.40), "a": Color(0.45, 0.92, 0.70),
	},
	"galactic_core": {
		"k": Color(0.07, 0.05, 0.13), "c": Color(0.26, 0.16, 0.38), "h": Color(0.44, 0.28, 0.58),
		"g": Color(0.60, 0.40, 0.85), "l": Color(0.20, 0.12, 0.28), "m": Color(0.14, 0.08, 0.20),
		"d": Color(0.09, 0.05, 0.14), "e": Color(0.90, 0.95, 1.0), "w": Color(1.0, 1.0, 1.0),
		"b": Color(0.18, 0.10, 0.24), "a": Color(0.62, 0.66, 1.0),
	},
}

const SPRITES := {
	"neonia_1": NEONIA,
	"sulfur_kor": SULFUR,
	"crystallos": CRYSTALLOS,
	"black_hole_04": BLACK_HOLE,
	"celestial_ring_station": RING_STATION,
	"terra_former": TERRA_FORMER,
	"gaia_prime": GAIA_PRIME,
	"galactic_core": GALACTIC_CORE,
}


## The king guarding a world, keyed by the world's stable id — the same key
## save data uses, so a renamed world keeps its king.
static func texture_for(world_id: String) -> ImageTexture:
	if not SPRITES.has(world_id):
		return null
	return PixelSprite.build("king:" + world_id, SPRITES[world_id], PALETTES[world_id])
