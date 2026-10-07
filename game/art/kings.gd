## The eight kings, one per world.
##
## Hand-authored 12x12 heads, drawn directly as strings so the sprite is
## visible in the source (see pixel_sprite.gd). Each character is a palette
## key; "." is transparent.
##
## They are heads rather than full figures because they sit on map nodes at
## about 36px — a full body at that size is a smudge, while a face reads. The
## web version's full-length mascots are a different problem with a different
## answer, and are not what these are ported from: these are new art, matched
## to the worlds in worlds.gd.
##
## Each is distinguished by HEADGEAR first and palette second. Colour alone
## fails for the player who cannot easily tell violet from blue, and fails
## again on the map where every node is already tinted by its planet.
##
## Palette keys, used consistently across all eight:
##   k outline   c crown/headgear   h crown highlight
##   l skin light   m skin mid   d skin dark
##   e eye   w eye glint   b beard/hair   a accent
class_name Kings


## 01 NEONIA-1 — the first king. A plain three-point crown and nothing else:
## he is the baseline the rest are variations on, so he carries no gimmick.
const NEONIA := [
	"..c.....c...",
	"..c..c..c...",
	".cccccccccc.",
	".chhhhhhhhc.",
	"..kkkkkkkk..",
	".kllllllllk.",
	".klleelleek.",
	".klewwellek.",
	".kmmmmmmmmk.",
	"..kmmmmmmk..",
	"...kbbbbk...",
	"....kkkk....",
]

## 02 SULFUR-KOR — a crown of flame. Jagged and asymmetric, because fire that
## mirrors itself reads as a pattern rather than as burning.
const SULFUR := [
	"..c...c.c...",
	".ch..chch...",
	".chc.chchc..",
	"..chccchch..",
	"...ccccccc..",
	".kkllllllkk.",
	".klleelleek.",
	".klewwellek.",
	".kmmmmmmmmk.",
	"..kmbbbbmk..",
	"...kbbbbk...",
	"....kkkk....",
]

## 03 CRYSTALLOS — shards instead of points, taller and thinner, with the
## facets catching light at different heights.
const CRYSTALLOS := [
	"..c...c...c.",
	"..ch..ch..ch",
	".cchccchccch",
	".ccccccccccc",
	"..kkkkkkkkk.",
	".kllllllllk.",
	".kleellee.k.",
	".klewwellek.",
	".kmmmmmmmmk.",
	"..kmmmmmmk..",
	"...kaaaak...",
	"....kkkk....",
]

## 04 BLACK HOLE 04 — no face at all. A ring of accreting light around a void
## with two points where eyes would be. The world has no king; it has a thing.
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

## 05 CELESTIAL RING STATION — a visored helm. A single horizontal slit, no
## skin showing: the one king you never see the face of.
const RING_STATION := [
	"....chhc....",
	"...cchhcc...",
	"..cchhhhcc..",
	".cchhhhhhcc.",
	".ckkkkkkkkc.",
	".ceeeeeeeec.",
	".cwwwwwwwwc.",
	".ckkkkkkkkc.",
	".cchhhhhhcc.",
	"..cchhhhcc..",
	"...caaaac...",
	"....kkkk....",
]

## 06 TERRA-FORMER — a crown of leaves, with the fronds spreading outward
## rather than up. Growth, not authority.
const TERRA_FORMER := [
	"c..c....c..c",
	".chc.cc.chc.",
	"..chccchch..",
	"...cccccc...",
	"..kkkkkkkk..",
	".kllllllllk.",
	".kleellee.k.",
	".klewwellek.",
	".kmmmmmmmmk.",
	"..kmbbbbmk..",
	"...kbbbbk...",
	"....kkkk....",
]

## 07 GAIA PRIME — an orbital halo. The ring passes BEHIND the head at the top
## and in front at the bottom, which is what makes it read as orbiting rather
## than as a hat.
const GAIA_PRIME := [
	"...aaaaaa...",
	"..a......a..",
	".a.cccccc.a.",
	".a.chhhhc.a.",
	"a..kkkkkk..a",
	"a.kllllllk.a",
	"a.kleellek.a",
	".aklewwelka.",
	".akmmmmmmka.",
	"..akmmmmka..",
	"...akbbka...",
	"....aaaa....",
]

## 08 GALACTIC CORE — a silhouette. No skin, no crown, only a shape and two
## burning eyes. The finale should not look like another man in a hat.
const GALACTIC_CORE := [
	"....aaaa....",
	"...akkkka...",
	"..akkkkkka..",
	".akkkkkkkka.",
	".akkkkkkkka.",
	".akkeekkeeka",
	".akkwekkewka",
	".akkkkkkkka.",
	".aakkkkkkaa.",
	"..aakkkkaa..",
	"...aaaaaa...",
	"....aaaa....",
]


## Palettes. Skin tones differ per world as well as headgear, so the eight do
## not read as one man in eight hats.
const PALETTES := {
	"neonia_1": {
		"k": Color(0.11, 0.09, 0.18), "c": Color(0.98, 0.82, 0.28), "h": Color(1.0, 0.94, 0.62),
		"l": Color(0.98, 0.86, 0.74), "m": Color(0.89, 0.72, 0.58), "d": Color(0.62, 0.45, 0.35),
		"e": Color(0.16, 0.20, 0.32), "w": Color(1.0, 1.0, 1.0), "b": Color(0.76, 0.60, 0.44),
		"a": Color(0.36, 0.95, 0.60),
	},
	"sulfur_kor": {
		"k": Color(0.16, 0.08, 0.06), "c": Color(0.98, 0.42, 0.14), "h": Color(1.0, 0.82, 0.30),
		"l": Color(0.95, 0.74, 0.60), "m": Color(0.84, 0.56, 0.42), "d": Color(0.55, 0.32, 0.22),
		"e": Color(0.98, 0.90, 0.40), "w": Color(1.0, 1.0, 0.86), "b": Color(0.72, 0.38, 0.20),
		"a": Color(0.98, 0.78, 0.25),
	},
	"crystallos": {
		"k": Color(0.14, 0.10, 0.22), "c": Color(0.78, 0.56, 1.0), "h": Color(0.94, 0.86, 1.0),
		"l": Color(0.90, 0.84, 0.98), "m": Color(0.76, 0.68, 0.90), "d": Color(0.50, 0.42, 0.66),
		"e": Color(0.42, 0.24, 0.70), "w": Color(1.0, 1.0, 1.0), "b": Color(0.64, 0.54, 0.84),
		"a": Color(0.72, 0.48, 0.98),
	},
	"black_hole_04": {
		"k": Color(0.05, 0.04, 0.09), "c": Color(0.30, 0.26, 0.40), "h": Color(0.46, 0.40, 0.58),
		"l": Color(0.22, 0.18, 0.30), "m": Color(0.16, 0.13, 0.24), "d": Color(0.09, 0.07, 0.15),
		"e": Color(1.0, 0.86, 0.52), "w": Color(1.0, 1.0, 1.0), "b": Color(0.18, 0.15, 0.26),
		"a": Color(0.99, 0.64, 0.26),
	},
	"celestial_ring_station": {
		"k": Color(0.12, 0.12, 0.18), "c": Color(0.72, 0.74, 0.84), "h": Color(0.93, 0.95, 1.0),
		"l": Color(0.86, 0.88, 0.96), "m": Color(0.62, 0.65, 0.76), "d": Color(0.38, 0.40, 0.52),
		"e": Color(0.30, 0.86, 0.98), "w": Color(0.76, 0.98, 1.0), "b": Color(0.52, 0.55, 0.68),
		"a": Color(0.98, 0.82, 0.30),
	},
	"terra_former": {
		"k": Color(0.10, 0.16, 0.12), "c": Color(0.36, 0.78, 0.38), "h": Color(0.62, 0.94, 0.56),
		"l": Color(0.86, 0.74, 0.60), "m": Color(0.70, 0.56, 0.42), "d": Color(0.44, 0.34, 0.24),
		"e": Color(0.22, 0.44, 0.26), "w": Color(1.0, 1.0, 1.0), "b": Color(0.42, 0.62, 0.34),
		"a": Color(0.35, 0.78, 0.95),
	},
	"gaia_prime": {
		"k": Color(0.09, 0.16, 0.18), "c": Color(0.98, 0.84, 0.36), "h": Color(1.0, 0.95, 0.70),
		"l": Color(0.84, 0.92, 0.84), "m": Color(0.64, 0.78, 0.68), "d": Color(0.40, 0.54, 0.46),
		"e": Color(0.14, 0.42, 0.40), "w": Color(1.0, 1.0, 1.0), "b": Color(0.46, 0.70, 0.56),
		"a": Color(0.45, 0.92, 0.70),
	},
	"galactic_core": {
		"k": Color(0.08, 0.05, 0.14), "c": Color(0.40, 0.14, 0.34), "h": Color(0.62, 0.24, 0.50),
		"l": Color(0.26, 0.10, 0.24), "m": Color(0.18, 0.07, 0.17), "d": Color(0.11, 0.04, 0.11),
		"e": Color(1.0, 0.36, 0.74), "w": Color(1.0, 0.86, 0.95), "b": Color(0.22, 0.08, 0.20),
		"a": Color(0.98, 0.35, 0.72),
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
