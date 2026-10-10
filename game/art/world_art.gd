## Supplied world art: a planet and its king together, one PNG per world.
##
## Drop a file named for the world's id into `game/art/worlds/` — neonia_1.png,
## sulfur_kor.png, and so on — and the map draws it instead of the sprites
## authored in planets.gd and kings.gd. Worlds without a file keep the
## authored pair, so the set can be replaced one at a time rather than all at
## once.
##
## ## Why these are loaded rather than converted
##
## The authored art lives as strings so it is visible and diffable in source.
## Supplied art does not get that treatment: converting a PNG into strings and
## a palette would be a lossy middle step between what was drawn and what
## renders, and the whole reason for taking files is that the result should be
## exactly what was drawn.
##
## ## What the files need to be
##
## See game/art/worlds/README.md. The short version: PNG, transparent
## background, no labels, native pixel resolution or an exact integer multiple
## of it, exported with nearest-neighbour rather than bicubic.
class_name WorldArt

const DIR := "res://game/art/worlds"

static var _cache: Dictionary = {}


## The supplied art for a world, or null if there is none.
static func texture_for(world_id: String) -> Texture2D:
	if _cache.has(world_id):
		return _cache[world_id]

	var path := "%s/%s.png" % [DIR, world_id]
	var texture: Texture2D = null
	# ResourceLoader rather than FileAccess: a PNG only becomes loadable after
	# Godot imports it, and asking the loader is the same question as "has this
	# been imported yet".
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_cache[world_id] = texture
	return texture


static func has(world_id: String) -> bool:
	return texture_for(world_id) != null


## Which worlds are still on authored art. Printed by dev/art_report so the
## state of a part-finished swap is visible without opening the folder.
static func missing() -> Array[String]:
	var out: Array[String] = []
	for i in Worlds.COUNT:
		var id: String = Worlds.get_world(i)["id"]
		if not has(id):
			out.append(id)
	return out
