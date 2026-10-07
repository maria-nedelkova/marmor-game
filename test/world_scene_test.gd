## The world screen and the router, end to end.
##
## The point of these is the two outward edges the session deliberately does
## not own: recording a win to PlayerProgress, and getting back to the map.
## Everything between those is GameSession's, and tested there.
extends GdUnitTestSuite

const WORLD_SCENE := preload("res://game/ui/world_scene.tscn")
const MAIN := preload("res://game/ui/main.tscn")


## Seeded per test. Without this the suite depends on whatever rng state the
## previously-run suite left behind: these tests open real sessions, so the
## opening deal — and therefore which cells are reachable — changes with it.
## It passed alone and failed in a full run, which is the worst way for a
## test to be wrong.
func before_test() -> void:
	MarmorEngine.rng = RandomNumberGenerator.new()
	MarmorEngine.rng.seed = 97531


func _world(index: int) -> Control:
	var scene: Control = WORLD_SCENE.instantiate()
	scene.world_index = index
	add_child(scene)
	scene.size = Vector2(720, 1280)
	return scene


func test_a_world_opens_with_a_live_session() -> void:
	var scene := _world(0)
	assert_object(scene.session).is_not_null()
	assert_int(scene.session.world_index).is_equal(0)
	assert_int(scene.session.phase).is_equal(GameSession.Phase.PLAYING)
	scene.queue_free()


## The rack shows exactly the tools that world has unlocked — no padlocks for
## tools that do not exist yet, and nothing missing that should be there.
func test_the_rack_matches_the_worlds_unlocks() -> void:
	for index in [0, 1, 5, Worlds.COUNT - 1]:
		var scene := _world(index)
		var rack: Control = scene._tool_bar
		assert_int(rack.get_child_count()) \
			.override_failure_message("world %d showed %d tools" % [index + 1, rack.get_child_count()]) \
			.is_equal(Tools.unlocked_at(index).size())
		scene.queue_free()


func test_tapping_a_marble_through_the_board_view_selects_it() -> void:
	var scene := _world(0)
	var board_view: Control = scene._board_view
	var occupied: Array[Vector2i] = scene.session.board.occupied_cells()
	assert_int(occupied.size()).is_greater(0)

	board_view.cell_tapped.emit(occupied[0])
	assert_bool(scene.session.has_selection()).is_true()
	assert_vector(scene.session.selected).is_equal(occupied[0])
	scene.queue_free()


## A tap must land on the cell it looks like it landed on. This is the one
## piece of geometry in the view that can be wrong without looking wrong — an
## r/c swap here would be invisible on a square board until you tried to play.
func test_a_point_maps_to_the_cell_it_is_drawn_in() -> void:
	var scene := _world(0)
	var board_view: Control = scene._board_view
	board_view.size = Vector2(720, 900)

	for r in Rules.SIZE:
		for c in Rules.SIZE:
			var cell := Board.cell(r, c)
			var round_tripped: Vector2i = board_view.cell_at(board_view.cell_center(cell))
			assert_vector(round_tripped) \
				.override_failure_message("cell %s round-tripped to %s" % [cell, round_tripped]) \
				.is_equal(cell)
	scene.queue_free()


func test_a_point_outside_the_board_maps_to_nothing() -> void:
	var scene := _world(0)
	var board_view: Control = scene._board_view
	board_view.size = Vector2(720, 900)
	assert_int(board_view.cell_at(Vector2(-50, -50)).x).is_equal(-1)
	assert_int(board_view.cell_at(Vector2(10000, 10000)).x).is_equal(-1)
	scene.queue_free()


## Winning records the score and unlocks the next world. This is the only
## writer of progress in the game, so if it is wrong nothing advances.
func test_winning_records_the_clear_and_unlocks_the_next_world() -> void:
	var save := ProjectSettings.globalize_path(PlayerProgress.SAVE_PATH)
	if FileAccess.file_exists(PlayerProgress.SAVE_PATH):
		DirAccess.remove_absolute(save)

	var scene := _world(0)
	scene.session.score = scene.session.target() + 25
	scene.session._check_finished()

	var loaded := PlayerProgress.load_progress()
	assert_int(loaded.best_for(0)).is_equal(scene.session.score)
	assert_bool(loaded.is_unlocked(1)).is_true()

	DirAccess.remove_absolute(save)
	scene.queue_free()


func test_losing_records_nothing() -> void:
	var save := ProjectSettings.globalize_path(PlayerProgress.SAVE_PATH)
	if FileAccess.file_exists(PlayerProgress.SAVE_PATH):
		DirAccess.remove_absolute(save)

	var scene := _world(0)
	scene.session.score = 40
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			scene.session.board.set_at(r, c, (r + c) % Rules.COLORS)
	scene.session._check_finished()
	assert_int(scene.session.phase).is_equal(GameSession.Phase.LOST)

	var loaded := PlayerProgress.load_progress()
	assert_int(loaded.best_for(0)).is_equal(0)
	assert_bool(loaded.is_unlocked(1)).is_false()
	scene.queue_free()


func test_the_title_asks_to_leave() -> void:
	var scene := _world(2)
	var left := [false]
	scene.exit_requested.connect(func() -> void: left[0] = true)
	scene._title.pressed.emit()
	assert_bool(left[0]).is_true()
	scene.queue_free()


# --- the router ------------------------------------------------------------


func test_the_router_opens_on_the_map_and_swaps_to_a_world_and_back() -> void:
	var main: Node = MAIN.instantiate()
	add_child(main)

	assert_object(main._current).is_not_null()
	assert_str(main._current.get_script().resource_path).is_equal("res://game/ui/level_map.gd")

	main._on_world_selected(0)
	assert_str(main._current.get_script().resource_path).is_equal("res://game/ui/world_scene.gd")
	assert_int(main._current.world_index).is_equal(0)

	main._show_map()
	assert_str(main._current.get_script().resource_path).is_equal("res://game/ui/level_map.gd")

	main.queue_free()


# --- arming through the rack -----------------------------------------------


func _rack_button(scene: Control, tool_id: String) -> Button:
	var defs := Tools.unlocked_at(scene.session.world_index)
	for i in defs.size():
		if defs[i]["id"] == tool_id:
			return scene._tool_bar.get_child(i) as Button
	return null


func test_pressing_a_targeted_tool_arms_it_rather_than_firing_it() -> void:
	var scene := _world(1)
	_rack_button(scene, Tools.HAMMER).pressed.emit()
	assert_str(scene.session.armed_tool).is_equal(Tools.HAMMER)
	# Nothing spent yet — arming is free.
	assert_int(scene.session.charges[Tools.HAMMER]).is_equal(1)
	scene.queue_free()


func test_pressing_the_armed_tool_again_cancels_it() -> void:
	var scene := _world(1)
	_rack_button(scene, Tools.HAMMER).pressed.emit()
	scene._rebuild_tools()
	_rack_button(scene, Tools.HAMMER).pressed.emit()
	assert_bool(scene.session.is_armed()).is_false()
	assert_int(scene.session.charges[Tools.HAMMER]).is_equal(1)
	scene.queue_free()


func test_a_targetless_tool_still_fires_immediately() -> void:
	var scene := _world(3)
	_rack_button(scene, Tools.REROLL).pressed.emit()
	assert_bool(scene.session.is_armed()).is_false()
	assert_int(scene.session.charges[Tools.REROLL]).is_equal(0)
	scene.queue_free()


func test_arming_then_tapping_the_board_uses_the_tool() -> void:
	var scene := _world(1)
	var occupied: Array[Vector2i] = scene.session.board.occupied_cells()
	var before: int = scene.session.board.marble_count()

	_rack_button(scene, Tools.HAMMER).pressed.emit()
	scene._board_view.cell_tapped.emit(occupied[0])

	assert_int(scene.session.board.marble_count()).is_equal(before - 1)
	assert_bool(scene.session.is_armed()).is_false()
	assert_int(scene.session.charges[Tools.HAMMER]).is_equal(0)
	scene.queue_free()


## The prompt is what tells the player the board is waiting for something, so
## it has to appear and clear with the armed state.
func test_the_prompt_appears_while_armed_and_clears_after() -> void:
	var scene := _world(1)
	assert_str(scene._prompt).is_empty()

	_rack_button(scene, Tools.HAMMER).pressed.emit()
	assert_str(scene._prompt).is_not_empty()

	var occupied: Array[Vector2i] = scene.session.board.occupied_cells()
	scene._board_view.cell_tapped.emit(occupied[0])
	assert_str(scene._prompt).is_empty()
	scene.queue_free()


## A spent tool must not stay selectable just because it was armed.
func test_a_tool_with_no_charges_left_cannot_be_rearmed() -> void:
	var scene := _world(1)
	var occupied: Array[Vector2i] = scene.session.board.occupied_cells()
	_rack_button(scene, Tools.HAMMER).pressed.emit()
	scene._board_view.cell_tapped.emit(occupied[0])
	scene._refresh()

	_rack_button(scene, Tools.HAMMER).pressed.emit()
	assert_bool(scene.session.is_armed()).is_false()
	assert_bool(_rack_button(scene, Tools.HAMMER).disabled).is_true()
	scene.queue_free()


# --- animation -------------------------------------------------------------


## The display board lagging the session board is the entire mechanism. If it
## ever stops lagging, the animation silently becomes a jump cut.
func test_the_display_lags_the_session_until_playback_runs() -> void:
	var scene := _world(0)
	var view: Control = scene._board_view
	var occupied: Array[Vector2i] = scene.session.board.occupied_cells()

	var from: Vector2i = occupied[0]
	var to := Vector2i(-1, -1)
	for candidate in scene.session.board.empty_cells():
		if not MarmorEngine.find_path(scene.session.board, from, candidate).is_empty():
			to = candidate
			break
	assert_int(to.x).is_not_equal(-1)

	scene.session.tap(from)
	scene.session.tap(to)

	# The session has already finished the turn...
	assert_bool(scene.session.board.is_empty_at(from.x, from.y)).is_true()
	# ...while the view has not started drawing it.
	assert_bool(view.is_busy()).is_true()
	assert_bool(view._display.is_empty_at(from.x, from.y)).is_false()

	view.settle()
	assert_bool(view.is_busy()).is_false()
	assert_bool(view._display.is_empty_at(from.x, from.y)).is_true()
	scene.queue_free()


## After playback the two boards must agree exactly. A drift here would show as
## marbles that are drawn but cannot be tapped, or the reverse.
func test_settling_leaves_the_display_identical_to_the_session() -> void:
	var scene := _world(0)
	var view: Control = scene._board_view

	for _turn in 6:
		var occupied: Array[Vector2i] = scene.session.board.occupied_cells()
		if occupied.is_empty():
			break
		var from: Vector2i = occupied[0]
		var moved := false
		for candidate in scene.session.board.empty_cells():
			if not MarmorEngine.find_path(scene.session.board, from, candidate).is_empty():
				scene.session.tap(from)
				scene.session.tap(candidate)
				moved = true
				break
		if not moved:
			break
		view.settle()

		for r in Rules.SIZE:
			for c in Rules.SIZE:
				assert_int(view._display.at(r, c)) \
					.override_failure_message("display and session differ at (%d,%d)" % [r, c]) \
					.is_equal(scene.session.board.at(r, c))
	scene.queue_free()


## A tap during playback would be applied to a board the player cannot see yet.
func test_taps_are_refused_while_the_board_is_playing_back() -> void:
	var scene := _world(0)
	var view: Control = scene._board_view
	var occupied: Array[Vector2i] = scene.session.board.occupied_cells()

	var from: Vector2i = occupied[0]
	for candidate in scene.session.board.empty_cells():
		if not MarmorEngine.find_path(scene.session.board, from, candidate).is_empty():
			scene.session.tap(from)
			scene.session.tap(candidate)
			break
	assert_bool(view.is_busy()).is_true()

	var others: Array[Vector2i] = scene.session.board.occupied_cells()
	scene._on_cell_tapped(others[0])
	assert_bool(scene.session.has_selection()).is_false()

	view.settle()
	scene._on_cell_tapped(others[0])
	assert_bool(scene.session.has_selection()).is_true()
	scene.queue_free()


## Leaving mid-turn must not strand the board part-way through a queue.
func test_leaving_settles_the_board_first() -> void:
	var scene := _world(0)
	var view: Control = scene._board_view
	var occupied: Array[Vector2i] = scene.session.board.occupied_cells()
	for candidate in scene.session.board.empty_cells():
		if not MarmorEngine.find_path(scene.session.board, occupied[0], candidate).is_empty():
			scene.session.tap(occupied[0])
			scene.session.tap(candidate)
			break
	assert_bool(view.is_busy()).is_true()

	scene._title.pressed.emit()
	assert_bool(view.is_busy()).is_false()
	scene.queue_free()


## A clear enqueues after the move that caused it, so the marble has to arrive
## before the line goes. Out of order, a line would vanish before the marble
## completing it was seen to land.
func test_a_move_that_clears_queues_the_move_before_the_clear() -> void:
	var scene := _world(0)
	var view: Control = scene._board_view
	var session: GameSession = scene.session
	for p in session.board.occupied_cells():
		session.board.clear_at(p.x, p.y)
	view.set_session(session)

	for c in [2, 3, 4, 5]:
		session.board.set_at(4, c, 1)
	session.board.set_at(0, 0, 1)

	session.tap(Board.cell(0, 0))
	session.tap(Board.cell(4, 6))

	var kinds: Array[String] = []
	for event in view._events:
		kinds.append(event["type"])
	assert_array(kinds).is_equal(["move", "clear"])
	scene.queue_free()


## The opening deal is adopted, not animated — there is nothing on an empty
## board for a spawn animation to contrast against, and the player has not
## acted yet.
func test_the_opening_deal_is_not_animated() -> void:
	var scene := _world(0)
	assert_bool(scene._board_view.is_busy()).is_false()
	assert_int(scene._board_view._display.marble_count()).is_equal(scene.session.board.marble_count())
	scene.queue_free()


## is_busy has to count the event currently playing, not just the ones still
## queued. Tests never run frames, so _current is normally always empty and the
## distinction never arises — but while the LAST event plays, _events is empty
## and only _current says the board is still moving. Missing that would accept
## taps during the final clear of a turn.
##
## _process is driven by hand here for that reason. Verified by mutation.
func test_the_board_is_busy_while_the_last_event_is_still_playing() -> void:
	var scene := _world(0)
	var view: Control = scene._board_view
	view.set_session(scene.session)

	view.enqueue_clear([Board.cell(0, 0)] as Array[Vector2i])
	assert_bool(view.is_busy()).is_true()

	# Pulls the event out of the queue and into flight without finishing it.
	view._process(0.001)
	assert_array(view._events).is_empty()
	assert_bool(view._current.is_empty()).is_false()
	assert_bool(view.is_busy()) \
		.override_failure_message("busy went false while an event was still in flight") \
		.is_true()

	# And taps are still refused at that point.
	var occupied: Array[Vector2i] = scene.session.board.occupied_cells()
	scene._on_cell_tapped(occupied[0])
	assert_bool(scene.session.has_selection()).is_false()

	# Running past the duration finishes it and releases the board.
	view._process(1.0)
	assert_bool(view.is_busy()).is_false()
	scene.queue_free()


## The glide itself: a marble part-way through a move must be drawn BETWEEN
## cell centres, and must travel at a constant rate rather than speeding up or
## stalling at corners.
##
## Asserted rather than eyeballed, because a screenshot of a glide is a poor
## witness — at 0.45 of a ten-cell path the marble sits almost exactly on a
## cell centre and the frame looks static whether the glide works or not.
func test_a_gliding_marble_is_drawn_between_cells() -> void:
	var scene := _world(0)
	var view: Control = scene._board_view
	view.size = Vector2(720, 900)

	var path: Array[Vector2i] = []
	for c in 9:
		path.append(Board.cell(0, c))
	view._current = {"type": "move", "path": path, "color": 1}

	var start: Vector2 = view.cell_center(path[0])
	var finish: Vector2 = view.cell_center(path[path.size() - 1])

	assert_vector(view._moving_position(0.0)).is_equal_approx(start, Vector2(0.5, 0.5))
	assert_vector(view._moving_position(1.0)).is_equal_approx(finish, Vector2(0.5, 0.5))

	# Half way along must be half way across, and must not coincide with the
	# cell centre it passes closest to by accident.
	var middle: Vector2 = view._moving_position(0.5)
	assert_vector(middle).is_equal_approx(start.lerp(finish, 0.5), Vector2(0.5, 0.5))

	# Constant rate: equal steps in progress cover equal distance.
	var previous: Vector2 = start
	var first_step := 0.0
	for i in range(1, 11):
		var at: Vector2 = view._moving_position(i / 10.0)
		var step := previous.distance_to(at)
		if i == 1:
			first_step = step
		else:
			assert_float(step) \
				.override_failure_message("step %d was %f against a first step of %f" % [i, step, first_step]) \
				.is_equal_approx(first_step, 0.5)
		previous = at
	scene.queue_free()


## A one-cell move has no span to interpolate across, which is exactly where an
## index-out-of-range or a divide-by-zero would live.
func test_a_single_cell_path_does_not_break_the_glide() -> void:
	var scene := _world(0)
	var view: Control = scene._board_view
	view.size = Vector2(720, 900)
	view._current = {"type": "move", "path": [Board.cell(3, 3)] as Array[Vector2i], "color": 1}
	assert_vector(view._moving_position(0.0)).is_equal(view.cell_center(Board.cell(3, 3)))
	assert_vector(view._moving_position(1.0)).is_equal(view.cell_center(Board.cell(3, 3)))
	scene.queue_free()


# --- sound ------------------------------------------------------------------


## Sound follows the VIEW, not the session. The session resolves a whole turn in
## one call, so playing from its signals would fire the move, the clear and the
## spawn in the same instant — the board would be silent while it animated and
## then make every noise at once.
func test_each_animation_step_announces_itself() -> void:
	var scene := _world(0)
	var view: Control = scene._board_view
	var session: GameSession = scene.session

	var occupied: Array[Vector2i] = session.board.occupied_cells()
	var moved := false
	for to in session.board.empty_cells():
		if not MarmorEngine.find_path(session.board, occupied[0], to).is_empty():
			session.tap(occupied[0])
			session.tap(to)
			moved = true
			break
	assert_bool(moved).is_true()

	var kinds: Array[String] = []
	view.event_started.connect(func(kind: String) -> void: kinds.append(kind))
	for _i in 400:
		view._process(0.05)
		if not view.is_busy():
			break

	assert_array(kinds).override_failure_message("no steps announced").is_not_empty()
	assert_bool(kinds.has("move")).override_failure_message("the move was silent").is_true()
	scene.queue_free()


func test_the_scene_owns_a_sound_bank_with_voices() -> void:
	var scene := _world(0)
	assert_object(scene._sound).is_not_null()
	assert_int(scene._sound._players.size()).is_equal(8)
	assert_bool(scene._sound.muted).is_false()
	scene.queue_free()


## Muting has to stop what is already sounding, not merely skip new effects —
## otherwise the tail of a clear keeps playing after the player hits mute.
func test_muting_stops_what_is_already_playing() -> void:
	var scene := _world(0)
	var bank: Node = scene._sound
	bank.play(Sfx.CLEAR)
	bank.muted = true
	for player in bank._players:
		assert_bool(player.playing).is_false()
	scene.queue_free()


func test_a_muted_bank_plays_nothing() -> void:
	var scene := _world(0)
	var bank: Node = scene._sound
	bank.muted = true
	bank.play(Sfx.SELECT)
	for player in bank._players:
		assert_bool(player.playing).is_false()
	scene.queue_free()


## The panel's sound key is the only way to reach the mute, so the wiring from
## it has to hold.
func test_the_sound_key_mutes_the_bank() -> void:
	var scene := _world(0)
	scene._panel.sound_toggled.emit(true)
	assert_bool(scene._sound.muted).is_true()
	scene._panel.sound_toggled.emit(false)
	assert_bool(scene._sound.muted).is_false()
	scene.queue_free()
