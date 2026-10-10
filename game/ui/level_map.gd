## The level map — the first screen the player sees.
##
## Eight worlds along a route, unlocked in order, every unlocked one replayable.
## Tapping one emits `world_selected`.
##
## ## What the reference got wrong, and what this does instead
##
## `docs/reference/level-map.jpeg` is right about mood and wrong about
## structure. It carries three nodes labelled 07, a level 10 that does not
## exist, and connection lines that wander and cross. Here:
##
## - Exactly eight nodes, numbered 01-08 once each, from `Worlds`.
## - The route is drawn strictly between consecutive worlds, so the line reads
##   as the progression it is rather than as decoration.
## - Nothing unreachable is drawn as if it were a level. The nebulae and comets
##   in the reference are background, and background is all they are here.
##
## ## Where the layout lives
##
## Node positions and planet colours are in THIS file, not in `worlds.gd`.
## That split is deliberate: worlds.gd is the portable data a different
## renderer would reuse unchanged — names, kings, targets, difficulty dials —
## while where a planet sits on screen and what colour it is belong to this
## particular map. Positions are fractions of the viewport so the map scales
## to any phone rather than assuming 720x1280.
extends Control

signal world_selected(world_index: int)

## Fractions of the play area, in world order. The route snakes left-right so
## consecutive nodes are never co-linear for long — a straight ladder reads as
## a list, and the reference's appeal is that it reads as a journey.
const LAYOUT: Array[Vector2] = [
	Vector2(0.20, 0.13),
	Vector2(0.58, 0.21),
	Vector2(0.83, 0.33),
	Vector2(0.50, 0.42),
	Vector2(0.18, 0.52),
	Vector2(0.47, 0.63),
	Vector2(0.78, 0.72),
	Vector2(0.48, 0.87),
]

const NODE_RADIUS := 42.0
## Planets are drawn at a whole multiple of their 16px art — 4x — so the pixel
## grid stays square. See PixelSprite.draw_scaled.
const PLANET_SIZE := 64.0
## The king hangs off the planet's upper right, the way the reference sets its
## avatars beside each world rather than on top of them.
##
## 48 is deliberate rather than tasteful: the sprites are 12px, and
## PixelSprite.draw_scaled only ever uses whole-number scales, so 48 is exactly
## 4x. At 36 it was 3x and the crowns were legible but cramped; anything
## between would round down and waste the space without adding a pixel.
const KING_SIZE := 48.0
## Gap between a planet and its first label row. Used by BOTH the layout and
## the label-zone helper, which must agree — when they were two literals, the
## final world's ring (NODE_RADIUS + 12) ended up drawn across its own name.
const LABEL_TOP_GAP := 18.0
const LOCKED_TINT := Color(0.32, 0.34, 0.44)

var progress: PlayerProgress
var _nodes: Array[Control] = []
var _stars: Array[Dictionary] = []
var _header: Array[Label] = []
## Rectangles the route must not drop dots inside — the node labels. Rebuilt on
## every layout, because they move with the viewport.
var _label_zones: Array[Rect2] = []
## Soft colour behind the stars. Built once and kept, like the field itself.
var _nebula: Array[Dictionary] = []


func _ready() -> void:
	# Injectable: set `progress` after instantiate() and before add_child() to
	# drive the map from a specific profile. Tests rely on this, and so would a
	# "preview someone else's run" screen. Loading from disk is only the
	# default, not a hard dependency on the filesystem.
	if progress == null:
		progress = PlayerProgress.load_progress()
		# A month may have turned over while the game was closed.
		if progress.roll_period_if_needed():
			progress.save()

	_seed_stars()
	_seed_nebula()
	_build_header()
	_build_nodes()
	resized.connect(_layout_nodes)
	_layout_nodes()


## The shared field: mixed sizes, four tints, rhomb sparkles and loose
## constellations. See starfield.gd on why a uniform scatter of white dots
## reads as noise rather than as sky.
func _seed_stars() -> void:
	_stars = Starfield.build(424242, 250, 13, 11, 9)


## Clouds of colour behind the stars, which is what separates the reference's
## sky from a black rectangle with dots on it.
##
## Each is a stack of widening translucent discs rather than one disc: a single
## translucent circle has a visible edge no matter how faint it is, and an edge
## is exactly what a nebula must not have. Stacking them lets the falloff do
## the work.
##
## Seeded, so the sky is the same place every launch.
func _seed_nebula() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31415
	var tints: Array[Color] = [
		Color(0.42, 0.18, 0.62),
		Color(0.16, 0.26, 0.68),
		Color(0.62, 0.16, 0.48),
		Color(0.14, 0.34, 0.54),
	]
	_nebula.clear()
	for i in 7:
		_nebula.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(0.18, 0.40),
			"tint": tints[i % tints.size()],
			"strength": rng.randf_range(0.10, 0.20),
		})


func _draw_nebula() -> void:
	var span := maxf(size.x, size.y)
	for cloud in _nebula:
		var centre: Vector2 = (cloud["pos"] as Vector2) * size
		var radius: float = cloud["radius"] * span
		var tint: Color = cloud["tint"]
		var strength: float = cloud["strength"]
		for shell in 6:
			var t := float(shell) / 5.0
			draw_circle(
				centre,
				radius * (0.35 + t * 0.65),
				Color(tint.r, tint.g, tint.b, strength * (1.0 - t) * 0.5),
			)


## The title doubles as the way back here from a world — tapping the game name
## inside a world returns to the map — so it is deliberately the same words in
## both places. The monthly total sits under it because it is the number the
## whole map is in service of.
func _build_header() -> void:
	var title := Label.new()
	title.name = "Title"
	title.text = "MARMOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.9, 1.15, 1.75))
	title.add_theme_font_size_override("font_size", 34)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	_header.append(title)

	var total := Label.new()
	total.name = "MonthlyTotal"
	total.text = "THIS MONTH   %d" % progress.monthly_total()
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total.add_theme_color_override("font_color", Color(0.92, 1.35, 1.5))
	total.add_theme_font_size_override("font_size", 14)
	total.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(total)
	_header.append(total)


func _build_nodes() -> void:
	for child in _nodes:
		child.queue_free()
	_nodes.clear()

	for i in Worlds.COUNT:
		var world := Worlds.get_world(i)
		var unlocked := progress.is_unlocked(i)

		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(NODE_RADIUS * 2.0, NODE_RADIUS * 2.0)
		button.size = button.custom_minimum_size
		button.tooltip_text = "%s — %s" % [world["name"], world["twist"]]
		button.disabled = not unlocked
		# Locked nodes still render their planet, dimmed, so the player can see
		# what is coming rather than facing a row of anonymous padlocks.
		button.modulate = Color.WHITE if unlocked else Color(0.55, 0.55, 0.62)
		button.pressed.connect(_on_node_pressed.bind(i))
		add_child(button)
		_nodes.append(button)

		var label := Label.new()
		label.text = "%02d  %s" % [i + 1, world["name"]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(1.35, 1.4, 1.5) if unlocked else Color(0.68, 0.70, 0.82))
		label.add_theme_font_size_override("font_size", 15)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)

		var best := progress.best_for(i)
		var sub := Label.new()
		if not unlocked:
			sub.text = "LOCKED"
		elif best > 0:
			sub.text = "best %d / %d" % [best, world["target"]]
		else:
			sub.text = "target %d" % world["target"]
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_color_override("font_color", Color(0.86, 0.94, 1.15))
		sub.add_theme_font_size_override("font_size", 12)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(sub)


func _node_center(index: int) -> Vector2:
	return LAYOUT[index] * size


func _layout_nodes() -> void:
	for i in _nodes.size():
		var centre := _node_center(i)
		var button := _nodes[i]
		button.position = centre - Vector2(NODE_RADIUS, NODE_RADIUS)
		# Labels sit below the planet, centred on it and wider than it so long
		# names like CELESTIAL RING STATION are not clipped.
		var children := button.get_children()
		for c in children.size():
			var label := children[c] as Label
			if label == null:
				continue
			label.size = Vector2(NODE_RADIUS * 5.0, 18.0)
			var local_x := NODE_RADIUS - label.size.x * 0.5
			# Keep the label on screen. CELESTIAL RING STATION is wide enough
			# that centring it under the leftmost planet ran its "05" off the
			# edge of the viewport.
			var global_x := centre.x - NODE_RADIUS + local_x
			var clamped := clampf(global_x, 4.0, maxf(4.0, size.x - label.size.x - 4.0))
			label.position = Vector2(
				local_x + (clamped - global_x),
				NODE_RADIUS * 2.0 + LABEL_TOP_GAP + c * 18.0,
			)

	if _header.size() == 2:
		_header[0].size = Vector2(size.x, 40.0)
		_header[0].position = Vector2(0.0, size.y * 0.015)
		_header[1].size = Vector2(size.x, 18.0)
		_header[1].position = Vector2(0.0, size.y * 0.015 + 38.0)

	queue_redraw()


func _on_node_pressed(index: int) -> void:
	if not progress.is_unlocked(index):
		return
	world_selected.emit(index)


## Where a node's two labels sit, derived from the node's centre.
##
## Computed on demand rather than cached from _layout_nodes. The cached version
## went stale: _ready() lays out before the Control has its final size, so the
## rects were built against one size while _draw drew planets against another,
## and the route's dots skipped empty space while still crossing the text.
func _label_zones_for(index: int) -> Array[Rect2]:
	var centre := _node_center(index)
	var label_size := Vector2(NODE_RADIUS * 5.0, 18.0)
	var left := clampf(
		centre.x - label_size.x * 0.5, 4.0, maxf(4.0, size.x - label_size.x - 4.0)
	)
	var top := centre.y + NODE_RADIUS + LABEL_TOP_GAP
	return [
		Rect2(Vector2(left, top), label_size),
		Rect2(Vector2(left, top + 18.0), label_size),
	]


func _is_on_a_label(point: Vector2) -> bool:
	for zone in _label_zones:
		if zone.grow(3.0).has_point(point):
			return true
	return false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.035, 0.10))
	_draw_nebula()

	_label_zones.clear()
	for i in Worlds.COUNT:
		_label_zones.append_array(_label_zones_for(i))

	# Stars skip the label rectangles for the same reason the route's dots do.
	# A star behind transparent text is indistinguishable from a stray dot in
	# the middle of a world's name.
	Starfield.draw_field(self, _stars, Rect2(Vector2.ZERO, size), _label_zones)

	# The route, strictly between consecutive worlds. A segment is lit only if
	# its destination is unlocked, so the line doubles as the progress bar.
	for i in range(Worlds.COUNT - 1):
		var from := _node_center(i)
		var to := _node_center(i + 1)
		var reached := progress.is_unlocked(i + 1)
		var tint := Color(1.55, 0.52, 1.15, 0.95) if reached else Color(0.46, 0.40, 0.62, 0.55)
		_draw_ribbon(from, to, tint, reached)

	for i in Worlds.COUNT:
		_draw_planet(i)
		_draw_king(i)


## A wavy pink ribbon between two worlds, as the reference draws its route.
##
## The wave is perpendicular to the line and tapers to nothing at both ends, so
## consecutive segments meet cleanly at each planet instead of arriving at an
## angle. Without the taper the route visibly kinks at every node.
##
## Drawn as a polyline rather than dots: the reference's path is continuous,
## and a dotted line reads as "not yet travelled" where a solid one reads as a
## road.
func _draw_ribbon(from: Vector2, to: Vector2, tint: Color, reached: bool) -> void:
	var span := to - from
	var length := span.length()
	if length < 1.0:
		return
	var dir := span / length
	var normal := Vector2(-dir.y, dir.x)

	# Start and end clear of the planets, so the ribbon runs between them
	# rather than under them.
	var clearance := PLANET_SIZE * 0.5 + 6.0
	if length <= clearance * 2.0:
		return
	var start := from + dir * clearance
	var finish := to - dir * clearance
	var run := start.distance_to(finish)

	var steps := maxi(10, int(run / 7.0))
	var amplitude := clampf(run * 0.10, 6.0, 20.0)
	var waves := maxf(1.0, round(run / 90.0))

	var points := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		# sin(PI * t) is the taper: zero at both ends, widest in the middle.
		var swing := sin(TAU * waves * t) * amplitude * sin(PI * t)
		points.append(start.lerp(finish, t) + normal * swing)

	draw_polyline(points, tint, 5.0 if reached else 3.0, true)


## The world's king, hung off the planet's upper right.
##
## Drawn after the planet so it sits on top, and desaturated rather than
## hidden when the world is locked — seeing WHO you have still to face is
## most of what makes a map worth looking at.
func _draw_king(index: int) -> void:
	var world := Worlds.get_world(index)
	var texture := Kings.texture_for(world["id"])
	if texture == null:
		return
	var centre := _node_center(index)
	var at := centre + Vector2(NODE_RADIUS * 0.55, -NODE_RADIUS * 0.95)
	var box := Rect2(at, Vector2(KING_SIZE, KING_SIZE))
	var tint := Color.WHITE if progress.is_unlocked(index) else Color(0.5, 0.5, 0.58, 0.85)
	PixelSprite.draw_scaled(self, texture, box, tint)


## The world itself, as pixel art rather than a drawn disc.
##
## Locked worlds are dimmed with modulate rather than a second palette: the art
## is the same art, and eight more colour sets would be eight more things to
## keep in step.
func _draw_planet(index: int) -> void:
	var centre := _node_center(index)
	var texture := Planets.texture_for(Worlds.get_world(index)["id"])
	if texture == null:
		return
	var unlocked := progress.is_unlocked(index)
	var box := Rect2(
		centre - Vector2(PLANET_SIZE, PLANET_SIZE) * 0.5, Vector2(PLANET_SIZE, PLANET_SIZE)
	)
	PixelSprite.draw_scaled(
		self, texture, box, Color.WHITE if unlocked else Color(0.44, 0.46, 0.56, 0.9)
	)

	# The final world gets a ring, so GALACTIC CORE reads as a destination
	# rather than as the eighth of eight.
	if index == Worlds.COUNT - 1:
		var ring := Color(1.7, 0.55, 1.25, 0.95) if unlocked else Color(0.45, 0.18, 0.34, 0.5)
		draw_arc(centre, PLANET_SIZE * 0.5 + 10.0, 0.0, TAU, 48, ring, 2.5)
