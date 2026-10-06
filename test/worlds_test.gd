## The world table's guardrails.
##
## Ported from `game/data/worlds_check.gd`, the stopgap written before GdUnit4
## existed in this project. Same invariants, now in the real framework and
## runnable alongside everything else.
##
## These are guardrails, not a description of the design. They pin the rules a
## world table must obey for the game to work at all; they deliberately do not
## pin the tuning, so a target or a dial can be changed without a test needing
## to be "fixed" to agree with it. The one exception is `test_dials_match_the_web_ladder`,
## which exists only for the duration of the port.
extends GdUnitTestSuite


func test_count_matches_the_table() -> void:
	assert_int(Worlds.WORLDS.size()).is_equal(Worlds.COUNT)
	assert_int(Worlds.COUNT).is_equal(8)


func test_every_world_has_every_field() -> void:
	var required := [
		"id", "name", "subtitle", "twist", "king", "target", "multiplier",
		"colors", "spawn_count", "preview_count", "start_count",
		"block_probability", "block_min_run_length", "color_affinity", "spawn_on_clear",
	]
	for i in Worlds.COUNT:
		var w: Dictionary = Worlds.WORLDS[i]
		for key in required:
			assert_bool(w.has(key)) \
				.override_failure_message("world %d (%s) is missing '%s'" % [i + 1, w.get("name", "?"), key]) \
				.is_true()


## Save data is keyed on id. A duplicate silently merges two worlds' unlocks
## and best scores into one, which is the kind of bug that only shows up in a
## player's save file.
func test_ids_and_names_are_unique() -> void:
	var ids: Array = []
	var names: Array = []
	for w in Worlds.WORLDS:
		ids.append(w["id"])
		names.append(w["name"])
	assert_int(ids.size()).is_equal(8)
	assert_array(ids).has_size(8)
	assert_int(_unique(ids).size()).override_failure_message("duplicate id in %s" % str(ids)).is_equal(8)
	assert_int(_unique(names).size()).override_failure_message("duplicate name in %s" % str(names)).is_equal(8)


## The multiplier scales line values so the target stays reachable. If the two
## disagree, the world silently needs a different number of lines than its
## design intends — see the note at the top of worlds.gd.
func test_multiplier_tracks_the_target() -> void:
	for w in Worlds.WORLDS:
		assert_int(w["multiplier"]) \
			.override_failure_message("%s: multiplier %d, target %d" % [w["name"], w["multiplier"], w["target"]]) \
			.is_equal(w["target"] / 100)


func test_targets_rise_strictly() -> void:
	var previous := 0
	for w in Worlds.WORLDS:
		assert_int(w["target"]) \
			.override_failure_message("%s: target %d does not exceed %d" % [w["name"], w["target"], previous]) \
			.is_greater(previous)
		previous = w["target"]


## Previewing more marbles than actually spawn would show the player marbles
## that never arrive.
func test_preview_never_exceeds_spawn() -> void:
	for w in Worlds.WORLDS:
		assert_int(w["preview_count"]) \
			.override_failure_message("%s previews %d of %d" % [w["name"], w["preview_count"], w["spawn_count"]]) \
			.is_less_equal(w["spawn_count"])


func test_dials_stay_within_their_ranges() -> void:
	for w in Worlds.WORLDS:
		assert_int(w["colors"]).is_between(2, Rules.COLORS)
		assert_int(w["start_count"]).is_less(Rules.SIZE * Rules.SIZE)
		assert_float(w["block_probability"]).is_between(0.0, 1.0)
		assert_float(w["color_affinity"]).is_between(0.0, 1.0)
		assert_int(w["block_min_run_length"]).is_between(2, Rules.LINE_MIN)


## A stray index must not crash the game into a missing world.
func test_get_world_clamps_at_both_ends() -> void:
	assert_str(Worlds.get_world(-5)["id"]).is_equal(Worlds.WORLDS[0]["id"])
	assert_str(Worlds.get_world(0)["id"]).is_equal(Worlds.WORLDS[0]["id"])
	assert_str(Worlds.get_world(999)["id"]).is_equal(Worlds.WORLDS[Worlds.COUNT - 1]["id"])


func test_is_final_only_at_the_end() -> void:
	for i in Worlds.COUNT - 1:
		assert_bool(Worlds.is_final(i)).is_false()
	assert_bool(Worlds.is_final(Worlds.COUNT - 1)).is_true()


## Save loading matches worlds by id rather than by position, so that
## inserting a world later does not reassign everyone's unlocks.
func test_index_of_finds_ids_and_rejects_unknown() -> void:
	for i in Worlds.COUNT:
		assert_int(Worlds.index_of(Worlds.WORLDS[i]["id"])).is_equal(i)
	assert_int(Worlds.index_of("not_a_world")).is_equal(-1)
	assert_int(Worlds.index_of("")).is_equal(-1)


## Temporary, and deliberately brittle: pins the difficulty dials to the web
## version's `src/game/levels.ts` so the port can be shown to be faithful
## before anything gets retuned.
##
## DELETE THIS once the port is done and the ladder is being tuned for mobile.
## Until then, a failure here means the port drifted, not that the design
## changed.
func test_dials_match_the_web_ladder() -> void:
	# colors, spawn, preview, start, block_p, block_min, affinity, spawn_on_clear
	var expected := [
		[7, 3, 3, 5, 0.35, 3, 1.0, false],
		[7, 3, 3, 5, 0.40, 3, 1.0, false],
		[8, 3, 3, 5, 0.40, 3, 1.0, false],
		[8, 4, 4, 5, 0.40, 3, 1.0, false],
		[8, 4, 3, 5, 0.40, 3, 1.0, false],
		[8, 4, 3, 5, 0.40, 3, 0.45, false],
		[8, 4, 3, 9, 0.40, 3, 0.45, false],
		[8, 4, 3, 9, 0.40, 3, 0.45, true],
	]
	for i in Worlds.COUNT:
		var w: Dictionary = Worlds.WORLDS[i]
		var e: Array = expected[i]
		var got := [
			w["colors"], w["spawn_count"], w["preview_count"], w["start_count"],
			w["block_probability"], w["block_min_run_length"], w["color_affinity"], w["spawn_on_clear"],
		]
		assert_array(got) \
			.override_failure_message("world %d (%s) drifted from levels.ts" % [i + 1, w["name"]]) \
			.is_equal(e)


func _unique(values: Array) -> Array:
	var seen := {}
	for v in values:
		seen[v] = true
	return seen.keys()
