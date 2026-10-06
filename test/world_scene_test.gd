## The world screen and the router, end to end.
##
## The point of these is the two outward edges the session deliberately does
## not own: recording a win to PlayerProgress, and getting back to the map.
## Everything between those is GameSession's, and tested there.
extends GdUnitTestSuite

const WORLD_SCENE := preload("res://game/ui/world_scene.tscn")
const MAIN := preload("res://game/ui/main.tscn")


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
		var rack: HBoxContainer = scene._tool_bar
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
