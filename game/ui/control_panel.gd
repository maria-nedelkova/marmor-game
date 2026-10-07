## The control panel that sits under the board.
##
## Ported from the web version's `.topbar`: a rounded deck with a gradient
## edge, a key at each end, the next-up queue between them, decoration at the
## four inner corners, and a trinket strip set into the bottom edge.
##
## The left key is RESTART rather than the web's menu — there is no pause menu
## here yet, and restarting the world is the thing you actually reach for.
## Sound stays as it was.
extends Control

signal restart_pressed
signal sound_toggled(muted: bool)

## The gradient runs top to bottom, cyan into pink, the same way the web
## version's `linear-gradient(to bottom, var(--btn-line), var(--btn-line-end))`
## does on every bordered element.
const EDGE_TOP := Color(0.39, 1.62, 1.79)
const EDGE_BOTTOM := Color(1.87, 0.42, 1.10)
const PANEL_FILL := Color(0.055, 0.075, 0.185, 0.92)
## Icon white. Slightly over 1.0 so the line art picks up the same bloom the
## rest of the chrome does rather than sitting flat against a lit frame.
const ICON := Color(1.45, 1.50, 1.60)
const CORNER_RADIUS := 14.0

## Keys are sized off the board's cell — a touch larger than one, so a key is
## never smaller than the thing it sits under. Computed rather than fixed for
## the same reason the queue is: the panel takes the board's width, so the
## board's cell is panel width / 9.
const KEY_OVERSIZE := 1.12
## Queue marbles are drawn at the BOARD's marble size, not a fixed one. The
## panel is set to the board's width, so the board's cell is panel width / 9 —
## which means the queue can match the board without being told the board's
## geometry. A fixed size drifted every time the board's sizing changed.
const QUEUE_SCALE := 0.88

var session: GameSession
var muted := false

var _ornaments: Array[Dictionary] = []
var _restart: Button
var _sound: Button


func _ready() -> void:
	_seed_ornaments()
	_restart = _make_key("Restart this world")
	_restart.pressed.connect(func() -> void: restart_pressed.emit())

	_sound = _make_key("Mute or unmute")
	_sound.pressed.connect(func() -> void:
		muted = not muted
		queue_redraw()
		sound_toggled.emit(muted))

	resized.connect(_layout)
	_layout()


## The keys are invisible Buttons — hit targets only. Their frame and icon are
## drawn by the panel, because a gradient border is not something a StyleBox
## can express and the icons are line art rather than glyphs in a font.
func _make_key(tip: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tip
	# Size is set in _layout, which knows the panel width the cell derives from.
	add_child(button)
	return button


func set_session(new_session: GameSession) -> void:
	session = new_session
	queue_redraw()


func key_size() -> float:
	var cell := size.x / float(Rules.SIZE)
	return minf(size.y - 16.0, cell * KEY_OVERSIZE)


func _layout() -> void:
	if _restart == null:
		return
	var key := key_size()
	# The same gap left and right as above and below, so a key sits in a square
	# of clear space rather than being pushed toward the ends.
	var inset := (size.y - key) * 0.5
	for button in [_restart, _sound]:
		button.custom_minimum_size = Vector2(key, key)
		button.size = Vector2(key, key)
	_restart.position = Vector2(inset, inset)
	_sound.position = Vector2(size.x - key - inset, inset)
	queue_redraw()


func _draw() -> void:
	_draw_panel()
	_draw_keys()
	_draw_ornaments()
	if session != null:
		_draw_queue()
	_draw_trinkets()


## Rounded rect with a vertical gradient edge.
##
## Drawn as a stack of one-pixel horizontal slices rather than with a
## StyleBoxFlat, because StyleBoxFlat takes a single border colour and the
## gradient is the whole point. The slices are clipped to the rounded corners
## by insetting each one, which is cheaper and steadier than a shader for a
## shape this size.
func _draw_panel() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var thickness := 2.0

	draw_rect(box.grow(-thickness), PANEL_FILL)

	var rows := int(size.y)
	for y in rows:
		var t := float(y) / maxf(1.0, float(rows - 1))
		var tint := EDGE_TOP.lerp(EDGE_BOTTOM, t)
		var inset := _corner_inset(y, rows)
		# Left and right edges.
		draw_rect(Rect2(inset, float(y), thickness, 1.0), tint)
		draw_rect(Rect2(size.x - inset - thickness, float(y), thickness, 1.0), tint)
		# Top and bottom edges, drawn where the corner curve allows.
		if y < thickness or y >= rows - thickness:
			draw_rect(Rect2(inset, float(y), size.x - inset * 2.0, 1.0), tint)


## How far in from the edge the border sits at this row, so the straight slices
## add up to a rounded corner.
func _corner_inset(y: int, rows: int) -> float:
	var distance := minf(float(y), float(rows - 1 - y))
	if distance >= CORNER_RADIUS:
		return 0.0
	var d := CORNER_RADIUS - distance
	return CORNER_RADIUS - sqrt(maxf(0.0, CORNER_RADIUS * CORNER_RADIUS - d * d))


## The next-up queue, as the marbles themselves rather than as numbers — which
## is what the web version shows and what makes the panel worth looking at.
func _draw_queue() -> void:
	var colors := session.next_queue
	if colors.is_empty():
		return
	var cell := size.x / float(Rules.SIZE)
	var diameter := cell * QUEUE_SCALE
	# Wide enough that three marbles read as three, not as a run.
	var gap := 22.0
	var total := colors.size() * diameter + (colors.size() - 1) * gap
	var at := Vector2((size.x - total) * 0.5 + diameter * 0.5, size.y * 0.5)
	for i in colors.size():
		_draw_marble(at + Vector2(i * (diameter + gap), 0.0), diameter * 0.5, colors[i])


func _draw_marble(centre: Vector2, radius: float, color_index: int) -> void:
	Marble.draw_at(self, centre, radius, color_index)


## The four inner corners: sparkles on one diagonal, hearts on the other.
##
## Opposite pairs rather than four of the same, which is what the reference
## does — four identical corners read as a border treatment, where two of each
## on crossing diagonals reads as decoration someone placed.
func _draw_ornaments() -> void:
	var key := key_size()
	var inset := (size.y - key) * 0.5
	# The two bands between a key and the queue. Everything is placed INTO one
	# of these rather than scattered across the panel and then discarded for
	# landing in the middle — that version threw away more than half of them,
	# which is why the panel looked bare rather than decorated.
	var queue_half := _queue_width() * 0.5
	var bands := [
		Vector2(key + inset + 10.0, size.x * 0.5 - queue_half - 10.0),
		Vector2(size.x * 0.5 + queue_half + 10.0, size.x - key - inset - 10.0),
	]

	for o in _ornaments:
		var band: Vector2 = bands[o["side"]]
		if band.y - band.x < 12.0:
			continue  # no room on this side at this width
		var at := Vector2(
			lerpf(band.x, band.y, o["x"]),
			lerpf(12.0, size.y - 12.0, o["y"]),
		)
		if o["heart"]:
			_draw_heart(at, o["size"], o["tint"])
		else:
			_draw_sparkle(at, o["size"], o["tint"])


## How wide the next-up queue is, so the decoration can keep clear of it.
func _queue_width() -> float:
	if session == null or session.next_queue.is_empty():
		return 0.0
	var count := session.next_queue.size()
	var diameter := (size.x / float(Rules.SIZE)) * QUEUE_SCALE
	return count * diameter + (count - 1) * 22.0


## Scattered, not set at four tidy corners — four ornaments at the corners read
## as a border treatment, where jittered sizes and positions read as decoration
## someone placed.
##
## Each is assigned a SIDE up front and then placed within that side's band, so
## both sides get a fair share and none is thrown away. Seeded, so the scatter
## is the same every launch: decoration that moves between redraws is noise.
func _seed_ornaments() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var tints: Array[Color] = [
		Color(1.75, 1.45, 0.55), Color(0.70, 1.70, 1.90),
		Color(1.80, 0.50, 1.20), Color(1.55, 1.60, 1.85),
	]
	_ornaments.clear()
	for i in 12:
		_ornaments.append({
			# Alternating rather than random, so neither band can come out
			# empty on a given seed.
			"side": i % 2,
			"x": rng.randf(),
			"y": rng.randf(),
			"size": rng.randf_range(3.0, 7.0),
			"heart": rng.randf() < 0.4,
			"tint": tints[rng.randi_range(0, tints.size() - 1)],
		})



## A filled rhomb, not a cross of thin arms. At this size a thin cross is
## nothing BUT its arms and reads as a plus sign — the body that makes a
## sparkle a sparkle has to be filled in for it to be there at all.
func _draw_sparkle(centre: Vector2, radius: float, tint: Color) -> void:
	var waist := radius * 0.30
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -radius), centre + Vector2(waist, 0.0),
		centre + Vector2(0.0, radius), centre + Vector2(-waist, 0.0),
	]), tint)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-radius, 0.0), centre + Vector2(0.0, -waist),
		centre + Vector2(radius, 0.0), centre + Vector2(0.0, waist),
	]), tint)


func _draw_heart(centre: Vector2, radius: float, tint: Color) -> void:
	draw_circle(centre + Vector2(-radius * 0.45, -radius * 0.3), radius * 0.55, tint)
	draw_circle(centre + Vector2(radius * 0.45, -radius * 0.3), radius * 0.55, tint)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-radius, -radius * 0.18),
		centre + Vector2(radius, -radius * 0.18),
		centre + Vector2(0.0, radius),
	]), tint)


## Star, coin, star, set into the bottom edge — the web version breaks its
## panel's border to let them sit astride it, which is why they are drawn after
## the panel and over a band of the fill colour.
func _draw_trinkets() -> void:
	var y := size.y
	var band := Vector2(160.0, 26.0)
	draw_rect(Rect2(Vector2((size.x - band.x) * 0.5, y - band.y * 0.5), band), Color(0.035, 0.027, 0.08))

	var centre := Vector2(size.x * 0.5, y)
	_draw_star(centre + Vector2(-48.0, 0.0), 12.0, Color(0.55, 1.65, 1.85))
	_draw_coin(centre, 12.0)
	_draw_star(centre + Vector2(48.0, 0.0), 12.0, Color(1.75, 1.35, 0.42))


func _draw_star(centre: Vector2, radius: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.42
		var angle := -PI * 0.5 + i * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, tint)


func _draw_coin(centre: Vector2, radius: float) -> void:
	draw_circle(centre, radius, Color(1.6, 1.15, 0.30))
	draw_circle(centre, radius * 0.55, Color(1.85, 1.55, 0.60))


## The two keys: a gradient-bordered rounded square with white line art inside.
##
## Both the frame and the icon are drawn rather than themed. A StyleBox takes a
## single border colour, and the icons are strokes rather than glyphs — a font
## would mean shipping one for two symbols.
func _draw_keys() -> void:
	if _restart == null:
		return
	_draw_key_frame(Rect2(_restart.position, _restart.size))
	_draw_key_frame(Rect2(_sound.position, _sound.size))
	_draw_restart_icon(Rect2(_restart.position, _restart.size))
	_draw_sound_icon(Rect2(_sound.position, _sound.size))


## Same vertical cyan-to-pink gradient as the panel's own edge, drawn as
## horizontal slices for the same reason.
func _draw_key_frame(box: Rect2) -> void:
	var radius := 10.0
	var thickness := 2.0
	draw_rect(box.grow(-thickness), Color(0.05, 0.07, 0.17, 0.95))

	var rows := int(box.size.y)
	for y in rows:
		var t := float(y) / maxf(1.0, float(rows - 1))
		var tint := EDGE_TOP.lerp(EDGE_BOTTOM, t)
		var distance := minf(float(y), float(rows - 1 - y))
		var inset := 0.0
		if distance < radius:
			var d := radius - distance
			inset = radius - sqrt(maxf(0.0, radius * radius - d * d))
		var at_y := box.position.y + y
		draw_rect(Rect2(box.position.x + inset, at_y, thickness, 1.0), tint)
		draw_rect(Rect2(box.position.x + box.size.x - inset - thickness, at_y, thickness, 1.0), tint)
		if y < thickness or y >= rows - thickness:
			draw_rect(Rect2(box.position.x + inset, at_y, box.size.x - inset * 2.0, 1.0), tint)


## A circular arrow — the icon for the thing this key actually does.
##
## The reference's left key is a hamburger, and this was one too for a while
## because the panel's composition is built around that shape. But it restarts
## the world rather than opening a menu, and a hamburger that does not open a
## menu is a lie told in the one place a player looks when they are lost. The
## shape is close enough in weight that the two ends still balance.
func _draw_restart_icon(box: Rect2) -> void:
	var centre := box.position + box.size * 0.5
	var radius := box.size.x * 0.25

	# An almost-closed circle: the gap is what makes it read as an arrow going
	# round rather than as a ring.
	var start := -PI * 0.32
	draw_arc(centre, radius, start, start + TAU * 0.82, 32, ICON, 3.0)

	# The head sits at the open end, pointing back the way the arc came, so the
	# eye follows it around rather than off the icon.
	var at := centre + Vector2(cos(start), sin(start)) * radius
	var along := Vector2(sin(start), -cos(start))
	var across := Vector2(-along.y, along.x)
	draw_colored_polygon(PackedVector2Array([
		at + along * 7.0,
		at + across * 5.0 - along * 2.0,
		at - across * 5.0 - along * 2.0,
	]), ICON)

## A speaker cone with two arcs, or with a cross when muted — the state has to
## be visible without tapping it to find out.
func _draw_sound_icon(box: Rect2) -> void:
	var cx := box.position.x + box.size.x * 0.5
	var cy := box.position.y + box.size.y * 0.5
	var s := box.size.x * 0.1

	# Body and cone.
	draw_rect(Rect2(cx - s * 2.0, cy - s * 0.8, s * 1.1, s * 1.6), ICON)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - s * 0.9, cy - s * 0.8),
		Vector2(cx + s * 0.2, cy - s * 1.9),
		Vector2(cx + s * 0.2, cy + s * 1.9),
		Vector2(cx - s * 0.9, cy + s * 0.8),
	]), ICON)

	if muted:
		var a := Vector2(cx + s * 0.9, cy - s * 1.0)
		var b := Vector2(cx + s * 2.3, cy + s * 1.0)
		draw_line(a, b, ICON, 2.5)
		draw_line(Vector2(a.x, b.y), Vector2(b.x, a.y), ICON, 2.5)
	else:
		for i in 2:
			draw_arc(
				Vector2(cx + s * 0.2, cy), s * (1.1 + i * 0.8),
				-PI * 0.33, PI * 0.33, 14, ICON, 2.2,
			)
