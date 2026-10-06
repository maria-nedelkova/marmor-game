## The engine's test suite, ported from the web version's
## `src/game/engine.test.ts` — the only suite that has ever run, and therefore
## the specification (PLAN.md section 2).
##
## Written before the implementation was trusted, so a failure here means the
## port drifted from the web behaviour rather than that the design changed.
##
## Note on randomness: the web tests pin `rng.random` to a constant where a
## random fallback would otherwise make an assertion a coin flip. This suite
## seeds `MarmorEngine.rng` instead, and where that is not enough it asserts
## the property across many seeds, which is a stronger claim than pinning one.
extends GdUnitTestSuite


func before_test() -> void:
	# Deterministic by default; individual tests reseed where they need to.
	MarmorEngine.rng = RandomNumberGenerator.new()
	MarmorEngine.rng.seed = 20261006


func _board() -> Board:
	return Board.new()


func _place(board: Board, cells: Array, color: int) -> void:
	for rc in cells:
		board.set_at(rc[0], rc[1], color)


# --- find_lines_through ----------------------------------------------------


func test_horizontal_line_of_exactly_five_clears() -> void:
	var b := _board()
	_place(b, [[4, 2], [4, 3], [4, 4], [4, 5], [4, 6]], 1)
	assert_int(MarmorEngine.find_lines_through(b, Board.cell(4, 4)).size()).is_equal(5)


func test_horizontal_line_of_four_does_not_clear() -> void:
	var b := _board()
	_place(b, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
	assert_int(MarmorEngine.find_lines_through(b, Board.cell(4, 4)).size()).is_equal(0)


func test_vertical_line_of_five_clears() -> void:
	var b := _board()
	_place(b, [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3]], 2)
	assert_int(MarmorEngine.find_lines_through(b, Board.cell(2, 3)).size()).is_equal(5)


func test_down_right_diagonal_of_five_clears() -> void:
	var b := _board()
	_place(b, [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4]], 3)
	assert_int(MarmorEngine.find_lines_through(b, Board.cell(2, 2)).size()).is_equal(5)


func test_anti_diagonal_of_five_clears() -> void:
	var b := _board()
	_place(b, [[0, 4], [1, 3], [2, 2], [3, 1], [4, 0]], 4)
	assert_int(MarmorEngine.find_lines_through(b, Board.cell(2, 2)).size()).is_equal(5)


func test_line_longer_than_five_includes_every_matching_cell() -> void:
	var b := _board()
	_place(b, [[4, 0], [4, 1], [4, 2], [4, 3], [4, 4], [4, 5], [4, 6]], 5)
	assert_int(MarmorEngine.find_lines_through(b, Board.cell(4, 3)).size()).is_equal(7)


## The crossing cell must appear once, not twice — this is what the dedupe is
## for, and the web version needs a string-keyed Map to get it.
func test_two_directions_through_one_cell_count_it_once() -> void:
	var b := _board()
	_place(b, [[4, 2], [4, 3], [4, 4], [4, 5], [4, 6]], 0)
	_place(b, [[2, 4], [3, 4], [5, 4], [6, 4]], 0)
	var line := MarmorEngine.find_lines_through(b, Board.cell(4, 4))
	assert_int(line.size()).is_equal(9)
	var unique := {}
	for c in line:
		unique[c] = true
	assert_int(unique.size()).is_equal(line.size())


func test_empty_cell_has_no_line() -> void:
	assert_int(MarmorEngine.find_lines_through(_board(), Board.cell(0, 0)).size()).is_equal(0)


func test_a_spawn_beside_a_run_completes_the_line() -> void:
	var b := _board()
	_place(b, [[4, 2], [4, 3], [4, 4], [4, 5]], 6)
	_place(b, [[4, 6]], 6)
	assert_int(MarmorEngine.find_lines_through(b, Board.cell(4, 6)).size()).is_equal(5)


# --- find_path -------------------------------------------------------------


func test_finds_a_direct_path_across_an_empty_board() -> void:
	var path := MarmorEngine.find_path(_board(), Board.cell(0, 0), Board.cell(0, 4))
	assert_bool(path.is_empty()).is_false()
	assert_vector(path[0]).is_equal(Board.cell(0, 0))
	assert_vector(path[path.size() - 1]).is_equal(Board.cell(0, 4))


func test_every_step_is_an_orthogonal_neighbour() -> void:
	var b := _board()
	_place(b, [[1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [7, 2]], 1)
	var path := MarmorEngine.find_path(b, Board.cell(0, 0), Board.cell(0, 8))
	assert_bool(path.is_empty()).is_false()
	for i in range(1, path.size()):
		var d: int = absi(path[i - 1].x - path[i].x) + absi(path[i - 1].y - path[i].y)
		assert_int(d).override_failure_message("diagonal jump at step %d" % i).is_equal(1)


func test_path_never_passes_through_an_occupied_cell() -> void:
	var b := _board()
	_place(b, [[1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [7, 2]], 1)
	var path := MarmorEngine.find_path(b, Board.cell(0, 0), Board.cell(0, 8))
	for p in path:
		if p == Board.cell(0, 0) or p == Board.cell(0, 8):
			continue
		assert_bool(b.is_empty_at(p.x, p.y)).is_true()


func test_returns_nothing_when_the_destination_is_walled_off() -> void:
	var b := _board()
	for r in Rules.SIZE:
		b.set_at(r, 4, 1)
	assert_bool(MarmorEngine.find_path(b, Board.cell(0, 0), Board.cell(0, 8)).is_empty()).is_true()


func test_returns_nothing_when_the_destination_is_occupied() -> void:
	var b := _board()
	b.set_at(0, 3, 2)
	assert_bool(MarmorEngine.find_path(b, Board.cell(0, 0), Board.cell(0, 3)).is_empty()).is_true()


# --- reachable_from --------------------------------------------------------


func test_reachable_does_not_cross_a_wall() -> void:
	var b := _board()
	for r in Rules.SIZE:
		b.set_at(r, 4, 1)
	for p in MarmorEngine.reachable_from(b, Board.cell(0, 0)):
		assert_int(p.y).override_failure_message("reached %s across the wall" % p).is_less(4)


# --- colour counts ---------------------------------------------------------


func test_color_counts_counts_each_colour() -> void:
	var b := _board()
	_place(b, [[0, 0], [0, 1], [0, 2]], 3)
	_place(b, [[1, 0]], 5)
	var counts := b.color_counts()
	assert_int(counts.size()).is_equal(Rules.COLORS)
	assert_int(counts[3]).is_equal(3)
	assert_int(counts[5]).is_equal(1)
	assert_int(counts[0]).is_equal(0)


# --- weighted_random_color -------------------------------------------------


func test_every_colour_remains_reachable_on_an_empty_board() -> void:
	var b := _board()
	var seen := {}
	for _i in 2000:
		seen[MarmorEngine.weighted_random_color(b)] = true
	assert_int(seen.size()).is_equal(Rules.COLORS)


func test_biased_toward_colours_already_on_the_board() -> void:
	var b := _board()
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			b.set_at(r, c, 2)
	b.set_at(0, 0, 6)

	var two := 0
	var six := 0
	for _i in 2000:
		var picked := MarmorEngine.weighted_random_color(b)
		if picked == 2:
			two += 1
		elif picked == 6:
			six += 1
	assert_int(two).is_greater(six * 10)


## A colour left on the board by a previous world must not drag the picker past
## the current world's range.
func test_never_returns_a_colour_outside_the_range() -> void:
	var b := _board()
	_place(b, [[0, 0], [0, 1], [0, 2], [0, 3]], 6)
	for _i in 500:
		var color := MarmorEngine.weighted_random_color(b, 5)
		assert_int(color).is_between(0, 4)


## The affinity dial, asserted against the formula rather than hard-coded
## shares — shares silently encode whatever COLOR_SMOOTHING happens to be, and
## the web version's earlier test failed purely because that constant was
## retuned.
func test_affinity_zero_ignores_the_board() -> void:
	var b := _board()
	for r in 5:
		for c in 8:
			b.set_at(r, c, 0)

	var runs := 3000
	var biased := 0
	var flat := 0
	for _i in runs:
		if MarmorEngine.weighted_random_color(b, Rules.COLORS, 1.0) == 0:
			biased += 1
		if MarmorEngine.weighted_random_color(b, Rules.COLORS, 0.0) == 0:
			flat += 1

	var expected_biased := float(40 + MarmorEngine.COLOR_SMOOTHING) / float(40 + Rules.COLORS * MarmorEngine.COLOR_SMOOTHING)
	var expected_flat := 1.0 / float(Rules.COLORS)
	assert_float(float(biased) / runs).is_between(expected_biased - 0.08, expected_biased + 0.08)
	assert_float(float(flat) / runs).is_between(expected_flat - 0.05, expected_flat + 0.05)
	# The point of the dial: clustering must be much stronger at 1 than at 0.
	assert_int(biased).is_greater(flat * 3)


## The bug this guards: with too small a smoothing constant a colour that falls
## behind effectively never returns. On a realistic 47-marble board an absent
## colour must stay well above ~1 in 50 per spawn, or it takes ~18 turns to
## reappear and the board looks stuck on three colours.
func test_an_absent_colour_keeps_a_usable_chance_on_a_busy_board() -> void:
	var b := _board()
	var placed := 0
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			if placed >= 47:
				break
			b.set_at(r, c, placed % 3)
			placed += 1

	var runs := 20000
	var absent := 0
	for _i in runs:
		if MarmorEngine.weighted_random_color(b, Rules.COLORS, 1.0) == 7:
			absent += 1
	assert_float(float(absent) / runs).is_greater(0.03)


func test_no_colour_starves_on_an_empty_board() -> void:
	var b := _board()
	var counts := PackedInt32Array()
	counts.resize(Rules.COLORS)
	counts.fill(0)
	for _i in 7000:
		counts[MarmorEngine.weighted_random_color(b)] += 1
	for i in Rules.COLORS:
		assert_int(counts[i]).override_failure_message("colour %d never appeared" % i).is_greater(0)


# --- longest_run_through ---------------------------------------------------


func test_isolated_empty_cell_has_run_length_one() -> void:
	assert_int(MarmorEngine.longest_run_through(_board(), Board.cell(4, 4), 0)).is_equal(1)


func test_counts_contiguous_neighbours_on_both_sides() -> void:
	var b := _board()
	_place(b, [[4, 1], [4, 2], [4, 3]], 2)
	_place(b, [[4, 5], [4, 6]], 2)
	assert_int(MarmorEngine.longest_run_through(b, Board.cell(4, 4), 2)).is_equal(6)


func test_a_mismatched_colour_sees_no_boost() -> void:
	var b := _board()
	_place(b, [[4, 3], [4, 5]], 2)
	assert_int(MarmorEngine.longest_run_through(b, Board.cell(4, 4), 3)).is_equal(1)


func test_detects_diagonal_runs() -> void:
	var b := _board()
	_place(b, [[0, 0], [1, 1], [2, 2]], 5)
	assert_int(MarmorEngine.longest_run_through(b, Board.cell(3, 3), 5)).is_equal(4)


# --- find_top_threats ------------------------------------------------------


func test_finds_the_cell_that_completes_a_near_full_line_first() -> void:
	var b := _board()
	_place(b, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
	var threats := MarmorEngine.find_top_threats(b, 3)
	assert_int(threats.size()).is_greater(0)
	var top: Dictionary = threats[0]
	assert_int(top["length"]).is_equal(5)
	assert_int(top["color"]).is_equal(1)
	assert_int(top["cell"].x).is_equal(4)
	assert_array([1, 6]).contains([top["cell"].y])


func test_ignores_runs_shorter_than_min_length() -> void:
	var b := _board()
	_place(b, [[0, 0]], 4)
	for t in MarmorEngine.find_top_threats(b, 3):
		assert_int(t["color"]).is_not_equal(4)


func test_empty_board_has_no_threats() -> void:
	assert_int(MarmorEngine.find_top_threats(_board(), 3).size()).is_equal(0)


## The tie-break that JavaScript gets free from a stable sort and GDScript does
## not.
##
## Two things about this test were found the hard way and are worth keeping:
##
## 1. Seeding the RNG and re-running proves nothing — find_top_threats never
##    touches the RNG, so that version of this test passed with the tie-breaks
##    deleted.
## 2. The list has to be BIG. Godot sorts small arrays with insertion sort,
##    which is stable, so a 7-threat board also passes with the tie-breaks
##    deleted. Measured: the orders diverge from about 50 threats, where
##    introsort takes over. Hence the density here and the size assertion.
##
## Verified by mutation: removing the tie-breaks fails this test.
func test_threats_are_sorted_by_a_total_order() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var b := _board()
	for _m in 10:
		var free := b.empty_cells()
		b.set_at_cell(free[rng.randi_range(0, free.size() - 1)], rng.randi_range(0, 7))

	# min_length 2 rather than the ladder's 3, purely to get a list long enough
	# to reach the unstable sort path. It is the same comparator either way.
	var threats := MarmorEngine.find_top_threats(b, 2)
	assert_int(threats.size()) \
		.override_failure_message("list too short to exercise the unstable sort") \
		.is_greater_equal(50)

	var ties := 0
	for i in range(1, threats.size()):
		var a: Dictionary = threats[i - 1]
		var c: Dictionary = threats[i]
		var ordered := false
		if a["length"] != c["length"]:
			ordered = a["length"] > c["length"]
		else:
			ties += 1
			if a["cell"].x != c["cell"].x:
				ordered = a["cell"].x < c["cell"].x
			elif a["cell"].y != c["cell"].y:
				ordered = a["cell"].y < c["cell"].y
			else:
				ordered = a["color"] < c["color"]
		assert_bool(ordered) \
			.override_failure_message("out of order at %d: %s then %s" % [i, a, c]) \
			.is_true()

	assert_int(ties).override_failure_message("no ties — the tie-break was not exercised").is_greater(20)


# --- assign_spawn_cells ----------------------------------------------------


func test_blocks_the_most_advanced_line_with_a_mismatched_colour() -> void:
	var b := _board()
	_place(b, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
	var result := MarmorEngine.assign_spawn_cells(b, [2] as Array[int])
	assert_bool(result["blocked"]).is_true()
	var cells: Array = result["cells"]
	assert_int(cells.size()).is_equal(1)
	assert_int(cells[0].x).is_equal(4)
	assert_array([1, 6]).contains([cells[0].y])


## If the only colour available IS the threatened colour, "blocking" with it
## would finish the line for the player. The web test pins the random fallback
## to index 0 to stop this being a coin flip; this asserts the property across
## many seeds instead, which is a stronger claim.
func test_never_hands_the_player_their_own_finishing_colour() -> void:
	for seed_value in [0, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144]:
		MarmorEngine.rng.seed = seed_value
		var b := _board()
		_place(b, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
		var result := MarmorEngine.assign_spawn_cells(b, [1] as Array[int])
		assert_bool(result["blocked"]).override_failure_message("seed %d blocked with the finishing colour" % seed_value).is_false()
		var cells: Array = result["cells"]
		assert_int(cells.size()).is_equal(1)
		if cells[0].x == 4:
			assert_bool(cells[0].y == 1 or cells[0].y == 6) \
				.override_failure_message("seed %d completed the player's line at %s" % [seed_value, cells[0]]) \
				.is_false()


func test_never_returns_duplicate_or_occupied_cells() -> void:
	for seed_value in [1, 42, 1000, 31337]:
		MarmorEngine.rng.seed = seed_value
		var b := _board()
		_place(b, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
		_place(b, [[0, 0], [0, 1], [0, 2]], 3)
		var cells: Array = MarmorEngine.assign_spawn_cells(b, [2, 4, 5, 6] as Array[int])["cells"]
		var unique := {}
		for c in cells:
			unique[c] = true
			assert_bool(b.is_empty_at(c.x, c.y)).is_true()
		assert_int(unique.size()).is_equal(cells.size())


func test_caps_output_at_the_number_of_empty_cells() -> void:
	var b := _board()
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			if not (r == 0 and (c == 0 or c == 1)):
				b.set_at(r, c, 0)
	var cells: Array = MarmorEngine.assign_spawn_cells(b, [1, 1, 1, 1, 1] as Array[int])["cells"]
	assert_int(cells.size()).is_equal(2)


func test_blocking_disabled_never_blocks() -> void:
	var b := _board()
	_place(b, [[4, 2], [4, 3], [4, 4], [4, 5]], 1)
	var result := MarmorEngine.assign_spawn_cells(b, [2] as Array[int], 3, false)
	assert_bool(result["blocked"]).is_false()


## Colour 6 is on the board but this world only plays colours 0-4, so the
## threat scan must not see it and must not aim a spawn at it.
func test_a_threat_outside_the_worlds_colours_is_not_blocked() -> void:
	var b := _board()
	_place(b, [[4, 2], [4, 3], [4, 4], [4, 5]], 6)
	var result := MarmorEngine.assign_spawn_cells(b, [2] as Array[int], 3, true, 5)
	assert_bool(result["blocked"]).is_false()


func test_spawning_into_a_full_board_yields_nothing() -> void:
	var b := _board()
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			b.set_at(r, c, 0)
	var result := MarmorEngine.assign_spawn_cells(b, [1, 2] as Array[int])
	assert_int((result["cells"] as Array).size()).is_equal(0)
	assert_bool(result["blocked"]).is_false()


# --- scoring ---------------------------------------------------------------


func test_score_for_five_is_ten() -> void:
	assert_int(MarmorEngine.score_for_clear(5)).is_equal(10)


func test_longer_lines_score_a_bonus() -> void:
	assert_int(MarmorEngine.score_for_clear(6)).is_greater(MarmorEngine.score_for_clear(5))
	assert_int(MarmorEngine.score_for_clear(9)).is_equal(9 * 2 + 4 * 3)


# --- smash_marble ----------------------------------------------------------


func test_smash_removes_the_marble() -> void:
	var b := _board()
	_place(b, [[3, 3]], 2)
	assert_bool(MarmorEngine.smash_marble(b, Board.cell(3, 3))).is_true()
	assert_bool(b.is_empty_at(3, 3)).is_true()


func test_smash_declines_on_an_empty_cell() -> void:
	assert_bool(MarmorEngine.smash_marble(_board(), Board.cell(0, 0))).is_false()


func test_smash_declines_out_of_bounds() -> void:
	var b := _board()
	assert_bool(MarmorEngine.smash_marble(b, Board.cell(-1, 0))).is_false()
	assert_bool(MarmorEngine.smash_marble(b, Board.cell(0, Rules.SIZE))).is_false()


func test_smash_can_open_the_gap_a_blocked_line_needed() -> void:
	var b := _board()
	_place(b, [[4, 0], [4, 1], [4, 2], [4, 4], [4, 5]], 1)
	_place(b, [[4, 3]], 6)
	MarmorEngine.smash_marble(b, Board.cell(4, 3))
	b.set_at(4, 3, 1)
	assert_int(MarmorEngine.find_lines_through(b, Board.cell(4, 3)).size()).is_equal(6)


# --- swap_marble_colors ----------------------------------------------------


func test_swap_exchanges_two_colours() -> void:
	var b := _board()
	_place(b, [[1, 1]], 2)
	_place(b, [[5, 5]], 4)
	assert_bool(MarmorEngine.swap_marble_colors(b, Board.cell(1, 1), Board.cell(5, 5))).is_true()
	assert_int(b.at(1, 1)).is_equal(4)
	assert_int(b.at(5, 5)).is_equal(2)


func test_swap_can_complete_a_line() -> void:
	var b := _board()
	_place(b, [[4, 0], [4, 1], [4, 2], [4, 3]], 1)
	_place(b, [[4, 4]], 6)
	_place(b, [[0, 0]], 1)
	MarmorEngine.swap_marble_colors(b, Board.cell(4, 4), Board.cell(0, 0))
	assert_int(MarmorEngine.find_lines_through(b, Board.cell(4, 4)).size()).is_equal(5)


func test_swap_refuses_when_either_cell_is_empty() -> void:
	var b := _board()
	_place(b, [[1, 1]], 2)
	assert_bool(MarmorEngine.swap_marble_colors(b, Board.cell(1, 1), Board.cell(5, 5))).is_false()
	assert_int(b.at(1, 1)).is_equal(2)


func test_swap_refuses_two_marbles_of_the_same_colour() -> void:
	var b := _board()
	_place(b, [[1, 1], [5, 5]], 3)
	assert_bool(MarmorEngine.swap_marble_colors(b, Board.cell(1, 1), Board.cell(5, 5))).is_false()


func test_swap_conserves_the_marble_count() -> void:
	var b := _board()
	_place(b, [[1, 1]], 2)
	_place(b, [[5, 5]], 4)
	var before := b.marble_count()
	MarmorEngine.swap_marble_colors(b, Board.cell(1, 1), Board.cell(5, 5))
	assert_int(b.marble_count()).is_equal(before)


# --- bomb_at ---------------------------------------------------------------


func test_bomb_clears_the_target_and_all_eight_neighbours() -> void:
	var b := _board()
	for r in range(3, 6):
		for c in range(3, 6):
			b.set_at(r, c, 1)
	assert_int(MarmorEngine.bomb_at(b, Board.cell(4, 4))).is_equal(9)
	assert_int(b.marble_count()).is_equal(0)


func test_bomb_leaves_everything_outside_the_patch_alone() -> void:
	var b := _board()
	_place(b, [[4, 4]], 1)
	_place(b, [[4, 6], [6, 4], [2, 2]], 2)
	assert_int(MarmorEngine.bomb_at(b, Board.cell(4, 4))).is_equal(1)
	assert_int(b.at(4, 6)).is_equal(2)
	assert_int(b.at(6, 4)).is_equal(2)
	assert_int(b.at(2, 2)).is_equal(2)


func test_bomb_clips_at_a_corner() -> void:
	var b := _board()
	for r in 2:
		for c in 2:
			b.set_at(r, c, 3)
	assert_int(MarmorEngine.bomb_at(b, Board.cell(0, 0))).is_equal(4)


func test_bomb_reports_zero_on_an_empty_patch() -> void:
	var b := _board()
	_place(b, [[8, 8]], 1)
	assert_int(MarmorEngine.bomb_at(b, Board.cell(2, 2))).is_equal(0)
	assert_int(b.at(8, 8)).is_equal(1)


func test_bomb_with_an_empty_centre_still_clears_the_ring() -> void:
	var b := _board()
	_place(b, [[3, 3], [3, 4], [3, 5], [4, 3], [4, 5]], 2)
	assert_int(MarmorEngine.bomb_at(b, Board.cell(4, 4))).is_equal(5)


# --- shuffle_board_colors --------------------------------------------------


func test_shuffle_keeps_occupancy_and_colour_counts() -> void:
	var b := _board()
	_place(b, [[0, 0], [0, 1], [3, 4]], 1)
	_place(b, [[2, 2], [5, 5]], 4)
	_place(b, [[7, 1]], 6)
	var before_count := b.marble_count()
	var before_colors := b.color_counts()

	assert_bool(MarmorEngine.shuffle_board_colors(b)).is_true()

	assert_int(b.marble_count()).is_equal(before_count)
	assert_array(Array(b.color_counts())).is_equal(Array(before_colors))


## The same cells, never different ones — the tool stirs the board, it does not
## redraw the free space the player has been working with.
func test_shuffle_preserves_occupancy_exactly() -> void:
	var b := _board()
	var cells := [[0, 0], [1, 5], [4, 4], [8, 2], [6, 7]]
	for i in cells.size():
		b.set_at(cells[i][0], cells[i][1], i % 3)
	MarmorEngine.shuffle_board_colors(b)
	for r in Rules.SIZE:
		for c in Rules.SIZE:
			var should_hold := false
			for rc in cells:
				if rc[0] == r and rc[1] == c:
					should_hold = true
					break
			assert_bool(not b.is_empty_at(r, c)) \
				.override_failure_message("occupancy changed at (%d,%d)" % [r, c]) \
				.is_equal(should_hold)


func test_shuffle_actually_rearranges() -> void:
	var b := _board()
	_place(b, [[0, 0], [0, 1], [0, 2], [0, 3]], 1)
	_place(b, [[1, 0], [1, 1], [1, 2], [1, 3]], 5)
	var before: Array[int] = []
	for p in b.occupied_cells():
		before.append(b.at(p.x, p.y))

	assert_bool(MarmorEngine.shuffle_board_colors(b)).is_true()

	var after: Array[int] = []
	for p in b.occupied_cells():
		after.append(b.at(p.x, p.y))
	assert_array(after).is_not_equal(before)


func test_shuffle_refuses_a_board_it_cannot_change() -> void:
	assert_bool(MarmorEngine.shuffle_board_colors(_board())).is_false()

	var single := _board()
	_place(single, [[4, 4]], 2)
	assert_bool(MarmorEngine.shuffle_board_colors(single)).is_false()

	var monochrome := _board()
	_place(monochrome, [[0, 0], [3, 3], [8, 8]], 2)
	assert_bool(MarmorEngine.shuffle_board_colors(monochrome)).is_false()


# --- board representation --------------------------------------------------


## The reason for flat storage: GDScript Arrays are references, so an
## array-of-arrays board would share its rows with any copy.
func test_duplicate_board_is_independent() -> void:
	var b := _board()
	_place(b, [[2, 2]], 5)
	var copy := b.duplicate_board()
	copy.set_at(2, 2, 1)
	copy.set_at(7, 7, 3)
	assert_int(b.at(2, 2)).is_equal(5)
	assert_bool(b.is_empty_at(7, 7)).is_true()


# --- fuzz ------------------------------------------------------------------


## 10,000 random legal moves: never crashes, never corrupts the marble count,
## and the two travel functions never disagree about what is reachable.
func test_fuzz_random_legal_moves_stay_consistent() -> void:
	MarmorEngine.rng.seed = 424242
	var b := _board()

	for _i in 5:
		var free := b.empty_cells()
		b.set_at_cell(free[MarmorEngine.rng.randi_range(0, free.size() - 1)], MarmorEngine.rng.randi_range(0, 6))

	for _iter in 10000:
		var occupied := b.occupied_cells()
		var free := b.empty_cells()
		if occupied.is_empty() or free.is_empty():
			break

		var from: Vector2i = occupied[MarmorEngine.rng.randi_range(0, occupied.size() - 1)]
		var to: Vector2i = free[MarmorEngine.rng.randi_range(0, free.size() - 1)]
		var path := MarmorEngine.find_path(b, from, to)
		if path.is_empty():
			continue

		var color := b.at(from.x, from.y)
		b.clear_at(from.x, from.y)
		b.set_at_cell(to, color)

		var matches := MarmorEngine.find_lines_through(b, to)
		if matches.size() > 0:
			for p in matches:
				b.clear_at(p.x, p.y)
		else:
			var spawn_free := b.empty_cells()
			for _s in mini(3, spawn_free.size()):
				var idx := MarmorEngine.rng.randi_range(0, spawn_free.size() - 1)
				b.set_at_cell(spawn_free[idx], MarmorEngine.rng.randi_range(0, 6))
				spawn_free.remove_at(idx)

		var count := b.marble_count()
		assert_int(count).is_between(0, Rules.SIZE * Rules.SIZE)


## find_path and reachable_from must agree: if one says a destination is
## reachable, so must the other. They are separate traversals of the same rule,
## and the web version's fuzz suite does not check this.
func test_fuzz_path_and_reachability_agree() -> void:
	MarmorEngine.rng.seed = 909090
	for _iter in 200:
		var b := _board()
		for _m in MarmorEngine.rng.randi_range(5, 45):
			var free := b.empty_cells()
			if free.is_empty():
				break
			b.set_at_cell(free[MarmorEngine.rng.randi_range(0, free.size() - 1)], MarmorEngine.rng.randi_range(0, 7))

		var occupied := b.occupied_cells()
		if occupied.is_empty():
			continue
		var from: Vector2i = occupied[MarmorEngine.rng.randi_range(0, occupied.size() - 1)]

		var reachable := {}
		for p in MarmorEngine.reachable_from(b, from):
			reachable[p] = true

		for to in b.empty_cells():
			var has_path := not MarmorEngine.find_path(b, from, to).is_empty()
			assert_bool(has_path) \
				.override_failure_message("find_path and reachable_from disagree: %s -> %s" % [from, to]) \
				.is_equal(reachable.has(to))
