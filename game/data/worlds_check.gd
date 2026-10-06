## Headless self-check for the world table.
##
## Run with:
##   Godot --headless --path . --script game/data/worlds_check.gd
##
## A stopgap, not the test suite. PLAN.md calls for GdUnit4 and for the engine
## tests to be ported from the web suite before the engine itself; this exists
## because the world table landed first and data that nothing reads is data
## nobody notices is wrong. Delete it once GdUnit4 covers the same ground.
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []

	if Worlds.WORLDS.size() != Worlds.COUNT:
		failures.append("WORLDS has %d entries, COUNT says %d" % [Worlds.WORLDS.size(), Worlds.COUNT])

	var seen_ids := {}
	var seen_names := {}
	var previous_target := 0

	for i in Worlds.WORLDS.size():
		var w: Dictionary = Worlds.WORLDS[i]
		var where := "world %d (%s)" % [i + 1, w.get("name", "?")]

		for key in [
			"id", "name", "subtitle", "twist", "king", "target", "multiplier",
			"colors", "spawn_count", "preview_count", "start_count",
			"block_probability", "block_min_run_length", "color_affinity", "spawn_on_clear",
		]:
			if not w.has(key):
				failures.append("%s is missing '%s'" % [where, key])

		# Save data is keyed on id, so a duplicate silently merges two worlds'
		# unlocks and bests.
		if seen_ids.has(w["id"]):
			failures.append("%s repeats id '%s'" % [where, w["id"]])
		seen_ids[w["id"]] = true
		if seen_names.has(w["name"]):
			failures.append("%s repeats name '%s'" % [where, w["name"]])
		seen_names[w["name"]] = true

		# The multiplier scales line values to the target; if they disagree the
		# level needs a different number of lines than intended.
		if w["multiplier"] != w["target"] / 100:
			failures.append("%s: multiplier %d != target/100 (%d)" % [where, w["multiplier"], w["target"] / 100])

		if w["target"] <= previous_target:
			failures.append("%s: target %d does not exceed the previous %d" % [where, w["target"], previous_target])
		previous_target = w["target"]

		# Previewing more than spawns would show marbles that never arrive.
		if w["preview_count"] > w["spawn_count"]:
			failures.append("%s: preview_count %d exceeds spawn_count %d" % [where, w["preview_count"], w["spawn_count"]])
		if w["colors"] > Rules.COLORS:
			failures.append("%s: colors %d exceeds the palette ceiling %d" % [where, w["colors"], Rules.COLORS])
		if w["start_count"] >= Rules.SIZE * Rules.SIZE:
			failures.append("%s: start_count %d does not fit a %dx%d board" % [where, w["start_count"], Rules.SIZE, Rules.SIZE])
		if w["block_probability"] < 0.0 or w["block_probability"] > 1.0:
			failures.append("%s: block_probability %f is not a probability" % [where, w["block_probability"]])
		if w["color_affinity"] < 0.0 or w["color_affinity"] > 1.0:
			failures.append("%s: color_affinity %f is out of range" % [where, w["color_affinity"]])

	# get_world clamps rather than crashing on a stray index.
	if Worlds.get_world(-5)["id"] != Worlds.WORLDS[0]["id"]:
		failures.append("get_world(-5) did not clamp to the first world")
	if Worlds.get_world(999)["id"] != Worlds.WORLDS[Worlds.COUNT - 1]["id"]:
		failures.append("get_world(999) did not clamp to the last world")
	if not Worlds.is_final(Worlds.COUNT - 1) or Worlds.is_final(0):
		failures.append("is_final is wrong at the ends")
	if Worlds.index_of("gaia_prime") != 6:
		failures.append("index_of('gaia_prime') != 6")
	if Worlds.index_of("nope") != -1:
		failures.append("index_of on an unknown id did not return -1")

	if failures.is_empty():
		print("worlds_check: OK — %d worlds, every invariant holds." % Worlds.COUNT)
		quit(0)
	else:
		for f in failures:
			printerr("worlds_check: " + f)
		printerr("worlds_check: %d FAILURE(S)" % failures.size())
		quit(1)
