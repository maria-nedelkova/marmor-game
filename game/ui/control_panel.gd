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
const CORNER_RADIUS := 14.0

const KEY_SIZE := 44.0
const QUEUE_MARBLE := 26.0

var session: GameSession
var muted := false

var _restart: Button
var _sound: Button


func _ready() -> void:
	_restart = _make_key("RST", "Restart this world")
	_restart.pressed.connect(func() -> void: restart_pressed.emit())

	_sound = _make_key("SND", "Mute or unmute")
	_sound.pressed.connect(func() -> void:
		muted = not muted
		_sound.text = "OFF" if muted else "SND"
		sound_toggled.emit(muted))

	resized.connect(_layout)
	_layout()


func _make_key(text: String, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(KEY_SIZE, KEY_SIZE)
	button.size = button.custom_minimum_size
	button.add_theme_font_size_override("font_size", 12)
	add_child(button)
	return button


func set_session(new_session: GameSession) -> void:
	session = new_session
	queue_redraw()


func _layout() -> void:
	if _restart == null:
		return
	var inset := 10.0
	var mid := size.y * 0.5 - KEY_SIZE * 0.5
	_restart.position = Vector2(inset, mid)
	_sound.position = Vector2(size.x - KEY_SIZE - inset, mid)
	queue_redraw()


func _draw() -> void:
	_draw_panel()
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
	var gap := 8.0
	var total := colors.size() * QUEUE_MARBLE + (colors.size() - 1) * gap
	var at := Vector2((size.x - total) * 0.5 + QUEUE_MARBLE * 0.5, size.y * 0.5)
	for i in colors.size():
		_draw_marble(at + Vector2(i * (QUEUE_MARBLE + gap), 0.0), QUEUE_MARBLE * 0.5, colors[i])


func _draw_marble(centre: Vector2, radius: float, color_index: int) -> void:
	var palette: Array = BoardPalette.MARBLE_COLORS
	var base: Color = palette[color_index % palette.size()]
	draw_circle(centre, radius, base.darkened(0.45))
	draw_circle(centre, radius * 0.86, base)
	var lit := base.lightened(0.45)
	draw_circle(centre - Vector2(radius * 0.3, radius * 0.3), radius * 0.32, Color(lit.r * 1.18, lit.g * 1.18, lit.b * 1.18))


## Star, coin, star, set into the bottom edge — the web version breaks its
## panel's border to let them sit astride it, which is why they are drawn after
## the panel and over a band of the fill colour.
func _draw_trinkets() -> void:
	var y := size.y
	var band := Vector2(84.0, 14.0)
	draw_rect(Rect2(Vector2((size.x - band.x) * 0.5, y - band.y * 0.5), band), Color(0.035, 0.027, 0.08))

	var centre := Vector2(size.x * 0.5, y)
	_draw_star(centre + Vector2(-26.0, 0.0), 6.0, Color(0.55, 1.65, 1.85))
	_draw_coin(centre, 6.0)
	_draw_star(centre + Vector2(26.0, 0.0), 6.0, Color(1.75, 1.35, 0.42))


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
