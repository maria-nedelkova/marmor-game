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

var session: GameSession
var world_index: int = 0

var _board_view: Control
var _duel: Control
var _panel: Control
var _title: Control
var _prompt_label: Label
var _status_label: Label
var _tool_bar: HBoxContainer
var _stars: Array[Dictionary] = []


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
	_stars = Starfield.build(8080, 150, 7, 5)

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
	_board_view.cell_tapped.connect(_on_cell_tapped)
	_board_view.animation_finished.connect(_refresh)
	add_child(_board_view)

	_tool_bar = HBoxContainer.new()
	_tool_bar.add_theme_constant_override("separation", 6)
	# Centred in the board's width. Left-aligned, a world with two tools left a
	# lopsided stub under a full-width board.
	_tool_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_tool_bar)

	_prompt_label = _make_label(Color(1.45, 1.02, 0.58), 13)
	_status_label = _make_label(Color(1.9, 1.5, 0.85), 20)

	_panel = Control.new()
	_panel.set_script(ControlPanelScript)
	_panel.restart_pressed.connect(_on_restart)
	add_child(_panel)

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
	var panel_height := 96.0
	# The trinkets hang ~8px below the panel's lower edge, so it cannot sit
	# flush against the bottom of the screen or they are cut in half.
	var panel_margin := 22.0
	var rack_height := 42.0

	var plaque_height := 112.0
	_title.position = Vector2(0.0, 6.0)
	_title.size = Vector2(w, plaque_height)

	# Tall enough for a badge stacked over a mascot: 38 + 76 plus the gaps.
	var duel_height := 128.0
	var duel_top := 6.0 + plaque_height + 2.0

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

	_duel.position = Vector2(board_left, duel_top)
	_duel.size = Vector2(board_side, duel_height)

	_panel.position = Vector2(board_left, size.y - panel_height - panel_margin)
	_panel.size = Vector2(board_side, panel_height)

	# Under the board, not above it. Above, it landed on the board's own frame
	# — and the space under the board was empty anyway, which is where a line
	# telling the player what the board wants should be.
	_prompt_label.position = Vector2(0.0, top + board_side + 18.0)
	_prompt_label.size = Vector2(w, 20.0)

	_status_label.position = Vector2(0.0, top + _board_view.size.y * 0.5 - 12.0)
	_status_label.size = Vector2(w, 24.0)


func _refresh() -> void:
	if session == null:
		return
	_title.set_lines("LEVEL %d" % (session.world_index + 1), session.world["name"])
	_prompt_label.text = session.prompt()
	_rebuild_tools()
	if _board_view != null:
		_board_view.queue_redraw()
		_duel.queue_redraw()
		_panel.queue_redraw()


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
		var button := Button.new()
		button.text = "%s %d" % [tool_def["name"], int(session.charges.get(id, 0))]
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not session.can_use(id) and session.armed_tool != id
		button.toggle_mode = true
		button.button_pressed = session.armed_tool == id
		button.tooltip_text = tool_def["description"]
		button.add_theme_font_size_override("font_size", 11)
		_style_key(button, session.armed_tool == id)
		button.pressed.connect(_on_tool_pressed.bind(id))
		_tool_bar.add_child(button)


## The rack's neon key look, applied to every state a Button has. Godot falls
## back to its default grey theme for any state left unset, so a key that looks
## right at rest turns into a stock button the moment it is hovered or held —
## all five have to be given, not just `normal`.
func _style_key(button: Button, armed: bool) -> void:
	var edge := Color(1.6, 0.55, 1.15) if armed else Color(0.45, 1.5, 1.65)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.06, 0.08, 0.19, 0.92)
		box.set_border_width_all(2)
		box.border_color = edge
		box.set_corner_radius_all(7)
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		if state == "pressed" or state == "hover":
			box.bg_color = Color(0.12, 0.14, 0.30, 0.95)
		if state == "disabled":
			box.border_color = Color(0.30, 0.32, 0.44)
			box.bg_color = Color(0.05, 0.05, 0.11, 0.85)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color(1.25, 1.35, 1.5))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.44, 0.56))
	button.add_theme_color_override("font_hover_color", Color(1.5, 1.55, 1.7))
	button.add_theme_color_override("font_pressed_color", Color(1.5, 1.55, 1.7))


## Targeted tools arm and wait for a board tap; the rest fire immediately.
## Pressing the armed tool again cancels it, which is the only way to back out
## without spending the charge — a stray board tap deliberately does not.
func _on_tool_pressed(tool_id: String) -> void:
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
	if session.tap(cell) != "none":
		_refresh()


func _on_finished(won: bool) -> void:
	if won:
		var progress := PlayerProgress.load_progress()
		progress.roll_period_if_needed()
		if progress.record_clear(session.world_index, session.score):
			progress.save()
		_status_label.text = "THE KING HAS FALLEN"
	else:
		_status_label.text = "NO ROOM LEFT"
	_rebuild_tools()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.058, 0.155))
	# Behind everything, and kept off the board — a star showing through the
	# grid would be taken for a marble.
	var board_zone := Rect2(_board_view.position, _board_view.size)
	Starfield.draw_field(self, _stars, Rect2(Vector2.ZERO, size), [board_zone.grow(6.0)])
