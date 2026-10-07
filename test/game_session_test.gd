## The turn loop.
##
## These pin the sequencing rules that make the game what it is — a clearing
## move buys a free turn, a tool that does nothing costs nothing, winning beats
## losing on the same move — rather than the tuning, which lives in worlds.gd
## and is free to change.
extends GdUnitTestSuite


func before_test() -> void:
	MarmorEngine.rng = RandomNumberGenerator.new()
	MarmorEngine.rng.seed = 13579


## A session with a board we control. Sessions deal an opening board in
## _init, so tests that care about specific cells wipe it first.
func _empty_session(world_index: int = 0) -> GameSession:
	var s := GameSession.new(world_index)
	for p in s.board.occupied_cells():
		s.board.clear_at(p.x, p.y)
	return s


func _place(s: GameSession, cells: Array, color: int) -> void:
	for rc in cells:
		s.board.set_at(rc[0], rc[1], color)


# --- opening -----------------------------------------------------------------


func test_a_new_session_deals_the_worlds_opening_board() -> void:
	for i in Worlds.COUNT:
		var s := GameSession.new(i)
		assert_int(s.board.marble_count()) \
			.override_failure_message("world %d dealt the wrong opening" % (i + 1)) \
			.is_equal(int(Worlds.get_world(i)["start_count"]))
		assert_int(s.score).is_equal(0)
		assert_int(s.phase).is_equal(GameSession.Phase.PLAYING)


func test_the_queue_is_filled_to_the_worlds_preview_count() -> void:
	for i in Worlds.COUNT:
		var s := GameSession.new(i)
		assert_int(s.next_queue.size()).is_equal(int(Worlds.get_world(i)["preview_count"]))


func test_a_new_session_arrives_with_the_worlds_charges() -> void:
	var s := GameSession.new(3)
	assert_dict(s.charges).is_equal(Tools.grant_charges(Tools.no_charges(), 3))


func test_the_world_index_is_clamped() -> void:
	assert_int(GameSession.new(-5).world_index).is_equal(0)
	assert_int(GameSession.new(999).world_index).is_equal(Worlds.COUNT - 1)


# --- selection and movement --------------------------------------------------


func test_tapping_a_marble_selects_it_and_tapping_it_again_deselects() -> void:
	var s := _empty_session()
	_place(s, [[4, 4]], 1)
	assert_str(s.tap(Board.cell(4, 4))).is_equal("select")
	assert_bool(s.has_selection()).is_true()
	assert_str(s.tap(Board.cell(4, 4))).is_equal("deselect")
	assert_bool(s.has_selection()).is_false()


## A misdirected tap should not cost two more taps to undo.
func test_tapping_another_marble_moves_the_selection() -> void:
	var s := _empty_session()
	_place(s, [[4, 4], [2, 2]], 1)
	s.tap(Board.cell(4, 4))
	assert_str(s.tap(Board.cell(2, 2))).is_equal("select")
	assert_vector(s.selected).is_equal(Board.cell(2, 2))


func test_tapping_empty_space_with_nothing_selected_does_nothing() -> void:
	var s := _empty_session()
	assert_str(s.tap(Board.cell(0, 0))).is_equal("none")


func test_a_move_relocates_the_marble() -> void:
	var s := _empty_session()
	_place(s, [[0, 0]], 3)
	s.tap(Board.cell(0, 0))
	assert_str(s.tap(Board.cell(5, 5))).is_equal("move")
	assert_bool(s.board.is_empty_at(0, 0)).is_true()
	assert_int(s.board.at(5, 5)).is_equal(3)


func test_an_unreachable_destination_is_refused_and_keeps_the_selection() -> void:
	var s := _empty_session()
	_place(s, [[0, 0]], 3)
	for r in Rules.SIZE:
		s.board.set_at(r, 1, 5)
	s.tap(Board.cell(0, 0))
	assert_str(s.tap(Board.cell(5, 5))).is_equal("none")
	assert_int(s.board.at(0, 0)).is_equal(3)
	assert_bool(s.has_selection()).is_true()


# --- clearing and scoring ----------------------------------------------------


func test_completing_a_line_clears_and_scores_it() -> void:
	var s := _empty_session()
	_place(s, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
	_place(s, [[0, 0]], 1)
	s.tap(Board.cell(0, 0))
	s.tap(Board.cell(4, 6))

	assert_int(s.board.marble_count()).is_equal(0)
	assert_int(s.score).is_equal(s.score_for(5))


func test_the_score_is_scaled_by_the_worlds_multiplier() -> void:
	# Same five-marble line, two worlds, scores in the ratio of the multipliers.
	var base := GameSession.new(0).score_for(5)
	var deep := GameSession.new(7).score_for(5)
	assert_int(base).is_equal(MarmorEngine.score_for_clear(5))
	assert_int(deep).is_equal(MarmorEngine.score_for_clear(5) * int(Worlds.get_world(7)["multiplier"]))
	assert_int(deep).is_greater(base)


## The free turn. This is the single largest advantage the player has, and the
## final world is the one that takes it away.
func test_a_clearing_move_spawns_nothing_except_in_the_final_world() -> void:
	var s := _empty_session(0)
	_place(s, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
	_place(s, [[0, 0]], 1)
	s.tap(Board.cell(0, 0))
	s.tap(Board.cell(4, 6))
	assert_int(s.board.marble_count()).is_equal(0)

	var final_world := _empty_session(Worlds.COUNT - 1)
	assert_bool(bool(final_world.world["spawn_on_clear"])).is_true()
	_place(final_world, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
	_place(final_world, [[0, 0]], 1)
	final_world.tap(Board.cell(0, 0))
	final_world.tap(Board.cell(4, 6))
	assert_int(final_world.board.marble_count()).is_greater(0)


func test_a_non_clearing_move_spawns_the_worlds_count() -> void:
	var s := _empty_session(0)
	_place(s, [[0, 0]], 3)
	s.tap(Board.cell(0, 0))
	s.tap(Board.cell(8, 8))
	# The moved marble plus the spawn.
	assert_int(s.board.marble_count()).is_equal(1 + int(s.world["spawn_count"]))


func test_the_queue_refreshes_after_a_spawn_but_not_on_the_opening_deal() -> void:
	var s := _empty_session(0)
	var before := s.next_queue.duplicate()
	_place(s, [[0, 0]], 3)
	s.tap(Board.cell(0, 0))
	s.tap(Board.cell(8, 8))
	assert_int(s.next_queue.size()).is_equal(before.size())


# --- finishing ---------------------------------------------------------------


func test_reaching_the_target_wins() -> void:
	var s := _empty_session()
	s.score = s.target() - 1
	_place(s, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
	_place(s, [[0, 0]], 1)
	s.tap(Board.cell(0, 0))
	s.tap(Board.cell(4, 6))
	assert_int(s.phase).is_equal(GameSession.Phase.WON)


func test_a_full_board_loses() -> void:
	var s := _empty_session()
	# One free cell, and a marble that cannot make a line when it fills it.
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			s.board.set_at(r, c, (r + c) % Rules.COLORS)
	s.board.clear_at(8, 8)
	s.board.clear_at(0, 0)
	s.tap(Board.cell(0, 1))
	s.tap(Board.cell(0, 0))
	assert_int(s.phase).is_equal(GameSession.Phase.LOST)


## A state that both reaches the target and fills the board is a WIN. The
## player met the King's score; the board running out afterwards is a
## technicality.
##
## Asserted directly on the finishing check rather than through a contrived
## move. The earlier version wrapped the assertion in "if the score happened
## to reach the target", which meant it passed without checking anything when
## the setup did not land there — and it did not catch the order being
## flipped. Verified by mutation now.
func test_winning_beats_losing_when_both_are_true() -> void:
	var s := _empty_session()
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			s.board.set_at(r, c, (r + c) % Rules.COLORS)
	s.score = s.target()

	assert_bool(s.board.empty_cells().is_empty()).is_true()
	assert_int(s.score).is_greater_equal(s.target())

	var outcomes: Array = []
	s.finished.connect(func(won: bool) -> void: outcomes.append(won))
	s._check_finished()

	assert_int(s.phase).is_equal(GameSession.Phase.WON)
	assert_array(outcomes).is_equal([true])


## And the other way: a full board with the target unmet is a loss.
func test_a_full_board_below_the_target_loses() -> void:
	var s := _empty_session()
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			s.board.set_at(r, c, (r + c) % Rules.COLORS)
	s.score = s.target() - 1

	var outcomes: Array = []
	s.finished.connect(func(won: bool) -> void: outcomes.append(won))
	s._check_finished()

	assert_int(s.phase).is_equal(GameSession.Phase.LOST)
	assert_array(outcomes).is_equal([false])


func test_a_finished_session_ignores_further_taps() -> void:
	var s := _empty_session()
	s.phase = GameSession.Phase.WON
	_place(s, [[4, 4]], 1)
	assert_str(s.tap(Board.cell(4, 4))).is_equal("none")


# --- tools -------------------------------------------------------------------


func test_a_locked_tool_cannot_be_used() -> void:
	var s := _empty_session(0)
	assert_bool(s.can_use(Tools.HAMMER)).is_false()
	assert_bool(s.can_use(Tools.BOMB)).is_false()


func test_an_unlocked_tool_with_a_charge_can_be_used() -> void:
	var s := _empty_session(1)
	assert_bool(s.can_use(Tools.HAMMER)).is_true()


func test_the_hammer_removes_a_marble_and_spends_a_charge() -> void:
	var s := _empty_session(1)
	_place(s, [[3, 3]], 2)
	assert_bool(s.use_tool_at(Tools.HAMMER, Board.cell(3, 3))).is_true()
	assert_bool(s.board.is_empty_at(3, 3)).is_true()
	assert_int(s.charges[Tools.HAMMER]).is_equal(0)


## The whole reason the board operations report success: a tool that did
## nothing must not cost a charge.
func test_a_tool_that_does_nothing_costs_nothing() -> void:
	var s := _empty_session(1)
	var before: int = s.charges[Tools.HAMMER]
	assert_bool(s.use_tool_at(Tools.HAMMER, Board.cell(0, 0))).is_false()
	assert_int(s.charges[Tools.HAMMER]).is_equal(before)

	var pouch := _empty_session(4)
	_place(pouch, [[0, 0], [1, 1], [2, 2]], 3)  # monochrome: nothing to stir
	var pouch_before: int = pouch.charges[Tools.SHUFFLE]
	assert_bool(pouch.use_tool(Tools.SHUFFLE)).is_false()
	assert_int(pouch.charges[Tools.SHUFFLE]).is_equal(pouch_before)


func test_a_tool_cannot_be_used_without_a_charge() -> void:
	var s := _empty_session(1)
	_place(s, [[3, 3], [4, 4]], 2)
	assert_bool(s.use_tool_at(Tools.HAMMER, Board.cell(3, 3))).is_true()
	assert_bool(s.can_use(Tools.HAMMER)).is_false()
	assert_bool(s.use_tool_at(Tools.HAMMER, Board.cell(4, 4))).is_false()
	assert_int(s.board.at(4, 4)).is_equal(2)


func test_the_bomb_clears_a_patch() -> void:
	var s := _empty_session(5)
	for r in range(3, 6):
		for c in range(3, 6):
			s.board.set_at(r, c, 1)
	assert_bool(s.use_tool_at(Tools.BOMB, Board.cell(4, 4))).is_true()
	assert_int(s.board.marble_count()).is_equal(0)


func test_the_dice_rerolls_the_queue() -> void:
	var s := _empty_session(3)
	var before: int = s.charges[Tools.REROLL]
	assert_bool(s.use_tool(Tools.REROLL)).is_true()
	assert_int(s.charges[Tools.REROLL]).is_equal(before - 1)
	assert_int(s.next_queue.size()).is_equal(int(s.world["preview_count"]))


## A tool can complete a line anywhere, not at a cell the session knows about,
## so the sweep after a tool has to cover the whole board.
func test_a_line_completed_by_a_tool_still_clears_and_scores() -> void:
	var s := _empty_session(2)
	_place(s, [[4, 0], [4, 1], [4, 2], [4, 3]], 1)
	_place(s, [[4, 4]], 6)
	_place(s, [[0, 0]], 1)
	assert_bool(s.use_tool_at(Tools.SWAP, Board.cell(4, 4), Board.cell(0, 0))).is_true()
	assert_int(s.score).is_equal(s.score_for(5))
	assert_bool(s.board.is_empty_at(4, 4)).is_true()


func test_an_unknown_tool_id_is_refused() -> void:
	var s := _empty_session(5)
	assert_bool(s.can_use("teleporter")).is_false()
	assert_bool(s.use_tool("teleporter")).is_false()
	assert_bool(s.use_tool_at("teleporter", Board.cell(0, 0))).is_false()


# --- signals -----------------------------------------------------------------


func test_a_move_reports_itself() -> void:
	var s := _empty_session()
	_place(s, [[0, 0]], 3)
	var seen: Array = []
	s.marble_moved.connect(func(path: Array[Vector2i], color: int) -> void: seen.append([path, color]))
	s.tap(Board.cell(0, 0))
	s.tap(Board.cell(0, 4))
	assert_int(seen.size()).is_equal(1)
	assert_int(seen[0][1]).is_equal(3)
	assert_vector(seen[0][0][0]).is_equal(Board.cell(0, 0))


func test_finishing_reports_the_outcome_once() -> void:
	var s := _empty_session()
	s.score = s.target() - 1
	var outcomes: Array = []
	s.finished.connect(func(won: bool) -> void: outcomes.append(won))
	_place(s, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
	_place(s, [[0, 0]], 1)
	s.tap(Board.cell(0, 0))
	s.tap(Board.cell(4, 6))
	assert_array(outcomes).is_equal([true])


# --- arming targeted tools ---------------------------------------------------


func test_only_targeted_tools_can_be_armed() -> void:
	assert_bool(GameSession.is_targeted(Tools.HAMMER)).is_true()
	assert_bool(GameSession.is_targeted(Tools.BOMB)).is_true()
	assert_bool(GameSession.is_targeted(Tools.SWAP)).is_true()
	assert_bool(GameSession.is_targeted(Tools.REROLL)).is_false()
	assert_bool(GameSession.is_targeted(Tools.SHUFFLE)).is_false()
	assert_bool(GameSession.is_targeted(Tools.FORESIGHT)).is_false()


func test_arming_a_targetless_or_locked_tool_is_refused() -> void:
	var s := _empty_session(5)
	assert_bool(s.arm(Tools.REROLL)).is_false()
	assert_bool(s.arm("teleporter")).is_false()
	assert_bool(s.is_armed()).is_false()

	var early := _empty_session(0)
	assert_bool(early.arm(Tools.HAMMER)).is_false()


## Arming must not leave a marble highlighted — that is precisely the tap the
## player did not mean to make.
func test_arming_cancels_a_marble_selection() -> void:
	var s := _empty_session(1)
	_place(s, [[4, 4]], 1)
	s.tap(Board.cell(4, 4))
	assert_bool(s.has_selection()).is_true()

	assert_bool(s.arm(Tools.HAMMER)).is_true()
	assert_bool(s.has_selection()).is_false()
	assert_str(s.armed_tool).is_equal(Tools.HAMMER)


func test_an_armed_hammer_smashes_instead_of_selecting() -> void:
	var s := _empty_session(1)
	_place(s, [[4, 4]], 1)
	s.arm(Tools.HAMMER)
	assert_str(s.tap(Board.cell(4, 4))).is_equal("tool")
	assert_bool(s.board.is_empty_at(4, 4)).is_true()
	assert_bool(s.is_armed()).is_false()
	assert_int(s.charges[Tools.HAMMER]).is_equal(0)


## A tap the tool cannot act on costs nothing, so it must not cost the arming
## either — otherwise a misdirected tap makes the player re-arm.
func test_a_tap_the_tool_cannot_act_on_stays_armed() -> void:
	var s := _empty_session(1)
	_place(s, [[4, 4]], 1)
	s.arm(Tools.HAMMER)
	assert_str(s.tap(Board.cell(0, 0))).is_equal("none")
	assert_bool(s.is_armed()).is_true()
	assert_int(s.charges[Tools.HAMMER]).is_equal(1)
	# And it still works afterwards.
	assert_str(s.tap(Board.cell(4, 4))).is_equal("tool")


func test_disarming_restores_normal_tapping() -> void:
	var s := _empty_session(1)
	_place(s, [[4, 4]], 1)
	s.arm(Tools.HAMMER)
	s.disarm()
	assert_bool(s.is_armed()).is_false()
	assert_str(s.tap(Board.cell(4, 4))).is_equal("select")
	assert_int(s.board.at(4, 4)).is_equal(1)


func test_an_armed_bomb_clears_a_patch_around_the_tap() -> void:
	var s := _empty_session(5)
	for r in range(3, 6):
		for c in range(3, 6):
			s.board.set_at(r, c, 1)
	s.arm(Tools.BOMB)
	assert_str(s.tap(Board.cell(4, 4))).is_equal("tool")
	assert_int(s.board.marble_count()).is_equal(0)
	assert_bool(s.is_armed()).is_false()


func test_the_flask_takes_two_taps() -> void:
	var s := _empty_session(2)
	_place(s, [[1, 1]], 2)
	_place(s, [[5, 5]], 4)
	s.arm(Tools.SWAP)

	assert_str(s.tap(Board.cell(1, 1))).is_equal("arm_second")
	assert_vector(s.swap_first).is_equal(Board.cell(1, 1))
	assert_bool(s.is_armed()).is_true()
	assert_int(s.charges[Tools.SWAP]).is_equal(1)

	assert_str(s.tap(Board.cell(5, 5))).is_equal("tool")
	assert_int(s.board.at(1, 1)).is_equal(4)
	assert_int(s.board.at(5, 5)).is_equal(2)
	assert_bool(s.is_armed()).is_false()
	assert_int(s.charges[Tools.SWAP]).is_equal(0)


func test_the_flask_takes_back_a_first_pick_tapped_again() -> void:
	var s := _empty_session(2)
	_place(s, [[1, 1]], 2)
	s.arm(Tools.SWAP)
	s.tap(Board.cell(1, 1))
	assert_str(s.tap(Board.cell(1, 1))).is_equal("arm_second")
	assert_int(s.swap_first.x).is_equal(-1)
	assert_bool(s.is_armed()).is_true()


func test_the_flask_ignores_empty_cells_for_its_first_pick() -> void:
	var s := _empty_session(2)
	_place(s, [[1, 1]], 2)
	s.arm(Tools.SWAP)
	assert_str(s.tap(Board.cell(7, 7))).is_equal("none")
	assert_int(s.swap_first.x).is_equal(-1)


## Two marbles of one colour is a no-op, so it keeps both the charge and the
## first pick rather than silently resetting.
func test_the_flask_refuses_two_marbles_of_one_colour_and_stays_armed() -> void:
	var s := _empty_session(2)
	_place(s, [[1, 1], [5, 5]], 3)
	_place(s, [[7, 7]], 6)
	s.arm(Tools.SWAP)
	s.tap(Board.cell(1, 1))
	assert_str(s.tap(Board.cell(5, 5))).is_equal("none")
	assert_bool(s.is_armed()).is_true()
	assert_vector(s.swap_first).is_equal(Board.cell(1, 1))
	assert_int(s.charges[Tools.SWAP]).is_equal(1)
	# A different colour then works.
	assert_str(s.tap(Board.cell(7, 7))).is_equal("tool")


func test_reaching_for_a_targetless_tool_cancels_the_armed_one() -> void:
	var s := _empty_session(4)
	_place(s, [[0, 0], [1, 1]], 1)
	_place(s, [[2, 2]], 5)
	s.arm(Tools.HAMMER)
	assert_bool(s.is_armed()).is_true()
	s.use_tool(Tools.SHUFFLE)
	assert_bool(s.is_armed()).is_false()


func test_the_prompt_says_what_the_board_is_waiting_for() -> void:
	var s := _empty_session(2)
	assert_str(s.prompt()).is_empty()

	s.arm(Tools.HAMMER)
	assert_str(s.prompt()).contains("smash")

	s.disarm()
	_place(s, [[1, 1]], 2)
	s.arm(Tools.SWAP)
	assert_str(s.prompt()).contains("first")
	s.tap(Board.cell(1, 1))
	assert_str(s.prompt()).contains("swap it with")


func test_arming_reports_itself() -> void:
	var s := _empty_session(1)
	var seen: Array = []
	s.armed_changed.connect(func(id: String) -> void: seen.append(id))
	s.arm(Tools.HAMMER)
	s.disarm()
	assert_array(seen).is_equal([Tools.HAMMER, ""])


func test_a_tool_cannot_be_armed_without_a_charge() -> void:
	var s := _empty_session(1)
	_place(s, [[3, 3], [4, 4]], 2)
	s.arm(Tools.HAMMER)
	s.tap(Board.cell(3, 3))
	assert_bool(s.arm(Tools.HAMMER)).is_false()
	assert_bool(s.is_armed()).is_false()
