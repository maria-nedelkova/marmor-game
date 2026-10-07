## The king art.
##
## Pixel art authored as strings has exactly two failure modes that are
## invisible until something renders wrong: a row of the wrong width, and a
## character with no palette entry (which silently becomes a transparent hole
## in the middle of a face). Both are checked here for all eight.
extends GdUnitTestSuite


func test_every_world_has_a_king() -> void:
	for i in Worlds.COUNT:
		var id: String = Worlds.get_world(i)["id"]
		assert_bool(Kings.SPRITES.has(id)) \
			.override_failure_message("%s has no sprite" % id).is_true()
		assert_bool(Kings.PALETTES.has(id)) \
			.override_failure_message("%s has no palette" % id).is_true()


func test_no_sprite_belongs_to_a_world_that_does_not_exist() -> void:
	for id in Kings.SPRITES:
		assert_int(Worlds.index_of(id)) \
			.override_failure_message("sprite '%s' has no world" % id).is_not_equal(-1)


## A row of the wrong width shifts every pixel after it.
func test_every_sprite_is_square_and_consistent() -> void:
	for id in Kings.SPRITES:
		var rows: Array = Kings.SPRITES[id]
		assert_int(rows.size()).override_failure_message("%s has %d rows" % [id, rows.size()]).is_equal(12)
		for y in rows.size():
			var line: String = rows[y]
			assert_int(line.length()) \
				.override_failure_message("%s row %d is %d wide, not 12: '%s'" % [id, y, line.length(), line]) \
				.is_equal(12)


## A character with no palette entry draws as transparent — a hole in the face
## that looks like a deliberate gap until you look closely.
func test_every_character_has_a_palette_entry() -> void:
	for id in Kings.SPRITES:
		var palette: Dictionary = Kings.PALETTES[id]
		for y in (Kings.SPRITES[id] as Array).size():
			var line: String = Kings.SPRITES[id][y]
			for x in line.length():
				var ch := line[x]
				if ch == ".":
					continue
				assert_bool(palette.has(ch)) \
					.override_failure_message("%s uses '%s' at (%d,%d) with no palette entry" % [id, ch, x, y]) \
					.is_true()


## The palettes share one key vocabulary, which is what the header comment in
## kings.gd documents. Unused keys are EXPECTED and not drift: a visored helm
## has no skin tone, a black hole has no crown. What would be a bug is a
## palette that spells a key differently from the rest, because the sprite
## using it would then draw a transparent hole.
##
## An earlier version of this test asserted that every entry was used, which
## failed on six of the eight kings for entirely correct art.
func test_every_palette_defines_the_same_keys() -> void:
	var expected: Array = []
	var reference := ""
	for id in Kings.PALETTES:
		var keys: Array = (Kings.PALETTES[id] as Dictionary).keys()
		keys.sort()
		if expected.is_empty():
			expected = keys
			reference = id
			continue
		assert_array(keys) \
			.override_failure_message("%s defines %s, %s defines %s" % [id, str(keys), reference, str(expected)]) \
			.is_equal(expected)


## Each king must be told apart by SHAPE, not only by colour — the map already
## tints every node by its planet, and colour alone fails a player who cannot
## separate violet from blue.
func test_the_kings_have_distinct_silhouettes() -> void:
	var shapes := {}
	for id in Kings.SPRITES:
		var mask := ""
		for line in (Kings.SPRITES[id] as Array):
			for x in (line as String).length():
				mask += "." if (line as String)[x] == "." else "#"
		assert_bool(shapes.has(mask)) \
			.override_failure_message("%s has the same silhouette as %s" % [id, shapes.get(mask, "")]) \
			.is_false()
		shapes[mask] = id


func test_a_sprite_builds_into_a_texture_of_the_right_size() -> void:
	for i in Worlds.COUNT:
		var id: String = Worlds.get_world(i)["id"]
		var texture := Kings.texture_for(id)
		assert_object(texture).override_failure_message("%s built no texture" % id).is_not_null()
		assert_vector(texture.get_size()).is_equal(Vector2(12, 12))


## Built once and reused, not rebuilt on every redraw of the map.
func test_textures_are_cached() -> void:
	var first := Kings.texture_for("neonia_1")
	var second := Kings.texture_for("neonia_1")
	assert_object(second).is_same(first)


func test_an_unknown_world_has_no_king() -> void:
	assert_object(Kings.texture_for("atlantis")).is_null()


## Pixels actually land where the strings say they do — including the
## transparent ones, which is what makes "." mean empty rather than black.
func test_the_image_matches_the_strings() -> void:
	var texture := Kings.texture_for("neonia_1")
	var image := texture.get_image()
	var rows: Array = Kings.SPRITES["neonia_1"]
	var palette: Dictionary = Kings.PALETTES["neonia_1"]
	for y in 12:
		for x in 12:
			var ch: String = (rows[y] as String)[x]
			var pixel := image.get_pixel(x, y)
			if ch == ".":
				assert_float(pixel.a) \
					.override_failure_message("(%d,%d) should be transparent" % [x, y]).is_equal(0.0)
			else:
				assert_float(pixel.a).is_greater(0.0)
				# One 8-bit step of tolerance. The image is RGBA8, so a palette
				# entry of 0.98 is stored as 250/255 = 0.9765, and Color's own
				# is_equal_approx uses an epsilon far tighter than that — it
				# reported all 89 opaque pixels as wrong for correct art.
				var want: Color = palette[ch]
				var step := 1.5 / 255.0
				var close: bool = absf(pixel.r - want.r) <= step \
					and absf(pixel.g - want.g) <= step \
					and absf(pixel.b - want.b) <= step
				assert_bool(close) \
					.override_failure_message("(%d,%d) is %s, expected %s" % [x, y, pixel, want]) \
					.is_true()
