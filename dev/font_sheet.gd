extends Control
# Draws the whole glyph set, so a wrong or swapped glyph is obvious:
#
#   Godot --path . --resolution 760x500 dev/font_capture.tscn
#
# Written because FLASK on the tool rack looked like PLASK in a screenshot, and
# there was no way to tell a bad F glyph from blur in an upscaled crop of
# 2x-scale text. It was blur. A sheet answers that in one render.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.10))
	var rows := [
		"ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ0123", "456789-.,:", "FLASK DICE",
	]
	for i in rows.size():
		PixelFont.draw_text(self, rows[i], Vector2(20.0, 20.0 + i * 90.0), 6.0, Color(1.2, 1.25, 1.4))
