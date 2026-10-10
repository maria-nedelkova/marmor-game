## The eight worlds as 16x16 pixel art, one per map node.
##
## Drawn from docs/reference/level-map.jpeg for the same reasons the kings are
## (see kings.gd): the reference's planets are small, lossy and each sits on a
## different background, so they are reproduced rather than cut out.
##
## 16x16 rather than the kings' 12x12. A planet is the node itself and the king
## only a badge beside it, so the planet carries more detail and needs the room
## — a cracked sphere or a crystal cluster has nothing to show at 12.
##
## Palette keys, shared across all eight so a misspelling cannot silently draw
## a hole:
##   d rim/dark   m body mid   l body light   h highlight
##   a feature accent   b second accent   g ring or glow   w white
class_name Planets

## 01 NEONIA-1 — a green world inside a gold orbital ring.
const NEONIA := [
	".....gggggg.....",
	"...gg......gg...",
	"..g..dddddd..g..",
	".g.ddmmllmmdd.g.",
	".g.dmllhhllmd.g.",
	"g.dmmlhhhhlmmd.g",
	"g.dmmllhhllmmd.g",
	"g.dmmmllllmmmd.g",
	"g.dmmmmmmmmmmd.g",
	"g.dmmmmmmmmmmd.g",
	".g.dmmmmmmmmd.g.",
	".g.ddmmmmmmdd.g.",
	"..g..dddddd..g..",
	"...gg......gg...",
	".....gggggg.....",
	"................",
]

## 02 SULFUR-KOR — a cracked sulfur sphere, the fissures running across it.
const SULFUR := [
	".....dddddd.....",
	"...dddmmmmddd...",
	"..ddmmlllmmmdd..",
	".ddmmlllmmmammd.",
	".dmmlllmmammmmd.",
	"ddmmllmmammmmmdd",
	"dmmlmmmammmmmmmd",
	"dmmmmmammmmmmmmd",
	"dmmmmammmmmammmd",
	"dmmmammmmmammmmd",
	"ddmmmmmmmammmmdd",
	".dmmmmmmammmmmd.",
	".ddmmmmammmmmdd.",
	"..ddmmmmmmmmdd..",
	"...dddmmmmddd...",
	".....dddddd.....",
]

## 03 CRYSTALLOS — a cluster of shards rather than a sphere, which is what
## makes it read as a crystal world at a glance.
const CRYSTALLOS := [
	"......aa........",
	".....ahha.......",
	"..a..ahha..a....",
	".aha.amma.aha...",
	".ahha.amm.ahha..",
	"..ahhaammaahha..",
	"...ammmmmmmma...",
	"..ammllmmllmma..",
	".ammlhhmmhhlmma.",
	".ammllmmmmllmma.",
	"..ammmmmmmmmma..",
	"...ammmmmmmma...",
	"....ammmmmma....",
	".....ammmma.....",
	"......amma......",
	".......aa.......",
]

## 04 BLACK HOLE 04 — a void with an accretion disc cutting across it. The disc
## is drawn WIDER than the sphere, which is the only thing that stops the node
## reading as an empty hole.
const BLACK_HOLE := [
	"................",
	".....dddddd.....",
	"...ddkkkkkkdd...",
	"..dkkkkkkkkkkd..",
	".dkkkkkkkkkkkkd.",
	".dkkkkkkkkkkkkd.",
	"aakkkkkkkkkkkkaa",
	"haakkkkkkkkkkaah",
	"whaakkkkkkkkaahw",
	"haakkkkkkkkkkaah",
	"aakkkkkkkkkkkkaa",
	".dkkkkkkkkkkkkd.",
	".dkkkkkkkkkkkkd.",
	"..dkkkkkkkkkkd..",
	"...ddkkkkkkdd...",
	".....dddddd.....",
]

## 05 CELESTIAL RING STATION — a hub inside a wide flat ring, seen near edge on.
const RING_STATION := [
	"................",
	"................",
	"......dddd......",
	".....dmmmmd.....",
	".....dmllmd.....",
	"....ddmmmmdd....",
	"..ggddmmmmddgg..",
	".gghhdmmmmdhhgg.",
	"ggwhhddmmddhhwgg",
	".gghhdddddDhhgg.",
	"..ggdd....ddgg..",
	"....g......g....",
	"................",
	"................",
	"................",
	"................",
]

## 06 TERRA-FORMER — ocean and continents, with the red marks of terraforming
## works on its surface.
const TERRA_FORMER := [
	".....dddddd.....",
	"...dddmmmmddd...",
	"..ddmaammmmmdd..",
	".ddmaaammmaammd.",
	".dmmaammmaaammd.",
	"ddmmmmmbmmaammdd",
	"dmmaammmmmmmmmmd",
	"dmaaammmmmaaammd",
	"dmaammmmmaaaammd",
	"dmmmmmmbmmaaammd",
	"ddmmaammmmmmmmdd",
	".dmmaaammmmaamd.",
	".ddmmaammmaammd.",
	"..ddmmmmaammdd..",
	"...dddmmmmddd...",
	".....dddddd.....",
]

## 07 GAIA PRIME — a living world crossed by two orbital rings.
const GAIA_PRIME := [
	"................",
	"..g..........g..",
	"...gg.dddd.gg...",
	"....ggdmmdgg....",
	"...gg.dmmd.gg...",
	"..gg.dmaamd.gg..",
	".gg.dmaaaamd.gg.",
	"gg.dmmaaaammd.gg",
	"gg.dmmaaaammd.gg",
	".gg.dmaaaamd.gg.",
	"..gg.dmaamd.gg..",
	"...gg.dmmd.gg...",
	"....ggdmmdgg....",
	"...gg.dddd.gg...",
	"..g..........g..",
	"................",
]

## 08 GALACTIC CORE — not a planet but a burning point, with rays. The finale
## should not look like another sphere.
const GALACTIC_CORE := [
	".......aa.......",
	".......aa.......",
	"....a..hh..a....",
	".....a.hh.a.....",
	"......ahha......",
	"..a...ahha...a..",
	"...a.ahwwha.a...",
	"aaaaahwwwwhaaaaa",
	"aaaaahwwwwhaaaaa",
	"...a.ahwwha.a...",
	"..a...ahha...a..",
	"......ahha......",
	".....a.hh.a.....",
	"....a..hh..a....",
	".......aa.......",
	".......aa.......",
]

const PALETTES := {
	"neonia_1": {
		"d": Color(0.07, 0.35, 0.22), "m": Color(0.18, 0.72, 0.42), "l": Color(0.36, 0.92, 0.58),
		"h": Color(0.70, 1.0, 0.80), "a": Color(0.20, 0.80, 0.50), "b": Color(0.12, 0.55, 0.32),
		"g": Color(0.98, 0.80, 0.30), "w": Color(1.0, 1.0, 1.0), "k": Color(0.04, 0.16, 0.10),
	},
	"sulfur_kor": {
		"d": Color(0.42, 0.28, 0.06), "m": Color(0.85, 0.66, 0.16), "l": Color(0.98, 0.86, 0.38),
		"h": Color(1.0, 0.96, 0.66), "a": Color(0.34, 0.20, 0.04), "b": Color(0.60, 0.40, 0.10),
		"g": Color(0.98, 0.72, 0.22), "w": Color(1.0, 1.0, 1.0), "k": Color(0.20, 0.12, 0.03),
	},
	"crystallos": {
		"d": Color(0.26, 0.14, 0.42), "m": Color(0.60, 0.36, 0.88), "l": Color(0.78, 0.58, 0.98),
		"h": Color(0.94, 0.86, 1.0), "a": Color(0.42, 0.22, 0.68), "b": Color(0.34, 0.18, 0.56),
		"g": Color(0.72, 0.48, 0.98), "w": Color(1.0, 1.0, 1.0), "k": Color(0.14, 0.07, 0.24),
	},
	"black_hole_04": {
		"d": Color(0.16, 0.10, 0.20), "m": Color(0.10, 0.07, 0.14), "l": Color(0.20, 0.14, 0.26),
		"h": Color(1.0, 0.62, 0.18), "a": Color(0.86, 0.36, 0.10), "b": Color(0.52, 0.20, 0.06),
		"g": Color(0.70, 0.30, 0.10), "w": Color(1.0, 0.92, 0.70), "k": Color(0.03, 0.02, 0.05),
	},
	"celestial_ring_station": {
		"d": Color(0.34, 0.36, 0.44), "m": Color(0.68, 0.71, 0.80), "l": Color(0.90, 0.93, 0.98),
		"h": Color(0.78, 0.82, 0.92), "a": Color(0.50, 0.53, 0.62), "b": Color(0.42, 0.45, 0.54),
		"g": Color(0.58, 0.62, 0.74), "w": Color(1.0, 1.0, 1.0), "k": Color(0.16, 0.17, 0.22),
		"D": Color(0.30, 0.32, 0.40),
	},
	"terra_former": {
		"d": Color(0.06, 0.22, 0.38), "m": Color(0.16, 0.44, 0.70), "l": Color(0.34, 0.64, 0.88),
		"h": Color(0.62, 0.86, 1.0), "a": Color(0.26, 0.64, 0.30), "b": Color(0.88, 0.26, 0.22),
		"g": Color(0.40, 0.78, 0.44), "w": Color(1.0, 1.0, 1.0), "k": Color(0.03, 0.12, 0.22),
	},
	"gaia_prime": {
		"d": Color(0.08, 0.30, 0.30), "m": Color(0.16, 0.52, 0.52), "l": Color(0.34, 0.76, 0.66),
		"h": Color(0.66, 0.96, 0.82), "a": Color(0.34, 0.80, 0.42), "b": Color(0.20, 0.58, 0.32),
		"g": Color(0.45, 0.95, 0.60), "w": Color(1.0, 1.0, 1.0), "k": Color(0.04, 0.16, 0.16),
	},
	"galactic_core": {
		"d": Color(0.40, 0.10, 0.34), "m": Color(0.70, 0.18, 0.54), "l": Color(0.92, 0.36, 0.72),
		"h": Color(1.0, 0.68, 0.92), "a": Color(0.88, 0.28, 0.66), "b": Color(0.56, 0.14, 0.44),
		"g": Color(0.98, 0.40, 0.76), "w": Color(1.0, 1.0, 1.0), "k": Color(0.22, 0.05, 0.18),
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


static func texture_for(world_id: String) -> ImageTexture:
	if not SPRITES.has(world_id):
		return null
	return PixelSprite.build("planet:" + world_id, SPRITES[world_id], PALETTES[world_id])
