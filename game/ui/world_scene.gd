## Playing one world.
##
## Laid out the way the web version lays out a phone: the game's name, then the
## duel row (Pretender, progress bar, King), then the board, then the control
## panel pinned under it. The session owns every rule; this owns presentation
## and the two outward edges — recording a win, and going back to the map.
extends Control

signal exit_requested

const BoardViewScript := preload("res://game/ui/board_view.gd")
const DuelHeaderScript := preload("res://game/ui/duel_header.gd")
const ControlPanelScript := preload("res://game/ui/control_panel.gd")
const PlaqueScript := preload("res://game/ui/plaque.gd")
const SoundBankScript := preload("res://game/audio/sound_bank.gd")

## Wide enough for the longest short name at scale 2 — CRYSTAL is seven
## characters — plus padding. Six of these have to fit the board's width.
const RACK_KEY_WIDTH := 100.0
const RACK_TEXT_SCALE := 2.0


## Two lines of text plus padding — the tool's name over its charge count.
func _rack_height() -> float:
	return PixelFont.height(RACK_TEXT_SCALE) * 2.0 + 18.0

var session: GameSession
var world_index: int = 0

var _board_view: Control
var _duel: Control
var _panel: Control
var _title: Control
var _prompt := ""
var _status_label: Label
var _tool_bar: Control
var _stars: Array[Dictionary] = []
var _sound: Node


func _ready() -> void:
	_build()
	start(world_index)


func start(index: int) -> void:
	world_index = index
	session = GameSession.new(index)
	session.marble_moved.connect(_on_moved)
	session.cells_cleared.connect(_on_cleared)
	session.marbles_spawned.connect(_on_spawned)
	session.score_changed.connect(_refresh)
	session.queue_changed.connect(func(_colors: Array[int]) -> void: _refresh())
	session.armed_changed.connect(func(_id: String) -> void: _refresh())
	session.finished.connect(_on_finished)

	if _board_view != null:
		_board_view.set_session(session)
		_duel.set_session(session)
		_panel.set_session(session)
	if _status_label != null:
		_status_label.text = ""
	_refresh()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Counts are high because the board masks roughly two thirds of the screen:
	# stars are kept off it, so only the bands above and below it ever show, and
	# a count that looks right across the whole rect looks sparse in those bands.
	_stars = Starfield.build(8080, 340, 16, 14, 11)

	# "LEVEL 6" over "TERRA-FORMER" in a stepped neon plaque. Also the way back
	# to the map, as on the web.
	_title = Control.new()
	_title.set_script(PlaqueScript)
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.pressed.connect(func() -> void:
		if _board_view != null:
			_board_view.settle()
		exit_requested.emit())
	add_child(_title)

	_duel = Control.new()
	_duel.set_script(DuelHeaderScript)
	_duel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_duel)

	_board_view = Control.new()
	_board_view.set_script(BoardViewScript)
	_board_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_board_view.stars = _stars
	_board_view.cell_tapped.connect(_on_cell_tapped)
	_board_view.animation_finished.connect(_refresh)
	# Sound is driven by the VIEW rather than the session. The session resolves a
	# whole turn in one call, so playing from its signals would fire the move,
	# the clear and the spawn in the same instant — the board would be silent
	# while it animated and then make every noise at once.
	_board_view.event_started.connect(_on_view_event)
	add_child(_board_view)

	# A plain Control, not an HBoxContainer. The keys are drawn by _draw from
	# their Buttons' positions, and a container does not assign those until it
	# next sorts its children — so on the frame the rack was rebuilt every
	# button still reported position zero and all six drew on top of each
	# other. Laying them out here means the positions are true immediately.
	_tool_bar = Control.new()
	_tool_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tool_bar)

	_status_label = _make_label(Color(1.9, 1.5, 0.85), 20)

	_panel = Control.new()
	_panel.set_script(ControlPanelScript)
	_panel.restart_pressed.connect(_on_restart)
	_panel.sound_toggled.connect(func(is_muted: bool) -> void: _sound.muted = is_muted)
	add_child(_panel)

	_sound = Node.new()
	_sound.set_script(SoundBankScript)
	add_child(_sound)

	resized.connect(_layout)
	_layout()


func _make_label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _layout() -> void:
	if _title == null:
		return
	var w := size.x
	var panel_height := 120.0
	# The trinkets hang ~8px below the panel's lower edge, so it cannot sit
	# flush against the bottom of the screen or they are cut in half.
	var panel_margin := 22.0
	var rack_height := _rack_height()

	var plaque_height := 112.0
	# Clear space above the plaque, so it is not jammed against the top edge.
	var top_margin := 30.0
	_title.position = Vector2(0.0, top_margin)
	_title.size = Vector2(w, plaque_height)

	# Tall enough for a badge stacked over a mascot: 38 + 76 plus the gaps.
	var duel_height := 128.0
	var duel_top := top_margin + plaque_height + 2.0

	# Tools sit ABOVE the board, matching the web version's phone layout: name,
	# duellists and progress, tools, board, controls pinned to the bottom.
	# Only the Y is known here — the rack takes its width and left edge from the
	# board, which is sized below, so it is positioned after that.
	var rack_top := duel_top + duel_height + 8.0

	# Full width: the board leaves half a cell clear either side itself (see
	# board_view.cell_size), which is more room than the frame needs and keeps
	# the clear space proportional to the board rather than a fixed 14px.
	var side_margin := 0.0
	var top := rack_top + rack_height + 12.0
	var bottom := panel_height + panel_margin + 16.0
	_board_view.star_area = Rect2(Vector2.ZERO, size)
	_board_view.position = Vector2(side_margin, top)
	_board_view.size = Vector2(w - side_margin * 2.0, maxf(0.0, size.y - top - bottom))

	# The board's real footprint, read off the board itself rather than
	# recomputed here. The duel row and the control panel are set to THIS width,
	# not the screen's, so the three stack as one column with one pair of edges
	# — and reading it rather than repeating the formula is the only way they
	# cannot drift apart when the board's sizing changes.
	var board_cell: float = _board_view.cell_size()
	var board_side := board_cell * Rules.SIZE
	var board_origin: Vector2 = _board_view.board_origin()
	var board_left := _board_view.position.x + board_origin.x

	_tool_bar.position = Vector2(board_left, rack_top)
	_tool_bar.size = Vector2(board_side, rack_height)
	_layout_rack()

	_duel.position = Vector2(board_left, duel_top)
	_duel.size = Vector2(board_side, duel_height)

	_panel.position = Vector2(board_left, size.y - panel_height - panel_margin)
	_panel.size = Vector2(board_side, panel_height)

	# Under the board, not above it. Above, it landed on the board's own frame
	# — and the space under the board was empty anyway, which is where a line
	# telling the player what the board wants should be.

	_status_label.position = Vector2(0.0, top + _board_view.size.y * 0.5 - 12.0)
	_status_label.size = Vector2(w, 24.0)


func _refresh() -> void:
	if session == null:
		return
	_title.set_lines("LEVEL %d" % (session.world_index + 1), session.world["name"])
	_prompt = session.prompt()
	queue_redraw()
	_rebuild_tools()
	if _board_view != null:
		_board_view.queue_redraw()
		_duel.queue_redraw()
		_panel.queue_redraw()


## Spreads the keys evenly across the rack's width, centred.
##
## Worlds unlock tools one at a time, so the count runs from zero to six: the
## keys shrink to fit rather than overflowing once there are six, and centring
## keeps one or two from sitting as a lopsided stub under a full-width board.
func _layout_rack() -> void:
	var keys := _tool_bar.get_child_count()
	if keys == 0:
		return
	var gap := 8.0
	var width := minf(RACK_KEY_WIDTH, (_tool_bar.size.x - gap * (keys - 1)) / float(keys))
	var total := keys * width + gap * (keys - 1)
	var x := (_tool_bar.size.x - total) * 0.5
	for i in keys:
		var button := _tool_bar.get_child(i) as Control
		button.size = Vector2(width, _rack_height())
		button.position = Vector2(x + i * (width + gap), 0.0)


## The rack's keys: a neon frame with the tool's name over its charge count.
##
## Drawn here rather than themed onto the Buttons, because a Button renders its
## label with a Font and the whole point is that this screen's text is
## PixelFont. The Buttons underneath are invisible and exist only to be tapped.
func _draw_rack() -> void:
	if session == null:
		return
	for child in _tool_bar.get_children():
		var button := child as Button
		if button == null or not button.has_meta("tool_id"):
			continue
		var id: String = button.get_meta("tool_id")
		var box := Rect2(_tool_bar.position + button.position, button.size)
		var armed := session.armed_tool == id
		var usable := session.can_use(id) or armed

		var edge := Color(1.6, 0.55, 1.15) if armed else Color(0.45, 1.5, 1.65)
		if not usable:
			edge = Color(0.30, 0.32, 0.44)
		draw_rect(box.grow(-1.0), Color(0.055, 0.075, 0.185, 0.92))
		draw_rect(box.grow(-1.0), edge, false, 2.0)

		var ink := Color(1.25, 1.35, 1.5) if usable else Color(0.42, 0.44, 0.56)
		# First word only. CRYSTAL BALL will not fit six-across on a phone, and
		# an abbreviation beats a truncation that reads as a different tool.
		var label: String = String(Tools.find_tool(id)["name"]).split(" ")[0]
		var line_h := PixelFont.height(RACK_TEXT_SCALE)
		PixelFont.draw_centered(
			self, label, box.position.x + box.size.x * 0.5, box.position.y + 6.0,
			RACK_TEXT_SCALE, ink,
		)
		PixelFont.draw_centered(
			self, str(int(session.charges.get(id, 0))),
			box.position.x + box.size.x * 0.5, box.position.y + 6.0 + line_h + 6.0,
			RACK_TEXT_SCALE, ink,
		)


func _draw_prompt() -> void:
	if _prompt.is_empty() or _board_view == null:
		return
	var scale := 2.0
	var top: float = _board_view.position.y + _board_view.cell_size() * Rules.SIZE + 18.0
	PixelFont.draw_centered(self, _prompt, size.x * 0.5, top, scale, Color(1.45, 1.02, 0.58))


## Rebuilt rather than updated in place: charges change on nearly every action,
## and six buttons is far too few for the churn to matter.
func _rebuild_tools() -> void:
	# remove_child BEFORE queue_free. queue_free is deferred to the end of the
	# frame, so freeing alone leaves the old buttons attached while the new ones
	# are added — a doubled rack for a frame, and anything reading the rack in
	# between sees stale buttons with stale charges.
	for child in _tool_bar.get_children():
		_tool_bar.remove_child(child)
		child.queue_free()

	for tool_def in Tools.TOOLS:
		if not Tools.is_unlocked(tool_def, session.world_index):
			continue
		var id: String = tool_def["id"]
		# Invisible: a hit target only. Its frame and label are drawn in _draw,
		# the same way the control panel's keys are, so every piece of text on
		# this screen goes through PixelFont rather than Godot's default sans.
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not session.can_use(id) and session.armed_tool != id
		button.tooltip_text = tool_def["description"]
		button.custom_minimum_size = Vector2(RACK_KEY_WIDTH, _rack_height())
		button.size = button.custom_minimum_size
		button.set_meta("tool_id", id)
		button.pressed.connect(_on_tool_pressed.bind(id))
		_tool_bar.add_child(button)

	_layout_rack()


## Targeted tools arm and wait for a board tap; the rest fire immediately.
## Pressing the armed tool again cancels it, which is the only way to back out
## without spending the charge — a stray board tap deliberately does not.
func _on_tool_pressed(tool_id: String) -> void:
	_sound.play(Sfx.CLICK)
	if GameSession.is_targeted(tool_id):
		if session.armed_tool == tool_id:
			session.disarm()
		else:
			session.arm(tool_id)
		_refresh()
		return
	if session.use_tool(tool_id):
		_refresh()


## A fresh attempt at the same world. Settles first so a restart mid-animation
## does not leave the old board's queue playing into the new session.
func _on_restart() -> void:
	if _board_view != null:
		_board_view.settle()
	start(world_index)


func _on_moved(path: Array[Vector2i], color: int) -> void:
	_board_view.enqueue_move(path, color)


func _on_cleared(cells: Array[Vector2i], _points: int) -> void:
	_board_view.enqueue_clear(cells)


func _on_spawned(cells: Array[Vector2i], colors: Array[int]) -> void:
	_board_view.enqueue_spawn(cells, colors)


## Taps are refused while the board is still playing back. The session has
## already resolved the turn, so a tap mid-animation would be applied to a
## board the player cannot see yet — legal, and baffling.
func _on_cell_tapped(cell: Vector2i) -> void:
	if _board_view.is_busy():
		return
	var result := session.tap(cell)
	if result == "none":
		return
	if result == "select" or result == "arm_second":
		_sound.play(Sfx.SELECT)
	elif result == "tool":
		_sound.play(Sfx.PLACE)
	_refresh()


## One sound per animation step, as it begins.
func _on_view_event(kind: String) -> void:
	match kind:
		"clear":
			_sound.play(Sfx.CLEAR)
		"spawn":
			_sound.play(Sfx.PLACE)
		"move":
			_sound.play(Sfx.SELECT)


func _on_finished(won: bool) -> void:
	if won:
		var progress := PlayerProgress.load_progress()
		progress.roll_period_if_needed()
		if progress.record_clear(session.world_index, session.score):
			progress.save()
		_sound.play(Sfx.WIN)
		_status_label.text = "THE KING HAS FALLEN"
	else:
		_sound.play(Sfx.BOO)
		_status_label.text = "NO ROOM LEFT"
	_rebuild_tools()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.058, 0.155))
	_draw_rack()
	_draw_prompt()
	# Behind everything. The board draws its own share — see board_view._draw_stars
	# — so the field skips the grid here rather than painting under a fill that
	# would hide it.
	var board_zone := Rect2(
		_board_view.position + _board_view.board_origin(),
		Vector2.ONE * _board_view.cell_size() * Rules.SIZE,
	)
	Starfield.draw_field(self, _stars, Rect2(Vector2.ZERO, size), [board_zone.grow(2.0)])
