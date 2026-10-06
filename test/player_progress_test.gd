## Progress: unlocks, per-world bests, the monthly roll, and hostile loads.
##
## The hostile-load cases matter more here than anywhere else in the project.
## The save is plain JSON in user://, which a player can open and edit, and a
## fabricated score would quietly own the leaderboard.
extends GdUnitTestSuite


func _fresh() -> PlayerProgress:
	var p := PlayerProgress.new()
	p.period = PlayerProgress.current_period()
	return p


# --- unlocks ---------------------------------------------------------------


func test_only_the_first_world_is_unlocked_initially() -> void:
	var p := _fresh()
	assert_bool(p.is_unlocked(0)).is_true()
	for i in range(1, Worlds.COUNT):
		assert_bool(p.is_unlocked(i)).is_false()


func test_clearing_a_world_unlocks_the_next() -> void:
	var p := _fresh()
	p.record_clear(0, 120)
	assert_bool(p.is_unlocked(1)).is_true()
	assert_bool(p.is_unlocked(2)).is_false()


## Replaying a world you have already beaten must not push the frontier
## forward — only clearing the newest unlocked world advances it.
func test_replaying_an_old_world_does_not_advance_the_frontier() -> void:
	var p := _fresh()
	p.record_clear(0, 120)
	p.record_clear(1, 350)
	assert_int(p.unlocked_through).is_equal(2)
	p.record_clear(0, 999)
	assert_int(p.unlocked_through).is_equal(2)


func test_clearing_the_final_world_does_not_run_past_the_end() -> void:
	var p := _fresh()
	p.unlocked_through = Worlds.COUNT - 1
	p.record_clear(Worlds.COUNT - 1, 5000)
	assert_int(p.unlocked_through).is_equal(Worlds.COUNT - 1)
	assert_bool(p.is_unlocked(Worlds.COUNT)).is_false()


func test_out_of_range_clears_are_ignored() -> void:
	var p := _fresh()
	assert_bool(p.record_clear(-1, 100)).is_false()
	assert_bool(p.record_clear(Worlds.COUNT, 100)).is_false()
	assert_int(p.unlocked_through).is_equal(0)


# --- bests and the monthly total -------------------------------------------


func test_only_a_better_score_replaces_the_best() -> void:
	var p := _fresh()
	p.record_clear(0, 140)
	assert_int(p.best_for(0)).is_equal(140)
	p.record_clear(0, 110)
	assert_int(p.best_for(0)).is_equal(140)
	p.record_clear(0, 160)
	assert_int(p.best_for(0)).is_equal(160)


## The whole point of summing bests: repetition alone earns nothing, so
## grinding the easiest world is not a strategy.
func test_the_monthly_total_is_the_sum_of_bests_not_of_clears() -> void:
	var p := _fresh()
	p.record_clear(0, 140)
	p.record_clear(1, 320)
	assert_int(p.monthly_total()).is_equal(460)

	for _i in 10:
		p.record_clear(0, 100)
	assert_int(p.monthly_total()).is_equal(460)

	p.record_clear(0, 200)
	assert_int(p.monthly_total()).is_equal(520)


func test_an_unplayed_world_contributes_nothing() -> void:
	assert_int(_fresh().monthly_total()).is_equal(0)


# --- the monthly roll ------------------------------------------------------


func test_rolling_the_period_wipes_scores_but_keeps_unlocks() -> void:
	var p := _fresh()
	p.record_clear(0, 140)
	p.record_clear(1, 320)
	p.period = PlayerProgress.current_period() - 1

	assert_bool(p.roll_period_if_needed()).is_true()
	assert_int(p.monthly_total()).is_equal(0)
	assert_int(p.unlocked_through).is_equal(2)
	assert_bool(p.is_unlocked(2)).is_true()


func test_rolling_within_the_same_period_changes_nothing() -> void:
	var p := _fresh()
	p.record_clear(0, 140)
	assert_bool(p.roll_period_if_needed()).is_false()
	assert_int(p.monthly_total()).is_equal(140)


# --- round trip ------------------------------------------------------------


func test_a_saved_dictionary_loads_back_identically() -> void:
	var p := _fresh()
	p.record_clear(0, 140)
	p.record_clear(1, 320)

	var loaded := PlayerProgress.from_dict(p.to_dict())
	assert_int(loaded.unlocked_through).is_equal(p.unlocked_through)
	assert_int(loaded.best_for(0)).is_equal(140)
	assert_int(loaded.best_for(1)).is_equal(320)
	assert_int(loaded.monthly_total()).is_equal(460)


## Bests are keyed by the world's stable id, so renaming a world's display name
## must not lose anyone's score. This is why worlds.gd keeps `id` separate from
## `name`.
func test_bests_are_keyed_by_id_not_by_name_or_index() -> void:
	var p := _fresh()
	p.record_clear(2, 600)
	var dict := p.to_dict()
	assert_bool((dict["bests"] as Dictionary).has("crystallos")).is_true()


# --- hostile loads ---------------------------------------------------------


func test_garbage_loads_as_a_fresh_profile() -> void:
	for junk in [null, 42, "not a save", [], {"bests": "nope"}]:
		var p := PlayerProgress.from_dict(junk)
		assert_int(p.unlocked_through) \
			.override_failure_message("junk %s produced unlocks" % str(junk)) \
			.is_equal(0)
		assert_int(p.monthly_total()).is_equal(0)


func test_an_absurd_score_is_capped_rather_than_trusted() -> void:
	var p := PlayerProgress.from_dict({
		"version": 1,
		"period": PlayerProgress.current_period(),
		"unlocked_through": 0,
		"bests": {"neonia_1": 999999999},
	})
	assert_int(p.best_for(0)).is_equal(PlayerProgress.score_ceiling(0))
	assert_int(p.best_for(0)).is_less(999999999)


func test_an_out_of_range_unlock_is_clamped_into_the_ladder() -> void:
	var p := PlayerProgress.from_dict({
		"period": PlayerProgress.current_period(),
		"unlocked_through": 9999,
		"bests": {},
	})
	assert_int(p.unlocked_through).is_equal(Worlds.COUNT - 1)

	var negative := PlayerProgress.from_dict({
		"period": PlayerProgress.current_period(),
		"unlocked_through": -5,
		"bests": {},
	})
	assert_int(negative.unlocked_through).is_equal(0)


func test_a_score_for_a_world_that_does_not_exist_is_dropped() -> void:
	var p := PlayerProgress.from_dict({
		"period": PlayerProgress.current_period(),
		"unlocked_through": 1,
		"bests": {"neonia_1": 100, "atlantis": 5000, "": 1},
	})
	assert_int(p.best_for(0)).is_equal(100)
	assert_int(p.monthly_total()).is_equal(100)


## A save written last month keeps its unlocks and loses its scores, through
## the load path as well as through roll_period_if_needed.
func test_loading_a_save_from_another_period_drops_its_scores() -> void:
	var p := PlayerProgress.from_dict({
		"period": PlayerProgress.current_period() - 3,
		"unlocked_through": 4,
		"bests": {"neonia_1": 140, "sulfur_kor": 320},
	})
	assert_int(p.unlocked_through).is_equal(4)
	assert_int(p.monthly_total()).is_equal(0)


func test_a_non_numeric_score_is_skipped_not_coerced() -> void:
	var p := PlayerProgress.from_dict({
		"period": PlayerProgress.current_period(),
		"unlocked_through": 1,
		"bests": {"neonia_1": "lots", "sulfur_kor": 300},
	})
	assert_int(p.best_for(0)).is_equal(0)
	assert_int(p.best_for(1)).is_equal(300)


# --- the real file ---------------------------------------------------------


func test_save_and_load_through_the_filesystem() -> void:
	if FileAccess.file_exists(PlayerProgress.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProgress.SAVE_PATH))

	var p := _fresh()
	p.record_clear(0, 175)
	p.record_clear(1, 410)
	p.save()

	var loaded := PlayerProgress.load_progress()
	assert_int(loaded.best_for(0)).is_equal(175)
	assert_int(loaded.best_for(1)).is_equal(410)
	assert_int(loaded.unlocked_through).is_equal(2)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProgress.SAVE_PATH))


func test_loading_with_no_save_file_is_a_fresh_profile() -> void:
	if FileAccess.file_exists(PlayerProgress.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProgress.SAVE_PATH))
	var loaded := PlayerProgress.load_progress()
	assert_int(loaded.unlocked_through).is_equal(0)
	assert_int(loaded.monthly_total()).is_equal(0)
