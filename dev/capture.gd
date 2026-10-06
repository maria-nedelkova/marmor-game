extends Node
# Renders the map once to user://map.png and quits, so the look can be checked
# without a human at the keyboard:
#
#   Godot --path . --resolution 720x1280 dev/capture.tscn
#   open ~/Library/Application\ Support/Godot/app_userdata/Marmor/map.png
#
# Kept rather than deleted because every visual change so far has needed it —
# three defects were found this way (a clipped label, stars showing through
# text, and the final world's ring crossing its own name).
func _ready() -> void:
	var map: Control = preload("res://game/ui/level_map.tscn").instantiate()
	add_child(map)
	for _i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://map.png")
	get_tree().quit()
