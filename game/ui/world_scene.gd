## Playing one world: the board, the score against the King's target, the
## queue, the tool rack, and what happens when the attempt ends.
##
## Holds a GameSession and renders it. The session owns every rule; this owns
## only presentation and the two outward edges — recording a win to
## PlayerProgress, and going back to the map.
extends Control

signal exit_requested

const BoardViewScript := preload("res://game/ui/board_view.gd")

var session: GameSession
var world_index: int = 0

var _board_view: Control
var _title: Button
var _score_label: Label
var _queue_label: Label
var _status_label: Label
var _prompt_label: Label
var _tool_bar: HBoxContainer


func _ready() -> void:
	_build()
	start(world_index)


func start(index: int) -> void:
	world_index = index
	session = GameSession.new(index)
	# Events are queued on the view rather than drawn immediately: the session
	# resolves a whole turn in one call, so these all arrive before the first
	# frame of animation. See board_view.gd on why it keeps its own board.
	session.marble_moved.connect(_on_moved)
	session.cells_cleared.connect(_on_cleared)
	session.marbles_spawned.connect(_on_spawned)
	session.score_changed.connect(_refresh)
	session.queue_changed.connect(func(_colors: Array[int]) -> void: _refresh())
	session.armed_changed.connect(func(_id: String) -> void: _refresh())
	session.finished.connect(_on_finished)
	if _board_view != null:
		_board_view.set_session(session)
	_refresh()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# The game name is the way back to the map — the same affordance as on the
	# web version, where tapping the title returns you there.
	_title = Button.new()
	_title.text = "MARMOR"
	_title.flat = true
	_title.focus_mode = Control.FOCUS_NONE
	_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.95))
	_title.add_theme_font_size_override("font_size", 26)
	_title.tooltip_text = "Back to the map"
	_title.pressed.connect(func() -> void:
		if _board_view != null:
			_board_view.settle()
		exit_requested.emit())
	add_child(_title)

	_score_label = _make_label(Color(0.92, 0.95, 1.0), 18)
	_queue_label = _make_label(Color(0.62, 0.72, 0.92), 14)
	_status_label = _make_label(Color(1.0, 0.85, 0.55), 20)
	# Reserved whether or not a tool is armed, so arming one does not shove the
	# board up a line.
	_prompt_label = _make_label(Color(0.98, 0.72, 0.42), 14)

	_board_view = Control.new()
	_board_view.set_script(BoardViewScript)
	_board_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_board_view.cell_tapped.connect(_on_cell_tapped)
	_board_view.animation_finished.connect(_refresh)
	add_child(_board_view)

	_tool_bar = HBoxContainer.new()
	_tool_bar.add_theme_constant_override("separation", 6)
	add_child(_tool_bar)

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
	var w := size.x
	_title.position = Vector2(0.0, 8.0)
	_title.size = Vector2(w, 34.0)
	_score_label.position = Vector2(0.0, 46.0)
	_score_label.size = Vector2(w, 24.0)
	_queue_label.position = Vector2(0.0, 72.0)
	_queue_label.size = Vector2(w, 20.0)
	_prompt_label.position = Vector2(0.0, size.y - 92.0)
	_prompt_label.size = Vector2(w, 20.0)

	# The board takes the square middle; the rack sits under it.
	var top := 100.0
	var rack_height := 54.0
	var available := Vector2(w, maxf(0.0, size.y - top - rack_height - 16.0))
	_board_view.position = Vector2(0.0, top)
	_board_view.size = available

	_status_label.position = Vector2(0.0, top + available.y * 0.5 - 12.0)
	_status_label.size = Vector2(w, 24.0)

	_tool_bar.position = Vector2(12.0, size.y - rack_height - 8.0)
	_tool_bar.size = Vector2(w - 24.0, rack_height)


func _refresh() -> void:
	if session == null:
		return
	var world := session.world
	_score_label.text = "%s     %d / %d" % [world["name"], session.score, session.target()]

	var names: Array[String] = []
	for color in session.next_queue:
		names.append(str(color))
	_queue_label.text = "next up:  %s" % ", ".join(names)

	_prompt_label.text = session.prompt()
	queue_redraw()
	_rebuild_tools()
	if _board_view != null:
		_board_view.queue_redraw()


## Rebuilt rather than updated in place: charges change on nearly every action,
## and six buttons is far too few for the churn to matter.
func _rebuild_tools() -> void:
	# remove_child BEFORE queue_free. queue_free is deferred to the end of the
	# frame, so freeing alone leaves the old buttons attached while the new ones
	# are added — a doubled rack for a frame, and anything reading the rack in
	# between (a test, or a second refresh in the same frame) sees stale
	# buttons with stale charges on them.
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
		button.pressed.connect(_on_tool_pressed.bind(id))
		_tool_bar.add_child(button)


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


func _on_moved(path: Array[Vector2i], color: int) -> void:
	_board_view.enqueue_move(path, color)


func _on_cleared(cells: Array[Vector2i], _points: int) -> void:
	_board_view.enqueue_clear(cells)


func _on_spawned(cells: Array[Vector2i], colors: Array[int]) -> void:
	_board_view.enqueue_spawn(cells, colors)


## Taps are refused while the board is still playing back. The session has
## already resolved the turn, so a tap during the animation would be applied to
## a board the player cannot see yet — legal, and baffling.
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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.027, 0.08))
	if session == null:
		return

	# The king you are actually fighting, beside the score he set. "Each world
	# is a new king" is the premise, and it only lands if he is on screen while
	# you play rather than only on the map you picked him from.
	var texture := Kings.texture_for(session.world["id"])
	if texture == null:
		return
	var box := Rect2(Vector2(size.x * 0.5 + 118.0, 38.0), Vector2(48.0, 48.0))
	var tint := Color.WHITE
	if session.phase == GameSession.Phase.WON:
		# Dethroned: drained of colour, so the header reflects the outcome.
		tint = Color(0.45, 0.45, 0.52, 0.8)
	PixelSprite.draw_scaled(self, texture, box, tint)
