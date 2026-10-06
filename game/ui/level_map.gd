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

## Per-world planet colours, matched to the king each world guards (see the
## `king` field in worlds.gd).
const PLANET_COLORS: Array[Color] = [
	Color(0.36, 0.95, 0.60),  # NEONIA-1, green
	Color(0.98, 0.78, 0.25),  # SULFUR-KOR, sulfur yellow
	Color(0.72, 0.48, 0.98),  # CRYSTALLOS, violet crystal
	Color(0.18, 0.16, 0.26),  # BLACK HOLE 04, near-black
	Color(0.85, 0.87, 0.95),  # CELESTIAL RING STATION, steel
	Color(0.35, 0.78, 0.95),  # TERRA-FORMER, ocean blue
	Color(0.45, 0.92, 0.70),  # GAIA PRIME, living green
	Color(0.98, 0.35, 0.72),  # GALACTIC CORE, hot pink
]

const NODE_RADIUS := 42.0
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
	_build_header()
	_build_nodes()
	resized.connect(_layout_nodes)
	_layout_nodes()


## A fixed star field rather than a per-frame random one: stars that twinkle by
## being redrawn in new places read as noise, not as sky.
func _seed_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	_stars.clear()
	for _i in 140:
		_stars.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(0.6, 2.1),
			"alpha": rng.randf_range(0.18, 0.9),
		})


## The title doubles as the way back here from a world — tapping the game name
## inside a world returns to the map — so it is deliberately the same words in
## both places. The monthly total sits under it because it is the number the
## whole map is in service of.
func _build_header() -> void:
	var title := Label.new()
	title.name = "Title"
	title.text = "MARMOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.95))
	title.add_theme_font_size_override("font_size", 34)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	_header.append(title)

	var total := Label.new()
	total.name = "MonthlyTotal"
	total.text = "THIS MONTH   %d" % progress.monthly_total()
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total.add_theme_color_override("font_color", Color(0.60, 0.88, 0.98))
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
		label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0) if unlocked else LOCKED_TINT)
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
		sub.add_theme_color_override("font_color", Color(0.62, 0.68, 0.85))
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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.027, 0.08))

	_label_zones.clear()
	for i in Worlds.COUNT:
		_label_zones.append_array(_label_zones_for(i))

	# Stars skip the label rectangles for the same reason the route's dots do.
	# A star behind transparent text is indistinguishable from a stray dot in
	# the middle of a world's name, and it costs legibility for nothing.
	for star in _stars:
		var pos: Vector2 = (star["pos"] as Vector2) * size
		if _is_on_a_label(pos):
			continue
		draw_circle(pos, star["radius"], Color(0.85, 0.90, 1.0, star["alpha"]))

	# The route, strictly between consecutive worlds. A segment is lit only if
	# its destination is unlocked, so the line doubles as the progress bar.
	for i in range(Worlds.COUNT - 1):
		var from := _node_center(i)
		var to := _node_center(i + 1)
		var reached := progress.is_unlocked(i + 1)
		var tint := Color(0.98, 0.45, 0.80, 0.75) if reached else Color(0.45, 0.45, 0.60, 0.30)
		_draw_dotted(from, to, tint, reached)

	for i in Worlds.COUNT:
		_draw_planet(i)


## Dots rather than a solid stroke — the reference uses them, and they keep the
## line from reading as a wall between the halves of the map.
func _draw_dotted(from: Vector2, to: Vector2, tint: Color, reached: bool) -> void:
	var span := to - from
	var length := span.length()
	if length < 1.0:
		return
	var step := 13.0
	var dots := int(length / step)
	var dir := span / length
	# Start and end clear of the planets so the dots do not run under them.
	for d in range(1, dots):
		var at := from + dir * (d * step)
		if at.distance_to(from) < NODE_RADIUS + 10.0:
			continue
		if at.distance_to(to) < NODE_RADIUS + 10.0:
			continue
		# A dot sitting on a world's name reads as a typo rather than as a
		# route. Leaving a gap is cheaper, and less fragile, than rerouting the
		# line around the text.
		if _is_on_a_label(at):
			continue
		draw_circle(at, 2.6 if reached else 2.0, tint)


func _draw_planet(index: int) -> void:
	var centre := _node_center(index)
	var unlocked: bool = progress.is_unlocked(index)
	var base: Color = PLANET_COLORS[index]
	if not unlocked:
		base = base.lerp(LOCKED_TINT, 0.72)

	# Halo first, as a few widening translucent discs. Cheap stand-in for real
	# bloom — the project is on the Mobile renderer so a WorldEnvironment glow
	# can replace this once the art is in.
	if unlocked:
		for ring in 3:
			var r := NODE_RADIUS + 6.0 + ring * 7.0
			draw_circle(centre, r, Color(base.r, base.g, base.b, 0.09 - ring * 0.025))

	draw_circle(centre, NODE_RADIUS, base.darkened(0.45))
	draw_circle(centre, NODE_RADIUS - 3.0, base)
	# Offset highlight, so the disc reads as a sphere rather than a dot.
	draw_circle(centre + Vector2(-NODE_RADIUS * 0.28, -NODE_RADIUS * 0.28), NODE_RADIUS * 0.42, base.lightened(0.35))

	# The final world gets a ring, so GALACTIC CORE reads as a destination
	# rather than as the eighth of eight.
	if index == Worlds.COUNT - 1:
		draw_arc(centre, NODE_RADIUS + 12.0, 0.0, TAU, 48, Color(0.98, 0.35, 0.72, 0.9 if unlocked else 0.3), 2.5)
