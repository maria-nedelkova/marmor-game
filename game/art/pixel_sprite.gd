## Turns hand-authored pixel art into a texture.
##
## ## Why literal strings, and not the web version's `row()` helper
##
## The web version builds each row with `row(W, ".", [[2, 13, "g"], ...])`,
## because a long run of identical characters is painful to count and easy to
## get wrong by one. The sprites here are 12 wide, where a literal string is
## short enough to count at a glance — and in exchange the art is VISIBLE in
## the source. You can see the crown. With range calls you can only see a list
## of numbers and have to run it to find out what you drew.
##
## ## Why a texture, and not a grid of nodes
##
## The web version renders pixel art as a CSS grid of divs, which is 144 DOM
## nodes for one of these. Here each sprite is baked once into an ImageTexture
## and drawn as a single quad with nearest-neighbour filtering — the thing a
## real renderer makes easy, and one of the reasons for moving to an engine at
## all (PLAN.md section 1).
class_name PixelSprite

## Cache keyed on the sprite's identity, so eight kings are built once rather
## than once per redraw of the map.
static var _cache: Dictionary = {}


## `rows` is a list of equal-length strings; each character is a key into
## `palette`. Any character missing from the palette is transparent, which is
## what makes "." read as empty space.
static func build(key: String, rows: Array, palette: Dictionary) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]

	var height := rows.size()
	assert(height > 0, "sprite has no rows")
	var width := (rows[0] as String).length()

	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in height:
		var line: String = rows[y]
		assert(line.length() == width, "row %d is %d wide, expected %d" % [y, line.length(), width])
		for x in width:
			var ch := line[x]
			if palette.has(ch):
				image.set_pixel(x, y, palette[ch])

	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Draws a sprite scaled to `box`, pinned to whole pixels.
##
## Nearest-neighbour is set project-wide (project.godot), but an integer scale
## matters just as much: at a fractional scale some source pixels cover two
## screen pixels and their neighbours cover one, so a crown's points come out
## visibly uneven. The sprite is centred in whatever space the integer scale
## does not fill.
static func draw_scaled(canvas: CanvasItem, texture: Texture2D, box: Rect2, modulate: Color = Color.WHITE) -> void:
	var source := texture.get_size()
	if source.x <= 0.0 or source.y <= 0.0:
		return
	var scale := maxf(1.0, floorf(minf(box.size.x / source.x, box.size.y / source.y)))
	var drawn := source * scale
	var at := box.position + (box.size - drawn) * 0.5
	canvas.draw_texture_rect(texture, Rect2(at.round(), drawn), false, modulate)
