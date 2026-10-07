## The background sky, matched to the web version's body/html star layers.
##
## Not a uniform scatter of white dots. The web field mixes three things, and
## dropping any of them makes it read as noise rather than as sky:
##
##   - plain dots at a range of sizes and alphas
##   - four-pointed rhomb sparkles, larger and brighter
##   - loose constellations — a few stars placed close together, so the eye
##     finds groups instead of an even wash
##
## Colours vary too: white, pale blue, pale pink and pale gold, rather than one
## white. A single colour at a single size is the tell that a starfield was
## generated rather than placed.
class_name Starfield

const TINTS: Array[Color] = [
	Color(1.25, 1.30, 1.45),  # white
	Color(0.85, 1.05, 1.55),  # blue
	Color(1.50, 0.95, 1.35),  # pink
	Color(1.50, 1.30, 0.85),  # gold
]


## Builds a fixed field. Seeded, because stars that move between redraws read as
## static — and because the same seed gives the same sky every launch, which is
## what makes it feel like a place.
static func build(seed_value: int, count: int, sparkles: int, constellations: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Dictionary] = []

	for _i in count:
		out.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(0.6, 2.2),
			"alpha": rng.randf_range(0.25, 0.95),
			"tint": TINTS[rng.randi_range(0, TINTS.size() - 1)],
			"sparkle": false,
		})

	# Constellations: a tight cluster around a point, so the field has texture
	# at a scale larger than one star.
	for _c in constellations:
		var anchor := Vector2(rng.randf(), rng.randf())
		var members := rng.randi_range(3, 6)
		var tint: Color = TINTS[rng.randi_range(0, TINTS.size() - 1)]
		for _m in members:
			var offset := Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.04, 0.04))
			out.append({
				"pos": (anchor + offset).clamp(Vector2.ZERO, Vector2.ONE),
				"radius": rng.randf_range(0.9, 2.0),
				"alpha": rng.randf_range(0.45, 1.0),
				"tint": tint,
				"sparkle": false,
			})

	for _s in sparkles:
		out.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(3.0, 5.5),
			"alpha": rng.randf_range(0.6, 1.0),
			"tint": TINTS[rng.randi_range(0, TINTS.size() - 1)],
			"sparkle": true,
		})

	return out


## Draws the field into `area`. `exclude` is a list of rectangles the stars keep
## out of — a star behind transparent text is indistinguishable from a stray dot
## in the middle of a word.
static func draw_field(
	canvas: CanvasItem, stars: Array[Dictionary], area: Rect2, exclude: Array[Rect2] = []
) -> void:
	for star in stars:
		var at: Vector2 = area.position + (star["pos"] as Vector2) * area.size
		var skip := false
		for zone in exclude:
			if zone.has_point(at):
				skip = true
				break
		if skip:
			continue

		var tint: Color = star["tint"]
		var color := Color(tint.r, tint.g, tint.b, star["alpha"])
		if star["sparkle"]:
			_draw_sparkle(canvas, at, star["radius"], color)
		else:
			canvas.draw_circle(at, star["radius"], color)


## A four-pointed rhomb, not a disc — the shape the web draws as an inline SVG
## because a radial-gradient can only ever make a round blob.
static func _draw_sparkle(canvas: CanvasItem, centre: Vector2, radius: float, tint: Color) -> void:
	var waist := radius * 0.26
	canvas.draw_colored_polygon(
		PackedVector2Array([
			centre + Vector2(0.0, -radius),
			centre + Vector2(waist, 0.0),
			centre + Vector2(0.0, radius),
			centre + Vector2(-waist, 0.0),
		]),
		tint,
	)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			centre + Vector2(-radius, 0.0),
			centre + Vector2(0.0, -waist),
			centre + Vector2(radius, 0.0),
			centre + Vector2(0.0, waist),
		]),
		tint,
	)
