## The planet art, checked the same two ways the kings are: a row of the wrong
## width shifts every pixel after it, and a character with no palette entry
## draws as a transparent hole.
extends GdUnitTestSuite


func test_every_world_has_a_planet() -> void:
	for i in Worlds.COUNT:
		var id: String = Worlds.get_world(i)["id"]
		assert_bool(Planets.SPRITES.has(id)).override_failure_message("%s has no sprite" % id).is_true()
		assert_bool(Planets.PALETTES.has(id)).override_failure_message("%s has no palette" % id).is_true()


func test_every_sprite_is_sixteen_square() -> void:
	for id in Planets.SPRITES:
		var rows: Array = Planets.SPRITES[id]
		assert_int(rows.size()).override_failure_message("%s has %d rows" % [id, rows.size()]).is_equal(16)
		for y in rows.size():
			var line: String = rows[y]
			assert_int(line.length()) \
				.override_failure_message("%s row %d is %d wide, not 16: '%s'" % [id, y, line.length(), line]) \
				.is_equal(16)


func test_every_character_has_a_palette_entry() -> void:
	for id in Planets.SPRITES:
		var palette: Dictionary = Planets.PALETTES[id]
		for y in (Planets.SPRITES[id] as Array).size():
			var line: String = Planets.SPRITES[id][y]
			for x in line.length():
				var ch := line[x]
				if ch == ".":
					continue
				assert_bool(palette.has(ch)) \
					.override_failure_message("%s uses '%s' at (%d,%d) with no palette entry" % [id, ch, x, y]) \
					.is_true()


## No two worlds may be the same sprite.
##
## Compared on full pixel content, not on silhouette — which is the opposite of
## how the kings are checked, and deliberately so. A king is told apart by his
## headgear, so two matching outlines there means two kings that look alike. But
## planets are mostly spheres: SULFUR-KOR and TERRA-FORMER have identical
## outlines in the reference too, and are told apart by what is ON them. The
## silhouette test failed on exactly that pair, correctly describing art that
## was right.
func test_no_two_planets_are_the_same_sprite() -> void:
	var seen := {}
	for id in Planets.SPRITES:
		var content := "|".join(PackedStringArray(Planets.SPRITES[id]))
		assert_bool(seen.has(content)) \
			.override_failure_message("%s is pixel-identical to %s" % [id, seen.get(content, "")]) \
			.is_false()
		seen[content] = id


func test_a_sprite_builds_into_a_texture_of_the_right_size() -> void:
	for i in Worlds.COUNT:
		var texture := Planets.texture_for(Worlds.get_world(i)["id"])
		assert_object(texture).is_not_null()
		assert_vector(texture.get_size()).is_equal(Vector2(16, 16))


func test_an_unknown_world_has_no_planet() -> void:
	assert_object(Planets.texture_for("atlantis")).is_null()


# --- supplied art ------------------------------------------------------------


## With no files dropped in, every world falls back to its authored sprites.
## This is the state the repo ships in, so it is the one most likely to break
## unnoticed when the loader changes.
func test_with_no_supplied_art_every_world_falls_back() -> void:
	for i in Worlds.COUNT:
		var id: String = Worlds.get_world(i)["id"]
		if WorldArt.has(id):
			continue  # a file has been added for this world; nothing to assert
		assert_object(Planets.texture_for(id)) \
			.override_failure_message("%s has neither supplied nor authored art" % id) \
			.is_not_null()


## Asking for a world that does not exist must be null, not an error — the
## loader is given ids from save data, which can name a world that was removed.
func test_supplied_art_for_an_unknown_world_is_null() -> void:
	assert_object(WorldArt.texture_for("atlantis")).is_null()
	assert_bool(WorldArt.has("atlantis")).is_false()


## `missing()` is what tells you how far a part-finished swap has got.
func test_missing_lists_worlds_still_on_authored_art() -> void:
	var missing := WorldArt.missing()
	for id in missing:
		assert_bool(WorldArt.has(id)) \
			.override_failure_message("%s is listed as missing but has art" % id).is_false()
	assert_int(missing.size()).is_less_equal(Worlds.COUNT)
