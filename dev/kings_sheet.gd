extends Control
# All eight kings at a large integer scale, so a redraw can be compared against
# docs/reference/level-map.jpeg without launching a world each time.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.11))
	var scale := 10.0
	var cell := 12.0 * scale + 16.0
	for i in Worlds.COUNT:
		var world := Worlds.get_world(i)
		var tex := Kings.texture_for(world["id"])
		if tex == null:
			continue
		var col := i % 3
		var row := i / 3
		var at := Vector2(10.0 + col * cell, 10.0 + row * (cell + 26.0))
		PixelSprite.draw_scaled(self, tex, Rect2(at, Vector2(12.0 * scale, 12.0 * scale)))
		PixelFont.draw_text(
			self, String(world["name"]).substr(0, 11),
			at + Vector2(0.0, 12.0 * scale + 6.0), 2.0, Color(1.1, 1.15, 1.3),
		)
