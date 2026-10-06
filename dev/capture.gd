extends Node
# Renders a screen once to user://shot.png and quits, so the look can be
# checked without a human at the keyboard:
#
#   Godot --path . --resolution 720x1280 dev/capture.tscn -- world
#
# Kept rather than deleted because every visual change so far has needed it —
# four defects in the map were found this way, including one (stale label
# zones) that no amount of reading the code would have shown.
func _ready() -> void:
	var which := "map"
	for arg in OS.get_cmdline_user_args():
		which = arg
	var screen: Control
	if which.begins_with("world"):
		screen = preload("res://game/ui/world_scene.tscn").instantiate()
		screen.world_index = int(which.get_slice(":", 1)) if ":" in which else 0
	else:
		screen = preload("res://game/ui/level_map.tscn").instantiate()
	add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for _i in 6:
		await get_tree().process_frame

	# Drive one real turn, so the shot shows a played board rather than an
	# opening deal: select a marble and move it somewhere reachable.
	if which.begins_with("world"):
		var session = screen.session
		var occupied = session.board.occupied_cells()
		if occupied.size() > 0:
			session.tap(occupied[0])
			for to in session.board.empty_cells():
				if not MarmorEngine.find_path(session.board, occupied[0], to).is_empty():
					session.tap(to)
					break
		screen._refresh()
		for _i in 4:
			await get_tree().process_frame

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot.png")
	get_tree().quit()
