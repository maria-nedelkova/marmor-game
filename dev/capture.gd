extends Node
# Renders a screen to user://shot.png and quits, so the look can be checked
# without a human at the keyboard:
#
#   Godot --path . --resolution 720x1280 dev/capture.tscn -- map
#   Godot --path . --resolution 720x1280 dev/capture.tscn -- world:5
#   Godot --path . --resolution 720x1280 dev/capture.tscn -- glide
#
# Kept rather than deleted because every visual change so far has needed it:
# four defects in the map were found this way, including one (stale label
# zones) that no amount of reading would have shown.
func _ready() -> void:
	var which := "map"
	for arg in OS.get_cmdline_user_args():
		which = arg

	if which == "map":
		var map: Control = preload("res://game/ui/level_map.tscn").instantiate()
		add_child(map)
		map.set_anchors_preset(Control.PRESET_FULL_RECT)
		await _shoot()
		return

	var screen: Control = preload("res://game/ui/world_scene.tscn").instantiate()
	screen.world_index = int(which.get_slice(":", 1)) if ":" in which else 0
	add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for _i in 6:
		await get_tree().process_frame

	var session = screen.session
	var view = screen._board_view

	if which.begins_with("glide"):
		# Catch a marble mid-flight: start the longest move available, then stop
		# partway through its duration.
		var best_from := Vector2i(-1, -1)
		var best_to := Vector2i(-1, -1)
		var best_len := 0
		for from in session.board.occupied_cells():
			for to in session.board.empty_cells():
				var path = MarmorEngine.find_path(session.board, from, to)
				if path.size() > best_len:
					best_len = path.size()
					best_from = from
					best_to = to
		if best_len > 0:
			session.tap(best_from)
			session.tap(best_to)
			view._process(0.001)
			view._process(view._duration(view._current) * 0.45)
			view.queue_redraw()
		await _shoot()
		return

	# Otherwise: one real turn, then the flask armed with a first pick.
	var occupied = session.board.occupied_cells()
	if occupied.size() > 0:
		session.tap(occupied[0])
		for to in session.board.empty_cells():
			if not MarmorEngine.find_path(session.board, occupied[0], to).is_empty():
				session.tap(to)
				break
	view.settle()
	if which.ends_with(":sel") or which == "select":
		# Just a selection, so the selected-cell highlight is what shows.
		var marbles = session.board.occupied_cells()
		if marbles.size() > 0:
			session.tap(marbles[0])
	elif session.can_use(Tools.SWAP):
		session.arm(Tools.SWAP)
		var marbles2 = session.board.occupied_cells()
		if marbles2.size() > 0:
			session.tap(marbles2[0])
	screen._refresh()
	await _shoot()


func _shoot() -> void:
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot.png")
	get_tree().quit()
